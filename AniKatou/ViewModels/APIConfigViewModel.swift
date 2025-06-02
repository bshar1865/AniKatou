import Foundation
import SwiftUI

@MainActor
class APIConfigViewModel: ObservableObject {
    @Published var apiURL: String = ""
    @Published var isValidating = false
    @Published var errorMessage: String?
    @Published var isConfigured: Bool
    
    init() {
        self.apiURL = APIConfig.baseURL ?? ""
        self.isConfigured = APIConfig.isConfigured
    }
    
    func saveAPIConfig() async -> Bool {
        defer {
            isValidating = false
        }
        
        guard !apiURL.isEmpty else {
            errorMessage = "Please enter an API URL"
            return false
        }
        
        var modifiedURL = apiURL.trimmingCharacters(in: .whitespaces)
        modifiedURL = modifiedURL.replacingOccurrences(of: "@", with: "")
        
        if !modifiedURL.contains("://") {
            modifiedURL = "https://" + modifiedURL
        }
        
        guard APIConfig.validateURL(modifiedURL) else {
            errorMessage = "Please enter a valid URL"
            return false
        }
        
        isValidating = true
        errorMessage = nil
        
        // Test the API endpoint
        do {
            // For Vercel deployment, we'll test the root endpoint
            guard let url = URL(string: modifiedURL) else {
                errorMessage = "Invalid URL format"
                return false
            }
            
            print("Testing API connection with URL: \(url.absoluteString)")
            
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15 // 15 seconds timeout
            config.waitsForConnectivity = true
            let session = URLSession(configuration: config)
            
            do {
                let (data, response) = try await session.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse else {
                    errorMessage = "Invalid response from server"
                    return false
                }
                
                print("API response status code: \(httpResponse.statusCode)")
                
                if !(200...299).contains(httpResponse.statusCode) {
                    errorMessage = "Server returned error code: \(httpResponse.statusCode)"
                    return false
                }
                
                // Try to verify if it's a valid API response
                if let responseString = String(data: data, encoding: .utf8) {
                    if !responseString.contains("hianime") && !responseString.contains("anime") {
                        errorMessage = "The URL doesn't appear to be a valid HiAnime API endpoint"
                        return false
                    }
                }
                
                // If we reach here, the API is valid
                APIConfig.baseURL = modifiedURL
                isConfigured = true
                return true
            } catch let urlError as URLError {
                print("URLError: \(urlError.code.rawValue) - \(urlError.localizedDescription)")
                switch urlError.code {
                case .timedOut:
                    errorMessage = "Connection timed out. Please check if your API server is running and accessible."
                case .notConnectedToInternet:
                    errorMessage = "No internet connection. Please check your network settings."
                case .cannotFindHost:
                    errorMessage = "Cannot find the API server. Please check the URL and ensure the server is running."
                case .cannotConnectToHost:
                    errorMessage = "Cannot connect to the server. Please check if the server is running and accessible."
                default:
                    errorMessage = "Network error: \(urlError.localizedDescription)"
                }
                return false
            }
        } catch {
            print("Unknown error: \(error.localizedDescription)")
            errorMessage = "Failed to connect to API: \(error.localizedDescription)"
            return false
        }
    }
    
    func clearConfig() {
        APIConfig.baseURL = nil
        apiURL = ""
        isConfigured = false
        errorMessage = nil
    }
} 
 