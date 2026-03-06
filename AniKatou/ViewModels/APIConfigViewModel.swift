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
            let homeResult = try await validateHomeEndpoint(url: homeURL)
            guard homeResult.status == 200 else {
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

    private func validateHomeEndpoint(url: URL) async throws -> HomePageResult {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 5
        let session = URLSession(configuration: config)

        let deadline = Date().addingTimeInterval(5)
        var lastError: Error?

        while Date() < deadline {
            do {
                var request = URLRequest(url: url)
                request.setValue("AniKatou/1.0", forHTTPHeaderField: "User-Agent")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 5

                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                guard httpResponse.statusCode == 200 else {
                    throw APIError.serverError(httpResponse.statusCode, UserMessage.serverError(httpResponse.statusCode))
                }
                guard let homeResult = try? JSONDecoder().decode(HomePageResult.self, from: data) else {
                    throw APIError.invalidResponse
                }
                return homeResult
            } catch {
                lastError = error
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        throw lastError ?? URLError(.timedOut)
    }
}
