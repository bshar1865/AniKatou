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
            errorMessage = "Please enter an API server URL."
            return false
        }

        var modifiedURL = apiURL.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "@", with: "")
        if !modifiedURL.contains("://") {
            modifiedURL = "https://" + modifiedURL
        }

        guard APIConfig.validateURL(modifiedURL) else {
            errorMessage = "Please enter a valid URL."
            return false
        }

        isValidating = true
        errorMessage = nil

        // Validate by requesting a real app endpoint.
        guard var components = URLComponents(string: modifiedURL) else {
            errorMessage = "The URL format is invalid."
            return false
        }
        let existingPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let homePath = "api/\(APIConfig.defaultAPIVersion)/hianime/home"
        components.path = existingPath.isEmpty ? "/\(homePath)" : "/\(existingPath)/\(homePath)"
        components.queryItems = [URLQueryItem(name: "nsfw", value: "false")]
        guard let homeURL = components.url else {
            errorMessage = "The URL format is invalid."
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
                errorMessage = "The server returned an invalid response."
                return false
            }

            guard httpResponse.statusCode == 200 else {
                errorMessage = "The server returned an error (code \(httpResponse.statusCode))."
                return false
            }

            let homeResult = try? JSONDecoder().decode(HomePageResult.self, from: data)
            guard homeResult?.status == 200 else {
                errorMessage = "The server is reachable, but it did not return a valid AniWatch API response."
                return false
            }

            APIConfig.baseURL = modifiedURL
            isConfigured = true
            return true
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                errorMessage = "The connection timed out. Please try again."
            case .notConnectedToInternet:
                errorMessage = "No internet connection. Please connect to the internet and try again."
            case .cannotFindHost:
                errorMessage = "The API host could not be found."
            case .cannotConnectToHost:
                errorMessage = "Unable to connect to the API host."
            default:
                errorMessage = "A network error occurred while validating the API server."
            }
            return false
        } catch {
            errorMessage = "Unable to validate the API server at this time."
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
