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
    @Published var nextEpisodeSchedule: NextEpisodeSchedule?

    private var loadTask: Task<Void, Never>?

    func loadAnimeDetails(animeId: String) {
        loadTask?.cancel()
        selectedGroupIndex = 0
        episodeGroups = []
        animeDetails = nil
        offlineAnimeDetails = nil
        nextEpisodeSchedule = nil

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
            async let detailsTask = APIService.shared.getAnimeDetails(id: animeId)
            async let episodesTask = APIService.shared.getAnimeEpisodes(id: animeId)
            let qtipTask = Task { try? await APIService.shared.getAnimeQtipInfo(id: animeId) }
            let scheduleTask = Task { try? await APIService.shared.getNextEpisodeSchedule(id: animeId) }

            let detailsResult = try await detailsTask
            let episodes = try await episodesTask
            let qtipResult = await qtipTask.value
            nextEpisodeSchedule = await scheduleTask.value

            if detailsResult.data.anime.info.containsNSFWContent || qtipResult?.data.anime.containsNSFWContent == true {
                errorMessage = "This app does not support hentai shows."
                animeDetails = nil
                episodeGroups = []
                return
            }

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
            LibraryManager.shared.add(anime)
            Task {
                await cacheCurrentAnimeForOffline()
            }
        }
        isInLibrary = !currentlyInLibrary
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
        let result = await queueEpisodeDownloadWithRetry(anime: anime, episodesToCache: episodesToCache, episode: episode)
        if result.queued {
            downloadMessage = UserMessage.downloadStarted(forEpisode: episode.number, server: result.serverName)
        } else {
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
            let result = await queueEpisodeDownloadWithRetry(anime: anime, episodesToCache: episodesToCache, episode: episode)
            if result.queued {
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
        LibraryManager.shared.add(anime)
        isInLibrary = true

        Task {
            await cacheCurrentAnimeForOffline()
        }
    }

    private func queueEpisodeDownload(anime: AnimeItem, episodesToCache: [EpisodeInfo], episode: EpisodeInfo) async throws -> (queued: Bool, serverName: String?) {
        addToLibraryIfNeeded(anime)

        if let details = animeDetails?.data.anime.info {
            await OfflineManager.shared.cacheAnimeDetails(details, episodes: episodesToCache, thumbnails: [:])
        }

        let resolved = try await APIService.shared.resolveStreamingSources(
            episodeId: episode.id,
            category: AppSettings.shared.preferredLanguage,
            preferredServer: AppSettings.shared.preferredServer
        )

        guard let source = resolved.result.data.sources.first(where: { ($0.isM3U8 ?? false) || $0.url.contains(".m3u8") }),
              let url = URL(string: source.url) else {
            downloadMessage = UserMessage.noDownloadableStream
            return (false, nil)
        }

        let started = HLSDownloadManager.shared.startDownload(
            streamURL: url,
            animeId: anime.id,
            episodeId: episode.id,
            animeTitle: anime.title,
            episodeNumber: "\(episode.number)",
            headers: resolved.result.data.headers,
            subtitleTracks: resolved.result.data.tracks,
            intro: resolved.result.data.intro,
            outro: resolved.result.data.outro
        )

        guard started else { return (false, nil) }
        return (true, resolved.didFallback ? displayName(for: resolved.server) : nil)
    }

    private func queueEpisodeDownloadWithRetry(anime: AnimeItem, episodesToCache: [EpisodeInfo], episode: EpisodeInfo) async -> (queued: Bool, serverName: String?) {
        do {
            let result = try await queueEpisodeDownload(anime: anime, episodesToCache: episodesToCache, episode: episode)
            if result.queued || HLSDownloadManager.shared.downloads.contains(where: { $0.episodeId == episode.id }) {
                return result.queued ? result : (true, nil)
            }
        } catch {
        }

        try? await Task.sleep(nanoseconds: 500_000_000)

        do {
            let result = try await queueEpisodeDownload(anime: anime, episodesToCache: episodesToCache, episode: episode)
            if result.queued || HLSDownloadManager.shared.downloads.contains(where: { $0.episodeId == episode.id }) {
                return result.queued ? result : (true, nil)
            }
        } catch {
        }

        return (false, nil)
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

    private func displayName(for server: String) -> String {
        AppSettings.shared.availableServers.first(where: { $0.id == server })?.name ?? server
    }
}
