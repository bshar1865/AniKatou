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

        let queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page", value: "\(page)")
        ]

        let result: AnimeSearchResult = try await fetch(.search, queryItems: queryItems)
        if excludeRatings.isEmpty {
            return result.data.animes
        }
        return result.data.animes.filter { !ContentSafety.shouldExcludeRating($0.rating, excludeRatings: excludeRatings) }
    }

    func getAnimeDetails(id: String) async throws -> AnimeDetailsResult {
        try await fetch(.animeDetails(id: id))
    }

    func getAnimeQtipInfo(id: String) async throws -> AnimeQtipResult {
        try await fetch(.qtip(id: id))
    }

    func getAnimeEpisodes(id: String) async throws -> [EpisodeInfo] {
        let result: EpisodesResponse = try await fetch(.animeEpisodes(id: id))
        return result.data.episodes
    }

    func getNextEpisodeSchedule(id: String) async throws -> NextEpisodeSchedule {
        let result: NextEpisodeScheduleResult = try await fetch(.nextEpisodeSchedule(id: id))
        return result.data
    }

    func getEpisodeServers(episodeId: String) async throws -> EpisodeServersData {
        let result: EpisodeServersResult = try await fetch(
            .episodeServers,
            queryItems: [
                URLQueryItem(name: "animeEpisodeId", value: episodeId)
            ]
        )
        return result.data
    }

    func resolveStreamingSources(episodeId: String, category: String = "sub", preferredServer: String = "hd-1") async throws -> ResolvedStreamingSource {
        var candidateServers = [preferredServer]

        if let serversData = try? await getEpisodeServers(episodeId: episodeId) {
            let categoryServers: [EpisodeServer]
            switch category.lowercased() {
            case "dub":
                categoryServers = serversData.dub ?? []
            case "raw":
                categoryServers = serversData.raw ?? []
            default:
                categoryServers = serversData.sub ?? []
            }

            for server in categoryServers.map(\.serverName) where !candidateServers.contains(server) {
                candidateServers.append(server)
            }
        }

        var lastError: Error?

        for server in candidateServers {
            do {
                let result = try await getStreamingSources(episodeId: episodeId, category: category, server: server)
                if !result.data.sources.isEmpty {
                    return ResolvedStreamingSource(result: result, server: server, didFallback: server != preferredServer)
                }
            } catch {
                lastError = error
            }
        }

        if let lastError = lastError as? APIError {
            throw lastError
        }
        throw lastError ?? APIError.serverError(503, UserMessage.streamingUnavailable)
    }

    func getStreamingSources(episodeId: String, category: String = "sub", server: String = "hd-1") async throws -> StreamingResult {
        guard episodeId.contains("?ep=") else {
            throw APIError.invalidEpisodeId
        }

        let queryItems = [
            URLQueryItem(name: "animeEpisodeId", value: episodeId),
            URLQueryItem(name: "server", value: server),
            URLQueryItem(name: "category", value: category)
        ]

        let result: StreamingResult = try await fetch(.streamingSources, queryItems: queryItems)
        return result
    }

    func getHomePage() async throws -> HomePageData {
        let result: HomePageResult = try await fetch(.home)
        return result.data
    }

    func getPopularAnime() async throws -> [AnimeItem] {
        let home = try await getHomePage()
        return home.mostPopularAnimes
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

    private func validateEnvelope(_ response: APIResultEnvelope) throws {
        if let success = response.success, success == false {
            throw APIError.serverError(response.status ?? 500, UserMessage.apiRequestFailed)
        }
        if let status = response.status, status != 200 {
            throw APIError.serverError(status, UserMessage.unexpectedStatus(status))
        }
    }

    private func validateResponse<T: Codable>(_ response: T) throws -> T {
        if let envelope = response as? APIResultEnvelope {
            try validateEnvelope(envelope)
        }
        return response
    }

    private func fetch<T: Codable>(_ endpoint: APIEndpoint, queryItems: [URLQueryItem] = []) async throws -> T {
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

                let decodedResponse = try self.decoder.decode(T.self, from: data)
                return try self.validateResponse(decodedResponse)
            } catch let error as DecodingError {
                throw APIError.decodingError(error)
            } catch let error as APIError {
                throw error
            } catch {
                throw APIError.networkError(error)
            }
        }
    }
}
