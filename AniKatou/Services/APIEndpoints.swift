import Foundation

enum APIEndpoint {
    case search
    case animeDetails(id: String)
    case animeEpisodes(id: String)
    case home
    case qtip(id: String)
    case nextEpisodeSchedule(id: String)
    case episodeServers
    case streamingSources

    var path: String {
        switch self {
        case .search:
            return "search"
        case .animeDetails(let id):
            return "anime/\(id)"
        case .animeEpisodes(let id):
            return "anime/\(id)/episodes"
        case .home:
            return "home"
        case .qtip(let id):
            return "qtip/\(id)"
        case .nextEpisodeSchedule(let id):
            return "anime/\(id)/next-episode-schedule"
        case .episodeServers:
            return "episode/servers"
        case .streamingSources:
            return "episode/sources"
        }
    }
}

struct APIEndpointConfig {
    // Update these values whenever you switch to a new API provider.
    static var apiVersion = "v2"
    static var serviceRoot = "hianime"

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
}
