import Foundation
import AVFoundation

@MainActor
class EpisodeViewModel: ObservableObject {
    @Published var streamingData: StreamingResult?
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
        
        do {
            streamingData = try await APIService.shared.getStreamingSources(
                episodeId: episodeId,
                category: AppSettings.shared.preferredLanguage,
                server: AppSettings.shared.preferredServer
            )
            
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = "Failed to load streaming sources: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
} 