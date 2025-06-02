import Foundation

@MainActor
class EpisodeViewModel: ObservableObject {
    @Published var streamingData: StreamingResult?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
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
            print("API Error: \(error.message)")
        } catch {
            errorMessage = "Failed to load streaming sources: \(error.localizedDescription)"
            print("Load error: \(error)")
        }
        
        isLoading = false
    }
} 