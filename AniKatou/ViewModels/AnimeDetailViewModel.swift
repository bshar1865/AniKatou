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
    @Published var customAniListId: String = ""
    @Published var showAniListIdField = false
    
    private var loadTask: Task<Void, Never>?
    private var aniListId: Int?
    private var thumbnailTask: Task<Void, Never>?
    
    enum ThumbnailLoadingState {
        case notStarted
        case loading
        case loaded
        case failed(String)
    }
    
    func loadAnimeDetails(animeId: String) {
        loadTask?.cancel()
        
        // Clear previous thumbnails immediately when loading new anime
        episodeThumbnails = [:]
        thumbnailLoadingState = .notStarted
        aniListId = nil
        customAniListId = ""
        
        loadTask = Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let result = try await APIService.shared.getAnimeDetails(id: animeId)
                
                if !Task.isCancelled {
                    self.animeDetails = result
                    
                    // Fetch episodes separately
                    let episodes = try await APIService.shared.getAnimeEpisodes(id: animeId)
                    self.episodeGroups = EpisodeGroup.createGroups(from: episodes)
                    
                    self.isBookmarked = BookmarkManager.shared.isBookmarked(animeToBookmarkItem() ?? AnimeItem(id: "", name: "", jname: "", poster: "", duration: "", type: "", rating: "", episodes: nil, isNSFW: false, genres: []))
                    
                    // Try to fetch thumbnails from AniList in the background
                    Task {
                        await loadThumbnails(for: result.data.anime.info.name)
                        // Update custom AniList ID field if we found an ID
                        if let foundId = self.aniListId {
                            await MainActor.run {
                                self.customAniListId = String(foundId)
                            }
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                }
            }
            
            if !Task.isCancelled {
                self.isLoading = false
            }
        }
    }
    
    private func loadThumbnails(for title: String) async {
        // Cancel any existing thumbnail task
        thumbnailTask?.cancel()
        
        thumbnailTask = Task {
            thumbnailLoadingState = .loading
            
            do {
                // Use custom AniList ID if provided, otherwise search for it
                if !customAniListId.isEmpty, let customId = Int(customAniListId) {
                    self.aniListId = customId
                } else if self.aniListId == nil {
                    self.aniListId = try? await AniListService.shared.searchAnimeByTitle(title)
                    
                    // If first attempt failed, try with alternative titles
                    if self.aniListId == nil {
                        let alternativeTitles = generateAlternativeTitles(from: title)
                        for altTitle in alternativeTitles {
                            if let id = try? await AniListService.shared.searchAnimeByTitle(altTitle) {
                                self.aniListId = id
                                print("Found AniList ID \(id) using alternative title: \(altTitle)")
                                break
                            }
                        }
                    }
                }
                
                // If we have an AniList ID, fetch thumbnails
                if let aniListId = self.aniListId {
                    let thumbnails = try await AniListService.shared.getEpisodeThumbnails(animeId: aniListId)
                    
                    if !Task.isCancelled {
                        if !thumbnails.isEmpty {
                            let episodeMap = self.mapThumbnailsToEpisodes(thumbnails: thumbnails)
                            
                            if !Task.isCancelled {
                                self.episodeThumbnails = episodeMap
                                self.thumbnailLoadingState = .loaded
                                print("Successfully mapped \(episodeMap.count) thumbnails for \(title) (found \(thumbnails.count) total)")
                            }
                        } else {
                            if !Task.isCancelled {
                                self.episodeThumbnails = [:]
                                self.thumbnailLoadingState = .failed("No thumbnails found for this anime")
                                print("No thumbnails found for \(title) with AniList ID: \(aniListId)")
                            }
                        }
                    }
                } else {
                    if !Task.isCancelled {
                        self.thumbnailLoadingState = .failed("Could not find matching anime on AniList")
                        print("Failed to find AniList ID for: \(title)")
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.thumbnailLoadingState = .failed(error.localizedDescription)
                    print("Error loading thumbnails for \(title): \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func generateAlternativeTitles(from title: String) -> [String] {
        var alternatives: [String] = []
        
        // Try with Japanese title if available
        if let details = animeDetails?.data.anime.info,
           let japanese = details.moreInfo?.japanese {
            alternatives.append(japanese)
        }
        
        // Try with English title variations
        let englishVariations = [
            title.replacingOccurrences(of: "Season 1", with: ""),
            title.replacingOccurrences(of: "Season 2", with: ""),
            title.replacingOccurrences(of: "Season 3", with: ""),
            title.replacingOccurrences(of: "Season 4", with: ""),
            title.replacingOccurrences(of: "Season 5", with: ""),
            title.replacingOccurrences(of: "2nd Season", with: ""),
            title.replacingOccurrences(of: "3rd Season", with: ""),
            title.replacingOccurrences(of: "4th Season", with: ""),
            title.replacingOccurrences(of: "5th Season", with: ""),
            title.replacingOccurrences(of: " (TV)", with: ""),
            title.replacingOccurrences(of: " (Movie)", with: ""),
            title.replacingOccurrences(of: " (OVA)", with: ""),
            title.replacingOccurrences(of: " (ONA)", with: ""),
            title.replacingOccurrences(of: " (Special)", with: "")
        ]
        
        alternatives.append(contentsOf: englishVariations)
        
        // Try with first word only if it's longer than 3 characters
        if let firstWord = title.components(separatedBy: " ").first, firstWord.count > 3 {
            alternatives.append(firstWord)
        }
        
        // Try with common abbreviations
        let abbreviations = [
            title.replacingOccurrences(of: "Attack on Titan", with: "Shingeki no Kyojin"),
            title.replacingOccurrences(of: "One Piece", with: "ワンピース"),
            title.replacingOccurrences(of: "Naruto", with: "ナルト"),
            title.replacingOccurrences(of: "Dragon Ball", with: "ドラゴンボール"),
            title.replacingOccurrences(of: "Bleach", with: "ブリーチ")
        ]
        
        alternatives.append(contentsOf: abbreviations)
        
        return Array(Set(alternatives)).filter { !$0.isEmpty && $0 != title }
    }
    
    private func mapThumbnailsToEpisodes(thumbnails: [EpisodeThumbnail]) -> [Int: String] {
        var episodeMap: [Int: String] = [:]
        var usedThumbnails = Set<String>()
        
        let episodes = self.currentEpisodes
        
        print("Mapping \(thumbnails.count) thumbnails to \(episodes.count) episodes")
        print("Thumbnail titles: \(thumbnails.map { $0.title ?? "Unknown" })")
        print("Episode numbers: \(episodes.map { $0.number })")
        
        // Strategy 1: Try to match by episode number in title
        for episode in episodes {
            if let matchingThumbnail = thumbnails.first(where: { thumbnail in
                guard let title = thumbnail.title else { return false }
                let episodeNumber = episode.number
                
                // Look for various episode number patterns
                let patterns = [
                    "Episode \(episodeNumber)",
                    "Ep \(episodeNumber)",
                    "Ep.\(episodeNumber)",
                    "Ep. \(episodeNumber)",
                    "#\(episodeNumber)",
                    "\(episodeNumber)",
                    "Episode \(episodeNumber):",
                    "Ep \(episodeNumber):"
                ]
                
                return patterns.contains { pattern in
                    title.localizedCaseInsensitiveContains(pattern)
                }
            }), !usedThumbnails.contains(matchingThumbnail.thumbnail) {
                episodeMap[episode.number] = matchingThumbnail.thumbnail
                usedThumbnails.insert(matchingThumbnail.thumbnail)
                print("✅ Matched episode \(episode.number) to thumbnail: \(matchingThumbnail.title ?? "Unknown")")
            }
        }
        
        // Strategy 2: Simple sequential mapping (most reliable)
        let sortedThumbnails = thumbnails.sorted { first, second in
            // Try to extract episode numbers from titles for sorting
            let firstNum = extractEpisodeNumber(from: first.title ?? "")
            let secondNum = extractEpisodeNumber(from: second.title ?? "")
            return firstNum < secondNum
        }
        
        for (index, episode) in episodes.enumerated() {
            if episodeMap[episode.number] == nil && index < sortedThumbnails.count {
                let thumbnail = sortedThumbnails[index]
                if !usedThumbnails.contains(thumbnail.thumbnail) {
                    episodeMap[episode.number] = thumbnail.thumbnail
                    usedThumbnails.insert(thumbnail.thumbnail)
                    print("🔄 Sequentially matched episode \(episode.number) to thumbnail: \(thumbnail.title ?? "Unknown")")
                }
            }
        }
        
        // Strategy 3: Assign remaining thumbnails sequentially (fallback)
        var thumbnailIndex = 0
        for episode in episodes where episodeMap[episode.number] == nil {
            while thumbnailIndex < thumbnails.count {
                let thumbnail = thumbnails[thumbnailIndex].thumbnail
                if !usedThumbnails.contains(thumbnail) {
                    episodeMap[episode.number] = thumbnail
                    usedThumbnails.insert(thumbnail)
                    print("📌 Fallback matched episode \(episode.number) to thumbnail: \(thumbnails[thumbnailIndex].title ?? "Unknown")")
                    break
                }
                thumbnailIndex += 1
            }
            if thumbnailIndex >= thumbnails.count {
                break
            }
        }
        
        print("Final mapping result: \(episodeMap.count) episodes mapped")
        return episodeMap
    }
    
    private func extractEpisodeNumber(from title: String) -> Int {
        // Try to extract episode number from title
        let patterns = [
            "Episode (\\d+)",
            "Ep\\.?\\s*(\\d+)",
            "#(\\d+)",
            "(\\d+)"
        ]
        
        for pattern in patterns {
            if let range = title.range(of: pattern, options: .regularExpression),
               let number = Int(title[range].replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)) {
                return number
            }
        }
        
        return 0
    }
    
    func getThumbnail(for episodeNumber: Int) -> String? {
        return episodeThumbnails[episodeNumber]
    }
    
    func refreshThumbnails() {
        guard let details = animeDetails?.data.anime.info else { return }
        
        // Reset state
        aniListId = nil
        episodeThumbnails = [:]
        thumbnailLoadingState = .loading
        
        // Try to load thumbnails again
        Task {
            await loadThumbnails(for: details.name)
        }
    }
    
    func updateCustomAniListId(_ newId: String) {
        customAniListId = newId
        if !newId.isEmpty {
            refreshThumbnails()
        }
    }
    
    func toggleAniListIdField() {
        showAniListIdField.toggle()
    }
    
    func getThumbnailLoadingStatus() -> String {
        switch thumbnailLoadingState {
        case .notStarted:
            return "Not started"
        case .loading:
            return "Loading thumbnails..."
        case .loaded:
            return "Loaded \(episodeThumbnails.count) thumbnails"
        case .failed(let error):
            return "Failed: \(error)"
        }
    }
    
    // Debug property to access aniListId
    var debugAniListId: Int? {
        return aniListId
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