import Foundation

struct APIConfig {
    static let defaultAPIVersion = "v2"
    static let apiConfigKey = "api_base_url"
    
    static var baseURL: String? {
        get {
            UserDefaults.standard.string(forKey: apiConfigKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: apiConfigKey)
        }
    }
    
    static var isConfigured: Bool {
        baseURL != nil
    }
    
    static func validateURL(_ urlString: String) -> Bool {
        var modifiedURLString = urlString.trimmingCharacters(in: .whitespaces)
        modifiedURLString = modifiedURLString.replacingOccurrences(of: "@", with: "")
        
        // Add https:// if no scheme is present
        if !modifiedURLString.contains("://") {
            modifiedURLString = "https://" + modifiedURLString
        }
        
        guard let url = URL(string: modifiedURLString) else { return false }
        return url.scheme?.lowercased() == "https" || url.scheme?.lowercased() == "http"
    }
    
    static func buildEndpoint(_ path: String, queryItems: [URLQueryItem]? = nil) -> URL? {
        guard var baseURL = baseURL else { return nil }
        
        // Clean up the URL
        baseURL = baseURL.trimmingCharacters(in: .whitespaces)
        baseURL = baseURL.replacingOccurrences(of: "@", with: "")
        
        // Add https:// if no scheme is present
        if !baseURL.contains("://") {
            baseURL = "https://" + baseURL
        }
        
        // Remove trailing slash if present
        if baseURL.hasSuffix("/") {
            baseURL = String(baseURL.dropLast())
        }
        
        // Create URL components
        guard var components = URLComponents(string: baseURL) else { return nil }
        
        // Ensure path starts with a slash
        var cleanPath = path
        if !cleanPath.hasPrefix("/") {
            cleanPath = "/" + cleanPath
        }
        
        // Set the path to include the API version and base path
        components.path = "/api/\(defaultAPIVersion)/hianime\(cleanPath)"
        
        // Add query items if provided
        if let queryItems = queryItems {
            components.queryItems = queryItems
        }
        
        let finalURL = components.url?.absoluteString ?? "nil"
        print("Building URL: \(finalURL)")
        return components.url
    }
} 