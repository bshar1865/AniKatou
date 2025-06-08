import Foundation

class AniListService {
    static let shared = AniListService()
    private let endpoint = "https://graphql.anilist.co"
    
    private init() {}
    
    func searchAnimeByTitle(_ title: String) async throws -> Int? {
        // Try multiple variations of the title
        let titleVariations = [
            title,
            title.replacingOccurrences(of: " ", with: ""),  // Remove spaces
            title.components(separatedBy: " ").first ?? title,  // First word only
            title.components(separatedBy: ":").first ?? title   // Before colon
        ]
        
        for variation in titleVariations {
            if let id = try? await searchSingleTitle(variation) {
                return id
            }
        }
        return nil
    }
    
    private func searchSingleTitle(_ title: String) async throws -> Int? {
        let query = """
        query ($search: String) {
            Media(search: $search, type: ANIME, isAdult: false) {
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
        
        let variables: [String: Any] = ["search": title]
        
        let data = try await sendGraphQLRequest(query: query, variables: variables)
        guard let mediaDict = data["Media"] as? [String: Any] else { return nil }
        return mediaDict["id"] as? Int
    }
    
    func getEpisodeThumbnails(animeId: Int) async throws -> [EpisodeThumbnail] {
        // Add retry logic
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let thumbnails = try await fetchEpisodeThumbnails(animeId: animeId)
                return thumbnails
            } catch {
                lastError = error
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
                }
            }
        }
        """
        
        let variables: [String: Any] = ["id": animeId]
        
        let data = try await sendGraphQLRequest(query: query, variables: variables)
        
        guard let mediaDict = data["Media"] as? [String: Any],
              let episodes = mediaDict["streamingEpisodes"] as? [[String: Any]] else {
            return []
        }
        
        return episodes.compactMap { episode in
            guard let thumbnail = episode["thumbnail"] as? String else { return nil }
            return EpisodeThumbnail(
                thumbnail: thumbnail,
                title: episode["title"] as? String,
                site: episode["site"] as? String
            )
        }
    }
    
    private func sendGraphQLRequest(query: String, variables: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "AniListService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid endpoint URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("AniKatou/1.0", forHTTPHeaderField: "User-Agent")
        
        let body: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AniListService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "AniListService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let data = json["data"] as? [String: Any] else {
            throw NSError(domain: "AniListService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
        }
        
        return data
    }
} 