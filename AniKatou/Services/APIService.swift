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
    case searchQueryTooShort
    
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
        case .searchQueryTooShort: return "Search query must be at least 3 characters"
        }
    }
}

class APIService {
    static let shared = APIService()
    private let decoder: JSONDecoder
    private let session: URLSession
    private let userAgent = "AniKatou/1.0"
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
        
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    // Search anime
    func searchAnime(query: String) async throws -> [AnimeItem] {
        guard query.count >= 3 else {
            throw APIError.searchQueryTooShort
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let queryItems = [
            URLQueryItem(name: "q", value: encodedQuery),
            URLQueryItem(name: "nsfw", value: "false")
        ]
        let result: AnimeSearchResult = try await fetch("search", queryItems: queryItems)
        return result.data.animes
    }
    
    // Get anime details
    func getAnimeDetails(id: String) async throws -> AnimeDetailsResult {
        return try await fetch("anime/\(id)", queryItems: [URLQueryItem(name: "nsfw", value: "false")])
    }
    
    // Get anime episodes
    func getAnimeEpisodes(id: String) async throws -> [EpisodeInfo] {
        let result: EpisodesResponse = try await fetch("anime/\(id)/episodes", queryItems: [URLQueryItem(name: "nsfw", value: "false")])
        return result.data.episodes
    }
    
    // Get streaming URLs
    func getStreamingSources(episodeId: String, category: String = "sub", server: String = "hd-1") async throws -> StreamingResult {
        guard episodeId.contains("?ep=") else {
            throw APIError.invalidEpisodeId
        }
        
        let queryItems = [
            URLQueryItem(name: "animeEpisodeId", value: episodeId),
            URLQueryItem(name: "server", value: server),
            URLQueryItem(name: "category", value: category),
            URLQueryItem(name: "nsfw", value: "false")
        ]
        
        print("\n[API Debug] Fetching streaming sources")
        print("[API Debug] Episode ID: \(episodeId)")
        print("[API Debug] Server: \(server)")
        print("[API Debug] Category: \(category)")
        
        let result: StreamingResult = try await fetch("episode/sources", queryItems: queryItems)
        
        print("\n[API Debug] Streaming response:")
        print("Status: \(result.status)")
        if let tracks = result.data.tracks?.filter({ !$0.lang.lowercased().contains("thumbnail") }) {
            print("Subtitles found: \(tracks.count)")
            for track in tracks {
                print("- Language: \(track.lang)")
                print("  URL: \(track.url)")
            }
        } else {
            print("No subtitles in response")
        }
        
        return result
    }
    
    // Get home page data
    func getHomePage() async throws -> HomePageData {
        let result: HomePageResult = try await fetch("home", queryItems: [URLQueryItem(name: "nsfw", value: "false")])
        return result.data
    }
    
    // Get popular anime
    func getPopularAnime() async throws -> [AnimeItem] {
        let queryItems = [URLQueryItem(name: "nsfw", value: "false")]
        let result: AnimeSearchResult = try await fetch("popular", queryItems: queryItems)
        return result.data.animes
    }
    
    private func validateResponse<T: Codable>(_ response: T) throws -> T {
        if let result = response as? HomePageResult, result.status != 200 {
            throw APIError.serverError(result.status, "Server returned error status: \(result.status)")
        }
        if let result = response as? AnimeSearchResult, result.status != 200 {
            throw APIError.serverError(result.status, "Server returned error status: \(result.status)")
        }
        if let result = response as? AnimeDetailsResult, result.status != 200 {
            throw APIError.serverError(result.status, "Server returned error status: \(result.status)")
        }
        if let result = response as? EpisodesResponse, result.status != 200 {
            throw APIError.serverError(result.status, "Server returned error status: \(result.status)")
        }
        if let result = response as? StreamingResult, result.status != 200 {
            throw APIError.serverError(result.status, "Server returned error status: \(result.status)")
        }
        return response
    }

    // Base fetch method
    private func fetch<T: Codable>(_ endpoint: String, queryItems: [URLQueryItem] = []) async throws -> T {
        guard let baseURL = URL(string: "https://bshar1865-hianime2.vercel.app/api/v2/hianime/") else {
            throw APIError.notConfigured
        }
        
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode == 404 {
                throw APIError.serverError(404, "Not found")
            }
            
            if httpResponse.statusCode != 200 {
                throw APIError.serverError(httpResponse.statusCode, "Server error")
            }
            
            let decodedResponse = try decoder.decode(T.self, from: data)
            return try validateResponse(decodedResponse)
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
} 