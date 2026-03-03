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
        defer { isValidating = false }

        guard !apiURL.isEmpty else {
            errorMessage = "Please enter an API URL"
            return false
        }

        var modifiedURL = apiURL.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "@", with: "")
        if !modifiedURL.contains("://") {
            modifiedURL = "https://" + modifiedURL
        }

        guard APIConfig.validateURL(modifiedURL) else {
            errorMessage = "Please enter a valid URL"
            return false
        }

        isValidating = true
        errorMessage = nil

        // Validate by requesting a real app endpoint.
        guard let homeURL = URL(string: modifiedURL.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/api/\(APIConfig.defaultAPIVersion)/hianime/home?nsfw=false") else {
            errorMessage = "Invalid URL format"
            return false
        }

        do {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15
            let session = URLSession(configuration: config)
            var request = URLRequest(url: homeURL)
            request.setValue("AniKatou/1.0", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response from server"
                return false
            }

            guard httpResponse.statusCode == 200 else {
                errorMessage = "Server returned error code: \(httpResponse.statusCode)"
                return false
            }

            let homeResult = try? JSONDecoder().decode(HomePageResult.self, from: data)
            guard homeResult?.status == 200 else {
                errorMessage = "This server is reachable but did not return a valid AniWatch API response"
                return false
            }

            APIConfig.baseURL = modifiedURL
            isConfigured = true
            return true
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                errorMessage = "Connection timed out."
            case .notConnectedToInternet:
                errorMessage = "No internet connection."
            case .cannotFindHost:
                errorMessage = "Cannot find API host."
            case .cannotConnectToHost:
                errorMessage = "Cannot connect to API host."
            default:
                errorMessage = "Network error: \(error.localizedDescription)"
            }
            return false
        } catch {
            errorMessage = "Failed to validate API: \(error.localizedDescription)"
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
