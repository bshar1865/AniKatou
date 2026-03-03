import Foundation

@MainActor
class AnimeDetailViewModel: ObservableObject {
    @Published var animeDetails: AnimeDetailsResult?
    @Published var episodeGroups: [EpisodeGroup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedGroupIndex: Int = 0
    @Published var isInLibrary = false
    @Published var isOfflineMode = false
    @Published var offlineAnimeDetails: OfflineAnimeDetails?
    @Published var downloadMessage: String?

    private var loadTask: Task<Void, Never>?

    func loadAnimeDetails(animeId: String) {
        loadTask?.cancel()
        episodeGroups = []
        animeDetails = nil
        offlineAnimeDetails = nil

        loadTask = Task {
            isLoading = true
            errorMessage = nil
            isOfflineMode = OfflineManager.shared.isOfflineMode

            if isOfflineMode {
                loadOfflineAnimeDetails(animeId: animeId)
            } else {
                await loadOnlineAnimeDetails(animeId: animeId)
            }

            isLoading = false
        }
    }

    private func loadOfflineAnimeDetails(animeId: String) {
        guard let offlineDetails = OfflineManager.shared.getCachedAnimeDetails(animeId) else {
            errorMessage = "Anime not available offline."
            return
        }

        offlineAnimeDetails = offlineDetails
        let episodes = offlineDetails.episodes.map {
            EpisodeInfo(title: $0.title, episodeId: $0.episodeId, number: $0.number, isFiller: $0.isFiller)
        }
        episodeGroups = EpisodeGroup.createGroups(from: episodes)
        isInLibrary = OfflineManager.shared.getOfflineBookmarks().contains(where: { $0.id == animeId })
    }

    private func loadOnlineAnimeDetails(animeId: String) async {
        do {
            let detailsResult = try await APIService.shared.getAnimeDetails(id: animeId)
            let episodes = try await APIService.shared.getAnimeEpisodes(id: animeId)
            animeDetails = detailsResult
            episodeGroups = EpisodeGroup.createGroups(from: episodes)
            isInLibrary = libraryItem().map { LibraryManager.shared.contains($0) } ?? false

            let details = detailsResult.data.anime.info
            await OfflineManager.shared.cacheAnimeDetails(details, episodes: episodes, thumbnails: [:])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func libraryItem() -> AnimeItem? {
        if let offlineDetails = offlineAnimeDetails {
            return AnimeItem(
                id: offlineDetails.id,
                name: offlineDetails.title,
                jname: nil,
                poster: offlineDetails.image,
                duration: nil,
                type: offlineDetails.type,
                rating: offlineDetails.rating,
                episodes: nil,
                isNSFW: false,
                genres: offlineDetails.genres,
                anilistId: nil
            )
        }

        guard let details = animeDetails?.data.anime.info else { return nil }

        return AnimeItem(
            id: details.id,
            name: details.name,
            jname: details.moreInfo?.japanese,
            poster: details.poster,
            duration: details.stats?.duration,
            type: details.type,
            rating: details.stats?.rating,
            episodes: details.stats?.episodes,
            isNSFW: false,
            genres: details.moreInfo?.genres,
            anilistId: details.anilistId
        )
    }

    func toggleLibrary() {
        guard let anime = libraryItem() else { return }
        LibraryManager.shared.toggle(anime)
        isInLibrary = LibraryManager.shared.contains(anime)
        NotificationCenter.default.post(name: NSNotification.Name("LibraryDidChange"), object: nil)
    }

    var currentEpisodes: [EpisodeInfo] {
        guard !episodeGroups.isEmpty else { return [] }
        return episodeGroups[selectedGroupIndex].episodes
    }

    func selectGroup(_ index: Int) {
        selectedGroupIndex = index
    }

    func downloadEpisode(animeId: String, animeTitle: String, episode: EpisodeInfo) async {
        do {
            let stream = try await APIService.shared.getStreamingSources(
                episodeId: episode.id,
                category: AppSettings.shared.preferredLanguage,
                server: AppSettings.shared.preferredServer
            )

            guard let source = stream.data.sources.first(where: { ($0.isM3U8 ?? false) || $0.url.contains(".m3u8") }),
                  let url = URL(string: source.url) else {
                downloadMessage = "No downloadable HLS source found for this episode."
                return
            }

            HLSDownloadManager.shared.startDownload(
                streamURL: url,
                animeId: animeId,
                episodeId: episode.id,
                animeTitle: animeTitle,
                episodeNumber: "\(episode.number)",
                headers: stream.data.headers
            )

            downloadMessage = "Download started for episode \(episode.number)."
        } catch {
            downloadMessage = "Failed to start download: \(error.localizedDescription)"
        }
    }

    deinit {
        loadTask?.cancel()
    }
}
