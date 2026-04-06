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
        case .networkError(let error):
            let nsError = error as NSError
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return UserMessage.noInternet
            case NSURLErrorTimedOut, NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost,
                 NSURLErrorDNSLookupFailed, NSURLErrorNetworkConnectionLost:
                return UserMessage.networkRequestFailed
            default:
                return UserMessage.networkRequestFailed
            }
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

    func searchAnime(query: String, page: Int = 1, excludeRatings: [String] = []) async throws -> [AnimeItem] {
        guard query.count >= 3 else {
            throw APIError.searchQueryTooShort
        }

        let queryItems = APIEndpointConfig.searchQueryItems(query: query, page: page)
        let data: AnimeAPISearchData = try await fetch(.search, queryItems: queryItems)
        let items = AnimeAPIMapper.mapSearch(data)

        if excludeRatings.isEmpty {
            return items
        }
        return items.filter { !ContentSafety.shouldExcludeRating($0.rating, excludeRatings: excludeRatings) }
    }

    func getAnimeDetails(id: String) async throws -> AnimeDetailsResult {
        let data: AnimeAPIDetails = try await fetch(.animeDetails(id: id))
        return try AnimeAPIMapper.mapDetails(data)
    }

    func getAnimeQtipInfo(id: String) async throws -> AnimeQtipResult {
        let data: AnimeAPIDetails = try await fetch(.qtip(id: id))
        return try AnimeAPIMapper.mapQtip(data)
    }

    func getAnimeEpisodes(id: String) async throws -> [EpisodeInfo] {
        let data: [AnimeAPIEpisode] = try await fetch(.animeEpisodes(id: id))
        return AnimeAPIMapper.mapEpisodes(data)
    }

    func getNextEpisodeSchedule(id: String) async throws -> NextEpisodeSchedule {
        throw APIError.invalidEndpoint
    }

    func resolveStreamingSources(episodeId: String, category: String = "sub", preferredServer: String = "hd-1") async throws -> ResolvedStreamingSource {
        let result = try await getStreamingSources(episodeId: episodeId, category: category, server: preferredServer)
        guard !result.data.sources.isEmpty else {
            throw APIError.serverError(503, UserMessage.streamingUnavailable)
        }
        return ResolvedStreamingSource(result: result, server: preferredServer, didFallback: false)
    }

    func getStreamingSources(episodeId: String, category: String = "sub", server: String = "hd-1") async throws -> StreamingResult {
        guard !episodeId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.invalidEpisodeId
        }

        let queryItems = APIEndpointConfig.streamQueryItems(token: episodeId, type: category)
        let data: AnimeAPIStreamData = try await fetch(.streamingSources, queryItems: queryItems)
        return AnimeAPIMapper.mapStream(data)
    }

    func getHomePage() async throws -> HomePageData {
        let data: AnimeAPIHomeData = try await fetch(.home)
        return AnimeAPIMapper.mapHome(data)
    }

    func getPopularAnime() async throws -> [AnimeItem] {
        let home = try await getHomePage()
        return home.mostPopularAnimes
    }

    private func fetch<T: Decodable>(_ endpoint: APIEndpoint, queryItems: [URLQueryItem] = []) async throws -> T {
        let data = try await fetchData(endpoint, queryItems: queryItems)
        do {
            let response = try decoder.decode(AnimeAPIResponse<T>.self, from: data)
            if response.success == false {
                throw APIError.serverError(502, response.error ?? UserMessage.apiRequestFailed)
            }
            guard let payload = response.data else {
                throw APIError.invalidResponse
            }
            return payload
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func fetchData(_ endpoint: APIEndpoint, queryItems: [URLQueryItem] = []) async throws -> Data {
        try await performWithRetryWindow { [self] in
            guard let url = APIConfig.buildEndpoint(endpoint, queryItems: queryItems) else {
                throw APIError.notConfigured
            }

            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 5

            do {
                let (data, response) = try await self.session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                if httpResponse.statusCode == 404 {
                    throw APIError.serverError(404, UserMessage.apiResourceNotFound)
                }

                if httpResponse.statusCode != 200 {
                    throw APIError.serverError(httpResponse.statusCode, UserMessage.apiRequestFailed)
                }

                return data
            } catch let error as APIError {
                throw error
            } catch {
                throw APIError.networkError(error)
            }
        }
    }

    private func performWithRetryWindow<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        let deadline = Date().addingTimeInterval(5)
        var lastError: Error?

        while Date() < deadline {
            do {
                return try await operation()
            } catch let error as APIError {
                lastError = error
                guard shouldRetry(error), Date() < deadline else {
                    throw error
                }
            } catch {
                lastError = error
                guard Date() < deadline else {
                    throw error
                }
            }

            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        if let apiError = lastError as? APIError {
            throw apiError
        }

        throw lastError ?? APIError.networkError(URLError(.timedOut))
    }

    private func shouldRetry(_ error: APIError) -> Bool {
        switch error {
        case .networkError:
            return true
        case .serverError(let code, _):
            return code >= 500
        default:
            return false
        }
    }
}
