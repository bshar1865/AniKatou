import Foundation

class AniListService {
    static let shared = AniListService()
    private let endpoint = "https://graphql.anilist.co"
    private let userDefaults = UserDefaults.standard
    private let accessTokenKey = "AniListAccessToken"
    private let refreshTokenKey = "AniListRefreshToken"
    private let tokenExpiryKey = "AniListTokenExpiry"
    
    private init() {}
    
    // MARK: - Authentication Properties
    
    var isAuthenticated: Bool {
        guard let accessToken = userDefaults.string(forKey: accessTokenKey),
              let expiryDate = userDefaults.object(forKey: tokenExpiryKey) as? Date else {
            return false
        }
        return !accessToken.isEmpty && expiryDate > Date()
    }
    
    var accessToken: String? {
        return userDefaults.string(forKey: accessTokenKey)
    }
    
    func authenticate(code: String) async throws -> Bool {
        let query = """
        mutation ($code: String!) {
            authenticate(code: $code) {
                access_token
                refresh_token
                expires_in
            }
        }
        """
        
        let variables: [String: Any] = ["code": code]
        
        do {
            let data = try await sendGraphQLRequest(query: query, variables: variables)
            guard let authDict = data["authenticate"] as? [String: Any],
                  let accessToken = authDict["access_token"] as? String,
                  let refreshToken = authDict["refresh_token"] as? String,
                  let expiresIn = authDict["expires_in"] as? Int else {
                throw AniListError.authenticationFailed
            }
            
            // Save tokens
            userDefaults.set(accessToken, forKey: accessTokenKey)
            userDefaults.set(refreshToken, forKey: refreshTokenKey)
            userDefaults.set(Date().addingTimeInterval(TimeInterval(expiresIn)), forKey: tokenExpiryKey)
            
            return true
        } catch {
            throw AniListError.authenticationFailed
        }
    }
    
    func logout() {
        userDefaults.removeObject(forKey: accessTokenKey)
        userDefaults.removeObject(forKey: refreshTokenKey)
        userDefaults.removeObject(forKey: tokenExpiryKey)
    }
    
    func refreshToken() async throws -> Bool {
        guard let refreshToken = userDefaults.string(forKey: refreshTokenKey) else {
            throw AniListError.noRefreshToken
        }
        
        let query = """
        mutation ($refreshToken: String!) {
            refreshToken(refreshToken: $refreshToken) {
                access_token
                refresh_token
                expires_in
            }
        }
        """
        
        let variables: [String: Any] = ["refreshToken": refreshToken]
        
        do {
            let data = try await sendGraphQLRequest(query: query, variables: variables)
            guard let authDict = data["refreshToken"] as? [String: Any],
                  let accessToken = authDict["access_token"] as? String,
                  let newRefreshToken = authDict["refresh_token"] as? String,
                  let expiresIn = authDict["expires_in"] as? Int else {
                throw AniListError.tokenRefreshFailed
            }
            
            // Save new tokens
            userDefaults.set(accessToken, forKey: accessTokenKey)
            userDefaults.set(newRefreshToken, forKey: refreshTokenKey)
            userDefaults.set(Date().addingTimeInterval(TimeInterval(expiresIn)), forKey: tokenExpiryKey)
            
            return true
        } catch {
            throw AniListError.tokenRefreshFailed
        }
    }
    
    // MARK: - User Library
    
    func getUserLibrary(status: AniListStatus? = nil) async throws -> [AniListLibraryItem] {
        guard isAuthenticated else {
            throw AniListError.notAuthenticated
        }
        
        let statusFilter = status?.rawValue ?? ""
        let query = """
        query ($status: MediaListStatus) {
            MediaListCollection(userName: null, type: ANIME, status: $status) {
                lists {
                    entries {
                        id
                        mediaId
                        status
                        score
                        progress
                        media {
                            id
                            title {
                                romaji
                                english
                                native
                            }
                            coverImage {
                                large
                                medium
                            }
                            episodes
                            status
                            format
                        }
                    }
                }
            }
        }
        """
        
        let variables: [String: Any] = ["status": statusFilter]
        
        do {
            let data = try await sendGraphQLRequest(query: query, variables: variables, requiresAuth: true)
            return try parseLibraryResponse(data)
        } catch {
            throw AniListError.failedToFetchLibrary
        }
    }
    
    private func parseLibraryResponse(_ data: [String: Any]) throws -> [AniListLibraryItem] {
        guard let collection = data["MediaListCollection"] as? [String: Any],
              let lists = collection["lists"] as? [[String: Any]] else {
            throw AniListError.invalidResponse
        }
        
        var items: [AniListLibraryItem] = []
        
        for list in lists {
            guard let entries = list["entries"] as? [[String: Any]] else { continue }
            
            for entry in entries {
                guard let media = entry["media"] as? [String: Any],
                      let mediaId = media["id"] as? Int,
                      let title = media["title"] as? [String: Any],
                      let romajiTitle = title["romaji"] as? String,
                      let status = entry["status"] as? String,
                      let listStatus = AniListStatus(rawValue: status) else {
                    continue
                }
                
                let englishTitle = title["english"] as? String
                let nativeTitle = title["native"] as? String
                let coverImage = media["coverImage"] as? [String: Any]
                let imageURL = coverImage?["large"] as? String
                let episodes = media["episodes"] as? Int
                let progress = entry["progress"] as? Int ?? 0
                let score = entry["score"] as? Double
                
                let item = AniListLibraryItem(
                    id: entry["id"] as? Int ?? 0,
                    mediaId: mediaId,
                    title: englishTitle ?? romajiTitle,
                    romajiTitle: romajiTitle,
                    nativeTitle: nativeTitle,
                    imageURL: imageURL,
                    status: listStatus,
                    progress: progress,
                    totalEpisodes: episodes,
                    score: score
                )
                
                items.append(item)
            }
        }
        
        return items
    }
    
    // MARK: - Existing Methods
    
    func searchAnimeByTitle(_ title: String) async throws -> Int? {
        // Create multiple search variations for better matching
        let titleVariations = createTitleVariations(from: title)
        
        for variation in titleVariations {
            if let id = try? await searchSingleTitle(variation) {
                // Validate that this is actually the correct anime
                if let isValid = try? await validateAnimeMatch(animeId: id, originalTitle: title), isValid {
                    print("✅ Found and validated AniList ID \(id) for title variation: \(variation)")
                    return id
                } else {
                    print("❌ Found AniList ID \(id) but validation failed for: \(variation)")
                }
            }
        }
        
        // If no exact match found, try fuzzy search with validation
        if let id = try? await fuzzySearch(title) {
            if let isValid = try? await validateAnimeMatch(animeId: id, originalTitle: title), isValid {
                print("✅ Found and validated AniList ID \(id) via fuzzy search for: \(title)")
                return id
            } else {
                print("❌ Found AniList ID \(id) via fuzzy search but validation failed for: \(title)")
            }
        }
        
        return nil
    }
    
    private func createTitleVariations(from title: String) -> [String] {
        var variations: [String] = []
        
        // Original title
        variations.append(title)
        
        // Remove common suffixes/prefixes
        let cleanTitle = title
            .replacingOccurrences(of: " (TV)", with: "")
            .replacingOccurrences(of: " (Movie)", with: "")
            .replacingOccurrences(of: " (OVA)", with: "")
            .replacingOccurrences(of: " (ONA)", with: "")
            .replacingOccurrences(of: " (Special)", with: "")
            .replacingOccurrences(of: " Season 1", with: "")
            .replacingOccurrences(of: " Season 2", with: "")
            .replacingOccurrences(of: " Season 3", with: "")
            .replacingOccurrences(of: " Season 4", with: "")
            .replacingOccurrences(of: " Season 5", with: "")
            .replacingOccurrences(of: " 2nd Season", with: "")
            .replacingOccurrences(of: " 3rd Season", with: "")
            .replacingOccurrences(of: " 4th Season", with: "")
            .replacingOccurrences(of: " 5th Season", with: "")
        
        if cleanTitle != title {
            variations.append(cleanTitle)
        }
        
        // Remove spaces
        let noSpaces = title.replacingOccurrences(of: " ", with: "")
        variations.append(noSpaces)
        
        // First word only
        if let firstWord = title.components(separatedBy: " ").first, firstWord.count > 2 {
            variations.append(firstWord)
        }
        
        // Before colon
        if let beforeColon = title.components(separatedBy: ":").first {
            variations.append(beforeColon.trimmingCharacters(in: .whitespaces))
        }
        
        // Before dash
        if let beforeDash = title.components(separatedBy: "-").first {
            variations.append(beforeDash.trimmingCharacters(in: .whitespaces))
        }
        
        // Remove numbers at the end
        let withoutNumbers = title.replacingOccurrences(of: "\\s*\\d+\\s*$", with: "", options: .regularExpression)
        if withoutNumbers != title {
            variations.append(withoutNumbers)
        }
        
        // Remove special characters
        let withoutSpecialChars = title.replacingOccurrences(of: "[^a-zA-Z0-9\\s]", with: "", options: .regularExpression)
        if withoutSpecialChars != title {
            variations.append(withoutSpecialChars)
        }
        
        return Array(Set(variations)).filter { !$0.isEmpty }
    }
    
    private func searchSingleTitle(_ title: String) async throws -> Int? {
        let query = """
        query ($search: String) {
            Media(search: $search, type: ANIME, isAdult: false, sort: [POPULARITY_DESC]) {
                id
                title {
                    romaji
                    english
                    native
                }
                synonyms
                format
                episodes
                status
            }
        }
        """
        
        let variables: [String: Any] = ["search": title]
        
        let data = try await sendGraphQLRequest(query: query, variables: variables)
        guard let mediaDict = data["Media"] as? [String: Any] else { return nil }
        return mediaDict["id"] as? Int
    }
    
    private func fuzzySearch(_ title: String) async throws -> Int? {
        let query = """
        query ($search: String) {
            Page(page: 1, perPage: 10) {
                media(search: $search, type: ANIME, isAdult: false, sort: [POPULARITY_DESC]) {
                    id
                    title {
                        romaji
                        english
                        native
                    }
                    synonyms
                    format
                    episodes
                    status
                }
            }
        }
        """
        
        let variables: [String: Any] = ["search": title]
        
        let data = try await sendGraphQLRequest(query: query, variables: variables)
        guard let pageDict = data["Page"] as? [String: Any],
              let mediaArray = pageDict["media"] as? [[String: Any]] else {
            return nil
        }
        
        // Return the first result (most popular)
        return mediaArray.first?["id"] as? Int
    }
    
    func getEpisodeThumbnails(animeId: Int) async throws -> [EpisodeThumbnail] {
        // Add retry logic
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let thumbnails = try await fetchEpisodeThumbnails(animeId: animeId)
                print("Successfully fetched \(thumbnails.count) thumbnails for AniList ID: \(animeId)")
                return thumbnails
            } catch {
                lastError = error
                print("Attempt \(attempt) failed for AniList ID \(animeId): \(error.localizedDescription)")
                if attempt < maxRetries {
                    // Wait before retrying with exponential backoff
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                    continue
                }
            }
        }
        
        throw lastError ?? NSError(domain: "AniListService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch thumbnails after multiple attempts"])
    }
    
    private func fetchEpisodeThumbnails(animeId: Int) async throws -> [EpisodeThumbnail] {
        let query = """
        query ($id: Int) {
            Media(id: $id, isAdult: false) {
                streamingEpisodes {
                    thumbnail
                    title
                    site
                    url
                }
                episodes
                format
            }
        }
        """
        
        let variables: [String: Any] = ["id": animeId]
        
        let data = try await sendGraphQLRequest(query: query, variables: variables)
        
        guard let mediaDict = data["Media"] as? [String: Any] else {
            print("❌ No Media data found for AniList ID: \(animeId)")
            return []
        }
        
        guard let episodes = mediaDict["streamingEpisodes"] as? [[String: Any]] else {
            print("❌ No streaming episodes found for AniList ID: \(animeId)")
            print("Media data: \(mediaDict)")
            return []
        }
        
        print("📺 Found \(episodes.count) streaming episodes for AniList ID: \(animeId)")
        
        let thumbnails = episodes.compactMap { (episode: [String: Any]) -> EpisodeThumbnail? in
            guard let thumbnail = episode["thumbnail"] as? String, !thumbnail.isEmpty else { 
                print("⚠️ Skipping episode with no thumbnail: \(episode)")
                return nil 
            }
            
            let title = episode["title"] as? String
            let site = episode["site"] as? String
            
            print("✅ Valid thumbnail found - Title: \(title ?? "Unknown"), Site: \(site ?? "Unknown")")
            
            return EpisodeThumbnail(
                thumbnail: thumbnail,
                title: title,
                site: site
            )
        }
        
        print("🎯 Found \(thumbnails.count) valid thumbnails out of \(episodes.count) streaming episodes")
        return thumbnails
    }
    
    private func sendGraphQLRequest(query: String, variables: [String: Any], requiresAuth: Bool = false) async throws -> [String: Any] {
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "AniListService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid endpoint URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("AniKatou/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        if requiresAuth {
            guard let accessToken = accessToken else {
                throw NSError(domain: "AniListService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Access token not available"])
            }
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AniListService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "AniListService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "AniListService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
        }
        
        // Check for GraphQL errors
        if let errors = json["errors"] as? [[String: Any]] {
            let errorMessages = errors.compactMap { $0["message"] as? String }.joined(separator: "; ")
            throw NSError(domain: "AniListService", code: -1, userInfo: [NSLocalizedDescriptionKey: "GraphQL errors: \(errorMessages)"])
        }
        
        guard let data = json["data"] as? [String: Any] else {
            throw NSError(domain: "AniListService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in response"])
        }
        
        return data
    }
    
    private func validateAnimeMatch(animeId: Int, originalTitle: String) async throws -> Bool {
        let query = """
        query ($id: Int) {
            Media(id: $id, isAdult: false) {
                id
                title {
                    romaji
                    english
                    native
                }
                synonyms
            }
        }
        """
        
        let variables: [String: Any] = ["id": animeId]
        let data = try await sendGraphQLRequest(query: query, variables: variables)
        
        guard let mediaDict = data["Media"] as? [String: Any],
              let titleDict = mediaDict["title"] as? [String: Any] else {
            return false
        }
        
        let romaji = titleDict["romaji"] as? String ?? ""
        let english = titleDict["english"] as? String ?? ""
        let native = titleDict["native"] as? String ?? ""
        let synonyms = mediaDict["synonyms"] as? [String] ?? []
        
        // Create a list of all possible titles for this anime
        let allTitles = [romaji, english, native] + synonyms
        let normalizedAllTitles = allTitles.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        let normalizedOriginalTitle = originalTitle.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Check if any title contains the original title or vice versa
        for title in normalizedAllTitles {
            if !title.isEmpty && (title.contains(normalizedOriginalTitle) || normalizedOriginalTitle.contains(title)) {
                print("✅ Validation passed: '\(title)' matches '\(normalizedOriginalTitle)'")
                return true
            }
        }
        
        // Additional check for common patterns
        let originalWords = normalizedOriginalTitle.components(separatedBy: " ")
        for title in normalizedAllTitles {
            let titleWords = title.components(separatedBy: " ")
            let commonWords = Set(originalWords).intersection(Set(titleWords))
            if commonWords.count >= 2 && commonWords.count >= Int(Double(min(originalWords.count, titleWords.count)) * 0.7) {
                print("✅ Validation passed: \(commonWords.count) common words between '\(title)' and '\(normalizedOriginalTitle)'")
                return true
            }
        }
        
        print("❌ Validation failed: No match found for '\(normalizedOriginalTitle)' in titles: \(normalizedAllTitles)")
        return false
    }
} 