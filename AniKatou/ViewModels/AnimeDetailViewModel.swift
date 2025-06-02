import Foundation

@MainActor
class AnimeDetailViewModel: ObservableObject {
    @Published var animeDetails: AnimeDetailsResult?
    @Published var episodes: [EpisodeInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadAnimeDetails(id: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load both details and episodes in parallel
            async let detailsTask = APIService.shared.getAnimeDetails(id: id)
            async let episodesTask = APIService.shared.getAnimeEpisodes(id: id)
            
            let (details, episodes) = try await (detailsTask, episodesTask)
            self.animeDetails = details
            self.episodes = episodes
        } catch let error as APIError {
            errorMessage = error.message
            print("API Error: \(error.message)")
        } catch {
            errorMessage = "Failed to load anime details: \(error.localizedDescription)"
            print("Load error: \(error)")
        }
        
        isLoading = false
    }
    
    func animeToBookmarkItem() -> AnimeItem? {
        guard let details = animeDetails?.data.anime.info else { return nil }
        
        return AnimeItem(
            id: details.id,
            name: details.name,
            jname: nil,
            poster: details.poster,
            duration: details.stats?.duration,
            type: details.stats?.type,
            rating: details.stats?.rating,
            episodes: details.stats?.episodes
        )
    }
    
    func isBookmarked() -> Bool {
        guard let anime = animeToBookmarkItem() else { return false }
        return BookmarkManager.shared.isBookmarked(anime)
    }
} 