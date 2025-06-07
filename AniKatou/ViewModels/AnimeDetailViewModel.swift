import Foundation

@MainActor
class AnimeDetailViewModel: ObservableObject {
    @Published var animeDetails: AnimeDetailsResult?
    @Published var episodeGroups: [EpisodeGroup] = []
    @Published var episodeThumbnails: [EpisodeThumbnail] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedGroupIndex: Int = 0
    
    private var loadTask: Task<Void, Never>?
    private var aniListId: Int?
    
    func loadAnimeDetails(id: String) async {
        // Cancel any existing load task
        loadTask?.cancel()
        
        loadTask = Task {
            isLoading = true
            errorMessage = nil
            
            do {
                // Load both details and episodes in parallel with error handling for each
                async let detailsTask = APIService.shared.getAnimeDetails(id: id)
                async let episodesTask = APIService.shared.getAnimeEpisodes(id: id)
                
                // Wait for both tasks to complete or fail
                do {
                    let (details, episodes) = try await (detailsTask, episodesTask)
                    if !Task.isCancelled {
                        // Create AnimeItem to check for NSFW content
                        let animeDetails = details.data.anime.info
                        let anime = AnimeItem(
                            id: animeDetails.id,
                            name: animeDetails.name,
                            jname: animeDetails.moreInfo?.japanese,
                            poster: animeDetails.poster,
                            duration: animeDetails.stats?.duration,
                            type: animeDetails.type,
                            rating: animeDetails.stats?.rating,
                            episodes: animeDetails.stats?.episodes,
                            isNSFW: animeDetails.moreInfo?.genres?.contains { $0.lowercased().contains("hentai") || $0.lowercased().contains("ecchi") } ?? false,
                            genres: animeDetails.moreInfo?.genres
                        )
                        
                        if anime.containsNSFWContent {
                            errorMessage = "This content is not available due to content restrictions."
                            self.animeDetails = nil
                            self.episodeGroups = []
                            self.episodeThumbnails = []
                            return
                        }
                        
                        self.animeDetails = details
                        self.episodeGroups = EpisodeGroup.createGroups(from: episodes)
                        
                        // Try to fetch thumbnails from AniList
                        // First try to get AniList ID by title
                        if self.aniListId == nil {
                            self.aniListId = try? await AniListService.shared.searchAnimeByTitle(animeDetails.name)
                        }
                        
                        // If we have an AniList ID, fetch thumbnails
                        if let aniListId = self.aniListId {
                            let thumbnails = try await AniListService.shared.getEpisodeThumbnails(animeId: aniListId)
                            if !Task.isCancelled {
                                self.episodeThumbnails = thumbnails
                            }
                        }
                    }
                } catch let error as APIError {
                    if !Task.isCancelled {
                        errorMessage = error.message
                    }
                } catch {
                    if !Task.isCancelled {
                        errorMessage = "Failed to load anime details: \(error.localizedDescription)"
                    }
                }
            }
            
            if !Task.isCancelled {
                isLoading = false
            }
        }
    }
    
    func getThumbnail(for episodeNumber: Int) -> String? {
        guard episodeNumber - 1 < episodeThumbnails.count else { return nil }
        return episodeThumbnails[episodeNumber - 1].thumbnail
    }
    
    func animeToBookmarkItem() -> AnimeItem? {
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
            isNSFW: details.moreInfo?.genres?.contains { $0.lowercased().contains("hentai") || $0.lowercased().contains("ecchi") } ?? false,
            genres: details.moreInfo?.genres
        )
    }
    
    func isBookmarked() -> Bool {
        guard let anime = animeToBookmarkItem() else { return false }
        return BookmarkManager.shared.isBookmarked(anime)
    }
    
    func selectGroup(_ index: Int) {
        selectedGroupIndex = index
    }
    
    var currentEpisodes: [EpisodeInfo] {
        guard !episodeGroups.isEmpty else { return [] }
        return episodeGroups[selectedGroupIndex].episodes
    }
    
    deinit {
        loadTask?.cancel()
    }
} 