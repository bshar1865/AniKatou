import Foundation

@MainActor
class EpisodeViewModel: ObservableObject {
    @Published var streamingData: StreamingResult?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadStreamingSources(episodeId: String) async {
        isLoading = true
        errorMessage = nil
        
        print("\n==================== API REQUEST START ====================")
        print("\n[API] Loading streaming sources")
        print("[API] Episode ID: \(episodeId)")
        print("[API] Category: \(AppSettings.shared.preferredLanguage)")
        print("[API] Server: \(AppSettings.shared.preferredServer)")
        
        if let endpoint = APIConfig.buildEndpoint("episode/sources", queryItems: [
            URLQueryItem(name: "animeEpisodeId", value: episodeId),
            URLQueryItem(name: "server", value: AppSettings.shared.preferredServer),
            URLQueryItem(name: "category", value: AppSettings.shared.preferredLanguage)
        ]) {
            print("\n[API] Full endpoint URL:")
            print(endpoint.absoluteString)
        }
        
        do {
            streamingData = try await APIService.shared.getStreamingSources(
                episodeId: episodeId,
                category: AppSettings.shared.preferredLanguage,
                server: AppSettings.shared.preferredServer
            )
            
            print("\n[API] Response received successfully")
            print("\n[API] Sources count: \(streamingData?.data.sources.count ?? 0)")
            print("[API] Has subtitles: \(streamingData?.data.tracks?.contains { $0.kind == "captions" } ?? false)")
            
            if let sources = streamingData?.data.sources {
                print("\n[API] Available video sources:")
                sources.forEach { source in
                    print("\nQuality: \(source.quality ?? "unknown")")
                    print("URL: \(source.url)")
                    print("Is M3U8: \(source.isM3U8 ?? false)")
                }
            }
            
            if let tracks = streamingData?.data.tracks {
                print("\n[API] Available tracks:")
                tracks.forEach { track in
                    print("\nKind: \(track.kind)")
                    if let label = track.label {
                        print("Label: \(label)")
                    }
                    print("URL: \(track.file)")
                    print("Default: \(track.default ?? false)")
                }
            }
            
            if let headers = streamingData?.data.headers {
                print("\n[API] Response headers:")
                headers.forEach { key, value in
                    print("\(key): \(value)")
                }
            }
            
            if let downloadUrl = streamingData?.data.download {
                print("\n[API] Download URL available: \(downloadUrl)")
            }
            
        } catch let error as APIError {
            errorMessage = error.message
            print("\n[API Error] \(error.message)")
        } catch {
            errorMessage = "Failed to load streaming sources: \(error.localizedDescription)"
            print("\n[Error] Load error: \(error)")
        }
        
        print("\n==================== API REQUEST END ====================\n")
        isLoading = false
    }
} 