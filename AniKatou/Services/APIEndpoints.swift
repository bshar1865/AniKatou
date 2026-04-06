import Foundation

enum APIEndpoint {
    case search
    case animeDetails(id: String)
    case animeEpisodes(id: String)
    case home
    case qtip(id: String)
    case nextEpisodeSchedule(id: String)
    case streamingSources

    var path: String {
        switch self {
        case .search:
            return "search"
        case .animeDetails(let id):
            return "details/\(id)"
        case .animeEpisodes(let id):
            return "episodes/\(id)"
        case .home:
            return "home"
        case .qtip(let id):
            return "details/\(id)"
        case .nextEpisodeSchedule:
            return "updates"
        case .streamingSources:
            return "stream"
        }
    }
}

struct APIEndpointConfig {
    // Update these values whenever you switch to a new API provider.
    static var defaultBaseURL = "https://animeapi.50n50.deno.net"
    static var apiVersion = ""
    static var serviceRoot = ""

    static let searchQueryKey = "keyword"
    static let searchPageKey = "page"
    static let streamTokenKey = "token"
    static let streamTypeKey = "type"

    static var basePath: String {
        let parts = ["api", apiVersion, serviceRoot].filter { !$0.isEmpty }
        return parts.joined(separator: "/")
    }

    static func endpointPath(_ endpointPath: String) -> String {
        let trimmed = endpointPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if basePath.isEmpty { return trimmed }
        if trimmed.isEmpty { return basePath }
        return "\(basePath)/\(trimmed)"
    }

    static func endpointPath(for endpoint: APIEndpoint) -> String {
        endpointPath(endpoint.path)
    }

    static func searchQueryItems(query: String, page: Int) -> [URLQueryItem] {
        [
            URLQueryItem(name: searchQueryKey, value: query),
            URLQueryItem(name: searchPageKey, value: "\(page)")
        ]
    }

    static func streamQueryItems(token: String, type: String) -> [URLQueryItem] {
        [
            URLQueryItem(name: streamTokenKey, value: token),
            URLQueryItem(name: streamTypeKey, value: type)
        ]
    }
}
