import Foundation

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int, String?)
    case notConfigured
    case invalidEndpoint
    case invalidAnimeURL
    case invalidEpisodeId
    
    var message: String {
        switch self {
        case .invalidURL: return "Invalid URL format"
        case .invalidResponse: return "Invalid response from server"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .decodingError(let error): return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let code, let message): return message ?? "Server error with code: \(code)"
        case .notConfigured: return "API URL not configured"
        case .invalidEndpoint: return "Invalid API endpoint"
        case .invalidAnimeURL: return "Invalid anime URL format"
        case .invalidEpisodeId: return "Invalid episode ID format"
        }
    }
}

class APIService {
    static let shared = APIService()
    private let decoder: JSONDecoder
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
        
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    // Search anime
    func searchAnime(query: String) async throws -> [AnimeItem] {
        guard query.count >= 3 else {
            return []
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let result: AnimeSearchResult = try await fetch("search", queryItems: [URLQueryItem(name: "q", value: encodedQuery)])
        return result.data.animes
    }
    
    // Get anime details
    func getAnimeDetails(id: String) async throws -> AnimeDetailsResult {
        return try await fetch("anime/\(id)")
    }
    
    // Get anime episodes
    func getAnimeEpisodes(id: String) async throws -> [EpisodeInfo] {
        let result: EpisodesResponse = try await fetch("anime/\(id)/episodes")
        return result.data.episodes
    }
    
    // Get streaming URLs
    func getStreamingSources(episodeId: String, category: String = "sub", server: String = "hd-1") async throws -> StreamingResult {
        // Validate episode ID format (should be like "anime-name?ep=number")
        guard episodeId.contains("?ep=") else {
            throw APIError.invalidEpisodeId
        }
        
        let queryItems = [
            URLQueryItem(name: "animeEpisodeId", value: episodeId),
            URLQueryItem(name: "server", value: server),
            URLQueryItem(name: "category", value: category)
        ]
        
        return try await fetch("episode/sources", queryItems: queryItems)
    }
    
    // Base fetch method
    private func fetch<T: Codable>(_ endpoint: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        guard let baseURL = APIConfig.buildEndpoint(endpoint, queryItems: queryItems) else {
            throw APIError.notConfigured
        }
        
        var request = URLRequest(url: baseURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            var errorMessage: String?
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data) {
                errorMessage = errorResponse["message"]
            }
            throw APIError.serverError(httpResponse.statusCode, errorMessage)
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
} 