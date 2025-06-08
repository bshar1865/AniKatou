import Foundation

@MainActor
class AnimeDetailViewModel: ObservableObject {
    @Published var animeDetails: AnimeDetailsResult?
    @Published var episodeGroups: [EpisodeGroup] = []
    @Published var episodeThumbnails: [Int: String] = [:] // Map episode number to thumbnail URL
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedGroupIndex: Int = 0 {
        didSet {
            // Clear current thumbnails and reload when group changes
            episodeThumbnails = [:]
            if let details = animeDetails?.data.anime.info {
                Task {
                    await loadThumbnails(for: details.name)
                }
            }
        }
    }
    @Published var thumbnailLoadingState: ThumbnailLoadingState = .notStarted
    @Published var isBookmarked = false
    
    private var loadTask: Task<Void, Never>?
    private var aniListId: Int?
    private var thumbnailTask: Task<Void, Never>?
    
    enum ThumbnailLoadingState {
        case notStarted
        case loading
        case loaded
        case failed(String)
    }
    
    func loadAnimeDetails(id: String) async {
        // Cancel any existing load task
        loadTask?.cancel()
        
        loadTask = Task {
            isLoading = true
            errorMessage = nil
            thumbnailLoadingState = .loading
            
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
                            self.episodeThumbnails = [:]
                            return
                        }
                        
                        self.animeDetails = details
                        self.episodeGroups = EpisodeGroup.createGroups(from: episodes)
                        self.isBookmarked = BookmarkManager.shared.isBookmarked(anime)
                        
                        // Try to fetch thumbnails from AniList in the background
                        Task {
                            await loadThumbnails(for: animeDetails.name)
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
    
    private func loadThumbnails(for title: String) async {
        // Cancel any existing thumbnail task
        thumbnailTask?.cancel()
        
        thumbnailTask = Task {
            thumbnailLoadingState = .loading
            
            do {
                // Try to get AniList ID
                if self.aniListId == nil {
                    self.aniListId = try? await AniListService.shared.searchAnimeByTitle(title)
                }
                
                // If we have an AniList ID, fetch thumbnails
                if let aniListId = self.aniListId {
                    let thumbnails = try await AniListService.shared.getEpisodeThumbnails(animeId: aniListId)
                    
                    if !Task.isCancelled {
                        // Map thumbnails to episode numbers
                        // Since AniList thumbnails might not be in perfect order, we'll try to match them
                        // with episodes based on their titles or just assign them sequentially
                        var episodeMap: [Int: String] = [:]
                        var usedThumbnails = Set<String>()
                        
                        // First pass: try to match by episode number in title
                        for episode in self.currentEpisodes {
                            if let matchingThumbnail = thumbnails.first(where: { thumbnail in
                                guard let title = thumbnail.title else { return false }
                                // Look for episode number in thumbnail title
                                return title.contains("Episode \(episode.number)") ||
                                       title.contains("Ep \(episode.number)") ||
                                       title.contains("#\(episode.number)")
                            }), !usedThumbnails.contains(matchingThumbnail.thumbnail) {
                                episodeMap[episode.number] = matchingThumbnail.thumbnail
                                usedThumbnails.insert(matchingThumbnail.thumbnail)
                            }
                        }
                        
                        // Second pass: assign remaining thumbnails sequentially
                        var thumbnailIndex = 0
                        for episode in self.currentEpisodes where episodeMap[episode.number] == nil {
                            while thumbnailIndex < thumbnails.count {
                                let thumbnail = thumbnails[thumbnailIndex].thumbnail
                                if !usedThumbnails.contains(thumbnail) {
                                    episodeMap[episode.number] = thumbnail
                                    usedThumbnails.insert(thumbnail)
                                    break
                                }
                                thumbnailIndex += 1
                            }
                            if thumbnailIndex >= thumbnails.count {
                                break
                            }
                        }
                        
                        if !Task.isCancelled {
                            self.episodeThumbnails = episodeMap
                            self.thumbnailLoadingState = .loaded
                        }
                    }
                } else {
                    if !Task.isCancelled {
                        self.thumbnailLoadingState = .failed("Could not find matching anime on AniList")
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.thumbnailLoadingState = .failed(error.localizedDescription)
                }
            }
        }
    }
    
    func getThumbnail(for episodeNumber: Int) -> String? {
        return episodeThumbnails[episodeNumber]
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
    
    func toggleBookmark() {
        guard let anime = animeToBookmarkItem() else { return }
        BookmarkManager.shared.toggleBookmark(anime)
        isBookmarked = BookmarkManager.shared.isBookmarked(anime)
        NotificationCenter.default.post(
            name: NSNotification.Name("BookmarksDidChange"),
            object: nil,
            userInfo: ["animeId": anime.id]
        )
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
        thumbnailTask?.cancel()
    }
} 