import Foundation
import SwiftUI

@MainActor
class APIConfigViewModel: ObservableObject {
    @Published var apiURL: String = ""
    @Published var isValidating = false
    @Published var errorMessage: String?
    @Published var isConfigured: Bool

    init() {
        apiURL = APIConfig.baseURL ?? ""
        isConfigured = APIConfig.isConfigured
    }

    func saveAPIConfig() async -> Bool {
        defer { isValidating = false }

        guard !apiURL.isEmpty else {
            errorMessage = UserMessage.apiURLRequired
            return false
        }

        var modifiedURL = apiURL.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "@", with: "")
        if !modifiedURL.contains("://") {
            modifiedURL = "https://" + modifiedURL
        }

        guard APIConfig.validateURL(modifiedURL) else {
            errorMessage = UserMessage.invalidServerURL
            return false
        }

        isValidating = true
        errorMessage = nil

        guard var components = URLComponents(string: modifiedURL) else {
            errorMessage = UserMessage.invalidURLFormat
            return false
        }
        let existingPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let homePath = "api/\(APIConfig.defaultAPIVersion)/hianime/home"
        components.path = existingPath.isEmpty ? "/\(homePath)" : "/\(existingPath)/\(homePath)"
        components.queryItems = [URLQueryItem(name: "nsfw", value: "false")]
        guard let homeURL = components.url else {
            errorMessage = UserMessage.invalidURLFormat
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
                errorMessage = UserMessage.invalidServerResponse
                return false
            }

            guard httpResponse.statusCode == 200 else {
                errorMessage = UserMessage.serverError(httpResponse.statusCode)
                return false
            }

            let homeResult = try? JSONDecoder().decode(HomePageResult.self, from: data)
            guard homeResult?.status == 200 else {
                errorMessage = UserMessage.apiUnexpectedResponse
                return false
            }

            APIConfig.baseURL = modifiedURL
            isConfigured = true
            return true
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                errorMessage = UserMessage.apiValidationTimeout
            case .notConnectedToInternet:
                errorMessage = UserMessage.noInternet
            case .cannotFindHost:
                errorMessage = UserMessage.apiHostNotFound
            case .cannotConnectToHost:
                errorMessage = UserMessage.apiHostConnectionFailed
            default:
                errorMessage = UserMessage.apiNetworkValidationFailed
            }
            return false
        } catch {
            errorMessage = UserMessage.apiValidationFailed
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
