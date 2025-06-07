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
        
        return try await fetch("episode/sources", queryItems: queryItems)
    }
    
    // Get home page data
    func getHomePage() async throws -> HomePageData {
        let result: HomePageResult = try await fetch("home", queryItems: [URLQueryItem(name: "nsfw", value: "false")])
        return result.data
    }
    
    // Base fetch method
    private func fetch<T: Codable>(_ endpoint: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        guard let baseURL = APIConfig.buildEndpoint(endpoint, queryItems: queryItems) else {
            print("\n[API Error] Base URL not configured")
            throw APIError.notConfigured
        }
        
        print("\n[API Request] Endpoint: \(endpoint)")
        print("[API Request] Full URL: \(baseURL.absoluteString)")
        if let items = queryItems {
            print("[API Request] Query parameters:")
            items.forEach { item in
                print("- \(item.name): \(item.value ?? "nil")")
            }
        }
        
        var request = URLRequest(url: baseURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        print("\n[API Request] Headers:")
        request.allHTTPHeaderFields?.forEach { key, value in
            print("- \(key): \(value)")
        }
        
        do {
            print("\n[API] Sending request...")
            let startTime = Date()
            let (data, response) = try await session.data(for: request)
            let duration = Date().timeIntervalSince(startTime)
            print("[API] Request completed in \(String(format: "%.2f", duration))s")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[API Error] Invalid response type")
                throw APIError.invalidResponse
            }
            
            print("\n[API Response] Status code: \(httpResponse.statusCode)")
            print("[API Response] Headers:")
            httpResponse.allHeaderFields.forEach { key, value in
                print("- \(key): \(value)")
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                var errorMessage: String?
                if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data) {
                    errorMessage = errorResponse["message"]
                    print("\n[API Error] Server error message: \(errorMessage ?? "none")")
                }
                throw APIError.serverError(httpResponse.statusCode, errorMessage)
            }
            
            print("\n[API Response] Response size: \(data.count) bytes")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("[API Response] Preview (first 500 chars):")
                print(String(jsonString.prefix(500)))
            }
            
            do {
                let decodedResponse = try decoder.decode(T.self, from: data)
                print("\n[API] Successfully decoded response of type \(T.self)")
                return decodedResponse
            } catch {
                print("\n[API Error] Decoding failed:")
                print("Error: \(error)")
                print("Type expected: \(T.self)")
                throw APIError.decodingError(error)
            }
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            print("\n[API Error] Decoding error: \(error)")
            throw APIError.decodingError(error)
        } catch {
            print("\n[API Error] Network error: \(error)")
            throw APIError.networkError(error)
        }
    }
} 