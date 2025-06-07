import Foundation

class AniListService {
    static let shared = AniListService()
    private let endpoint = "https://graphql.anilist.co"
    
    private init() {}
    
    func searchAnimeByTitle(_ title: String) async throws -> Int? {
        let query = """
        query ($search: String) {
            Media(search: $search, type: ANIME) {
                id
                title {
                    romaji
                    english
                    native
                }
            }
        }
        """
        
        let variables: [String: Any] = ["search": title]
        
        let data = try await sendGraphQLRequest(query: query, variables: variables)
        guard let mediaDict = data["Media"] as? [String: Any] else { return nil }
        return mediaDict["id"] as? Int
    }
    
    func getEpisodeThumbnails(animeId: Int) async throws -> [EpisodeThumbnail] {
        let query = """
        query ($id: Int) {
            Media(id: $id) {
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
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let body: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode, nil)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseData = json["data"] as? [String: Any] else {
            throw APIError.decodingError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure"]))
        }
        
        return responseData
    }
} 