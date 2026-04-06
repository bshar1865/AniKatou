import Foundation

struct APIConfig {
    static let apiConfigKey = "api_base_url"
    
    static var baseURL: String? {
        get { UserDefaults.standard.string(forKey: apiConfigKey) }
        set { UserDefaults.standard.set(newValue, forKey: apiConfigKey) }
    }
    
    static var isConfigured: Bool { baseURL != nil }
    
    static func validateURL(_ urlString: String) -> Bool {
        let cleanURL = urlString.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "@", with: "")
        let urlWithScheme = cleanURL.contains("://") ? cleanURL : "https://" + cleanURL
        guard let url = URL(string: urlWithScheme) else { return false }
        return url.scheme?.lowercased() == "https" || url.scheme?.lowercased() == "http"
    }
    
    static func buildEndpoint(_ endpoint: APIEndpoint, queryItems: [URLQueryItem]? = nil) -> URL? {
        buildEndpoint(endpoint.path, queryItems: queryItems)
    }

    static func buildEndpoint(_ path: String, queryItems: [URLQueryItem]? = nil) -> URL? {
        guard var urlString = baseURL?.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "@", with: "") else { return nil }
        
        if !urlString.contains("://") { urlString = "https://" + urlString }
        if urlString.hasSuffix("/") { urlString.removeLast() }
        
        guard var components = URLComponents(string: urlString) else { return nil }
        let existingPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointPath = APIEndpointConfig.endpointPath(path)

        if existingPath.isEmpty {
            components.path = "/\(endpointPath)"
        } else if existingPath.lowercased() == "api" && endpointPath.lowercased().hasPrefix("api/") {
            // Avoid double /api when the user includes /api in the base URL.
            components.path = "/\(endpointPath)"
        } else {
            components.path = "/\(existingPath)/\(endpointPath)"
        }
        components.queryItems = queryItems
        
        return components.url
    }
}
