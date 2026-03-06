import Foundation
import SwiftUI

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
        selectedGroupIndex = 0
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
            errorMessage = UserMessage.animeOfflineUnavailable
            return
        }

        offlineAnimeDetails = offlineDetails
        let episodes = offlineDetails.episodes.map {
            EpisodeInfo(title: $0.title, episodeId: $0.episodeId, number: $0.number, isFiller: $0.isFiller)
        }
        episodeGroups = EpisodeGroup.createGroups(from: episodes)
        refreshLibraryState()
    }

    private func loadOnlineAnimeDetails(animeId: String) async {
        do {
            let detailsResult = try await APIService.shared.getAnimeDetails(id: animeId)
            let episodes = try await APIService.shared.getAnimeEpisodes(id: animeId)
            animeDetails = detailsResult
            episodeGroups = EpisodeGroup.createGroups(from: episodes)
            refreshLibraryState()

            let details = detailsResult.data.anime.info
            await OfflineManager.shared.cacheAnimeDetails(details, episodes: episodes, thumbnails: [:])
        } catch {
            if let offlineDetails = OfflineManager.shared.getCachedAnimeDetails(animeId) {
                offlineAnimeDetails = offlineDetails
                let offlineEpisodes = offlineDetails.episodes.map {
                    EpisodeInfo(title: $0.title, episodeId: $0.episodeId, number: $0.number, isFiller: $0.isFiller)
                }
                episodeGroups = EpisodeGroup.createGroups(from: offlineEpisodes)
                refreshLibraryState()
                errorMessage = nil
                return
            }
            errorMessage = UserMessage.animeDetailsUnavailable
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
        let currentlyInLibrary = LibraryManager.shared.contains(anime)
        if currentlyInLibrary {
            LibraryManager.shared.remove(anime)
        } else {
            LibraryManager.shared.toggle(anime)
            Task {
                await cacheCurrentAnimeForOffline()
            }
        }
        isInLibrary = !currentlyInLibrary
        NotificationCenter.default.post(name: NSNotification.Name("LibraryDidChange"), object: nil)
    }

    func refreshLibraryState() {
        guard let anime = libraryItem() else {
            isInLibrary = false
            return
        }
        isInLibrary = LibraryManager.shared.contains(anime)
    }

    var currentEpisodes: [EpisodeInfo] {
        guard !episodeGroups.isEmpty,
              episodeGroups.indices.contains(selectedGroupIndex) else { return [] }
        return episodeGroups[selectedGroupIndex].episodes
    }

    var allEpisodes: [EpisodeInfo] {
        episodeGroups.flatMap(\.episodes)
    }

    var totalEpisodeCount: Int {
        allEpisodes.count
    }

    func selectGroup(_ index: Int) {
        guard episodeGroups.indices.contains(index) else { return }
        selectedGroupIndex = index
    }

    func downloadEpisode(anime: AnimeItem, episodesToCache: [EpisodeInfo], episode: EpisodeInfo) async {
        do {
            let queued = try await queueEpisodeDownload(anime: anime, episodesToCache: episodesToCache, episode: episode)
            if queued {
                downloadMessage = UserMessage.downloadStarted(forEpisode: episode.number)
            } else {
                downloadMessage = UserMessage.downloadStartFailed
            }
        } catch {
            downloadMessage = UserMessage.downloadStartFailed
        }
    }

    func downloadSelectedEpisodes(anime: AnimeItem, episodesToCache: [EpisodeInfo], selectedEpisodes: [EpisodeInfo]) async {
        guard !selectedEpisodes.isEmpty else {
            downloadMessage = UserMessage.selectEpisodeToDownload
            return
        }

        var queuedCount = 0
        for episode in selectedEpisodes {
            if await queueEpisodeDownloadWithRetry(anime: anime, episodesToCache: episodesToCache, episode: episode) {
                queuedCount += 1
            }
        }

        downloadMessage = queuedCount > 0
            ? UserMessage.bulkDownloadQueued(queuedCount, concurrentLimit: AppSettings.shared.concurrentDownloadsLimit)
            : UserMessage.downloadStartFailed
    }

    deinit {
        loadTask?.cancel()
    }

    private func addToLibraryIfNeeded(_ anime: AnimeItem) {
        guard !LibraryManager.shared.contains(anime) else {
            isInLibrary = true
            return
        }
        LibraryManager.shared.toggle(anime)
        isInLibrary = true
        NotificationCenter.default.post(name: NSNotification.Name("LibraryDidChange"), object: nil)

        Task {
            await cacheCurrentAnimeForOffline()
        }
    }

    private func queueEpisodeDownload(anime: AnimeItem, episodesToCache: [EpisodeInfo], episode: EpisodeInfo) async throws -> Bool {
        addToLibraryIfNeeded(anime)

        if let details = animeDetails?.data.anime.info {
            await OfflineManager.shared.cacheAnimeDetails(details, episodes: episodesToCache, thumbnails: [:])
        }

        let stream = try await APIService.shared.getStreamingSources(
            episodeId: episode.id,
            category: AppSettings.shared.preferredLanguage,
            server: AppSettings.shared.preferredServer
        )

        guard let source = stream.data.sources.first(where: { ($0.isM3U8 ?? false) || $0.url.contains(".m3u8") }),
              let url = URL(string: source.url) else {
            downloadMessage = UserMessage.noDownloadableStream
            return false
        }

        return HLSDownloadManager.shared.startDownload(
            streamURL: url,
            animeId: anime.id,
            episodeId: episode.id,
            animeTitle: anime.title,
            episodeNumber: "\(episode.number)",
            headers: stream.data.headers,
            subtitleTracks: stream.data.tracks,
            intro: stream.data.intro,
            outro: stream.data.outro
        )
    }

    private func queueEpisodeDownloadWithRetry(anime: AnimeItem, episodesToCache: [EpisodeInfo], episode: EpisodeInfo) async -> Bool {
        do {
            if try await queueEpisodeDownload(anime: anime, episodesToCache: episodesToCache, episode: episode) {
                return true
            }
        } catch {
        }

        try? await Task.sleep(nanoseconds: 500_000_000)

        do {
            return try await queueEpisodeDownload(anime: anime, episodesToCache: episodesToCache, episode: episode)
        } catch {
            return false
        }
    }

    private func cacheCurrentAnimeForOffline() async {
        if let details = animeDetails?.data.anime.info {
            await OfflineManager.shared.cacheAnimeDetails(details, episodes: allEpisodes, thumbnails: [:])
            return
        }

        if let offlineDetails = offlineAnimeDetails {
            await OfflineManager.shared.cacheImage(from: offlineDetails.image)
        }
    }
}
