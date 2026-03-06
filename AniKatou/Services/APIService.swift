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
        case .invalidURL:
            return UserMessage.invalidURLFormat
        case .invalidResponse:
            return UserMessage.invalidServerResponse
        case .networkError:
            return UserMessage.noInternet
        case .decodingError:
            return UserMessage.apiResponseProcessingFailed
        case .serverError(let code, let message):
            return message ?? UserMessage.serverError(code)
        case .notConfigured:
            return UserMessage.apiNotConfigured
        case .invalidEndpoint:
            return "The requested API endpoint is invalid."
        case .invalidAnimeURL:
            return "The anime URL format is invalid."
        case .invalidEpisodeId:
            return "The episode identifier is invalid."
        case .searchQueryTooShort:
            return "Please enter at least 3 characters to search."
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
    
    func getAnimeDetails(id: String) async throws -> AnimeDetailsResult {
        try await fetch("anime/\(id)", queryItems: [URLQueryItem(name: "nsfw", value: "false")])
    }
    
    func getAnimeEpisodes(id: String) async throws -> [EpisodeInfo] {
        let result: EpisodesResponse = try await fetch("anime/\(id)/episodes", queryItems: [URLQueryItem(name: "nsfw", value: "false")])
        return result.data.episodes
    }
    
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
        
        let result: StreamingResult = try await fetch("episode/sources", queryItems: queryItems)
        return result
    }
    
    func getHomePage() async throws -> HomePageData {
        let result: HomePageResult = try await fetch("home", queryItems: [URLQueryItem(name: "nsfw", value: "false")])
        return result.data
    }
    
    func getPopularAnime() async throws -> [AnimeItem] {
        let result: AnimeSearchResult = try await fetch("popular", queryItems: [URLQueryItem(name: "nsfw", value: "false")])
        return result.data.animes
    }
    
    private func validateResponse<T: Codable>(_ response: T) throws -> T {
        if let result = response as? HomePageResult, result.status != 200 {
            throw APIError.serverError(result.status, UserMessage.unexpectedStatus(result.status))
        }
        if let result = response as? AnimeSearchResult, result.status != 200 {
            throw APIError.serverError(result.status, UserMessage.unexpectedStatus(result.status))
        }
        if let result = response as? AnimeDetailsResult, result.status != 200 {
            throw APIError.serverError(result.status, UserMessage.unexpectedStatus(result.status))
        }
        if let result = response as? EpisodesResponse, result.status != 200 {
            throw APIError.serverError(result.status, UserMessage.unexpectedStatus(result.status))
        }
        if let result = response as? StreamingResult, result.status != 200 {
            throw APIError.serverError(result.status, UserMessage.unexpectedStatus(result.status))
        }
        return response
    }

    private func fetch<T: Codable>(_ endpoint: String, queryItems: [URLQueryItem] = []) async throws -> T {
        guard let url = APIConfig.buildEndpoint(endpoint, queryItems: queryItems) else {
            throw APIError.notConfigured
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
                throw APIError.serverError(404, UserMessage.apiResourceNotFound)
            }
            
            if httpResponse.statusCode != 200 {
                throw APIError.serverError(httpResponse.statusCode, UserMessage.apiRequestFailed)
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