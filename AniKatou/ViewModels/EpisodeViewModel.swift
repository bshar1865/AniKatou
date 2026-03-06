import Foundation

@MainActor
class EpisodeViewModel: ObservableObject {
    @Published var streamingData: StreamingResult?
    @Published var localPlaybackURL: URL?
    @Published var localSubtitleTracks: [SubtitleTrack]?
    @Published var localIntro: IntroOutro?
    @Published var localOutro: IntroOutro?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var playbackNotice: String?

    func loadStreamingSources(episodeId: String) async {
        isLoading = true
        errorMessage = nil
        playbackNotice = nil
        localPlaybackURL = nil
        localSubtitleTracks = nil
        localIntro = nil
        localOutro = nil
        streamingData = nil

        if OfflineManager.shared.isOfflineMode {
            if !loadDownloadedEpisodeIfAvailable(episodeId: episodeId, notice: nil) {
                errorMessage = UserMessage.episodeOfflineUnavailable
            }
            isLoading = false
            return
        }

        do {
            let resolved = try await APIService.shared.resolveStreamingSources(
                episodeId: episodeId,
                category: AppSettings.shared.preferredLanguage,
                preferredServer: AppSettings.shared.preferredServer
            )
            streamingData = resolved.result
            if resolved.didFallback {
                playbackNotice = UserMessage.switchedServer(displayName(for: resolved.server))
            }
        } catch let error as APIError {
            if !loadDownloadedEpisodeIfAvailable(episodeId: episodeId, notice: UserMessage.playbackOpeningOffline) {
                errorMessage = error.message.isEmpty ? UserMessage.playbackNeedsDownload : error.message
            }
        } catch {
            if !loadDownloadedEpisodeIfAvailable(episodeId: episodeId, notice: UserMessage.playbackOpeningOffline) {
                errorMessage = UserMessage.playbackNeedsDownload
            }
        }

        isLoading = false
    }

    @discardableResult
    private func loadDownloadedEpisodeIfAvailable(episodeId: String, notice: String?) -> Bool {
        guard let localURL = HLSDownloadManager.shared.localFileURL(for: episodeId) else {
            return false
        }
        localPlaybackURL = localURL
        localSubtitleTracks = HLSDownloadManager.shared.localSubtitleTracks(for: episodeId)
        let introOutro = HLSDownloadManager.shared.introOutro(for: episodeId)
        localIntro = introOutro.intro
        localOutro = introOutro.outro
        playbackNotice = notice
        return true
    }

    private func displayName(for server: String) -> String {
        AppSettings.shared.availableServers.first(where: { $0.id == server })?.name ?? server
    }
}
