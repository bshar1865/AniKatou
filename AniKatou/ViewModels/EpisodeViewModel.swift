import Foundation
import AVFoundation

@MainActor
class EpisodeViewModel: ObservableObject {
    @Published var streamingData: StreamingResult?
    @Published var localPlaybackURL: URL?
    @Published var localSubtitleTracks: [SubtitleTrack]?
    @Published var localIntro: IntroOutro?
    @Published var localOutro: IntroOutro?
    @Published var isLoading = false
    @Published var errorMessage: String?
    var subtitleCues: [SubtitleManager.SubtitleCue]?
    var timeObservers: [(player: AVPlayer, observer: Any)] = []
    
    deinit {
        // Clean up time observers
        timeObservers.forEach { playerAndObserver in
            playerAndObserver.player.removeTimeObserver(playerAndObserver.observer)
        }
    }
    
    func loadStreamingSources(episodeId: String) async {
        isLoading = true
        errorMessage = nil
        localPlaybackURL = nil
        localSubtitleTracks = nil
        localIntro = nil
        localOutro = nil
        streamingData = nil

        let isOffline = OfflineManager.shared.isOfflineMode
        if isOffline {
            if !loadDownloadedEpisodeIfAvailable(episodeId: episodeId) {
                errorMessage = "You have not downloaded this episode."
            }
            isLoading = false
            return
        }
        
        do {
            streamingData = try await APIService.shared.getStreamingSources(
                episodeId: episodeId,
                category: AppSettings.shared.preferredLanguage,
                server: AppSettings.shared.preferredServer
            )
            
        } catch let error as APIError {
            // If API fails, allow offline playback when this episode was downloaded.
            if !loadDownloadedEpisodeIfAvailable(episodeId: episodeId) {
                errorMessage = error.message
            }
        } catch {
            if !loadDownloadedEpisodeIfAvailable(episodeId: episodeId) {
                errorMessage = "Failed to load streaming sources: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }

    @discardableResult
    private func loadDownloadedEpisodeIfAvailable(episodeId: String) -> Bool {
        guard let localURL = HLSDownloadManager.shared.localFileURL(for: episodeId) else {
            return false
        }
        localPlaybackURL = localURL
        localSubtitleTracks = HLSDownloadManager.shared.localSubtitleTracks(for: episodeId)
        let introOutro = HLSDownloadManager.shared.introOutro(for: episodeId)
        localIntro = introOutro.intro
        localOutro = introOutro.outro
        return true
    }
}
