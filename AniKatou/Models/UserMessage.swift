import Foundation

enum UserMessage {
    static let noInternet = "No internet connection. Please connect to the internet and try again."
    static let networkRequestFailed = "Unable to reach the server right now. Please try again."
    static let homeOffline = "An internet connection is required to load Home."
    static let homeLoadFailed = "Unable to load Home at this time. Please try again."
    static let searchUnavailable = "Unable to complete the search right now. Please try again."
    static let popularUnavailable = "Unable to load popular anime at this time. Please try again."
    static let invalidServerURL = "Please enter a valid URL."
    static let invalidURLFormat = "The URL format is invalid."
    static let invalidServerResponse = "The server returned an invalid response."
    static let apiValidationFailed = "Unable to validate the API server at this time."
    static let apiResourceNotFound = "The requested resource was not found."
    static let apiRequestFailed = "The server could not complete the request."
    static let apiResponseProcessingFailed = "The server response could not be processed."
    static let apiNotConfigured = "The API server URL is not configured."
    static let animeDetailsUnavailable = "Unable to load anime details at this time. Please try again."
    static let animeOfflineUnavailable = "This anime is not available offline. Please connect to the internet to load its details."
    static let episodeOfflineUnavailable = "This episode is not available offline. Please download it while connected to the internet."
    static let streamingUnavailable = "Unable to load streaming sources at this time. Please try again."
    static let playbackOpeningOffline = "Stream unavailable. Opening the downloaded episode instead."
    static let playbackNeedsDownload = "This episode is not available right now. Connect to the internet or download it first."
    static let noDownloadableStream = "No downloadable stream was found for this episode."
    static let downloadStarted = "The download has started."
    static let downloadQueued = "The episode was added to your downloads."
    static let downloadStartFailed = "Unable to start the download at this time. Please try again."
    static let selectEpisodeToDownload = "Please select at least one episode to download."
    static let apiURLRequired = "Please enter an API server URL."
    static let apiHostNotFound = "The API host could not be found."
    static let apiHostConnectionFailed = "Unable to connect to the API host."
    static let apiValidationTimeout = "The connection timed out. Please try again."
    static let apiNetworkValidationFailed = "A network error occurred while validating the API server."
    static let apiUnexpectedResponse = "The server is reachable, but it did not return a valid AniWatch API response."

    static func serverError(_ code: Int) -> String {
        "The server returned an error (code \(code))."
    }

    static func unexpectedStatus(_ code: Int) -> String {
        "The server returned an unexpected status (\(code))."
    }

    static func switchedServer(_ server: String) -> String {
        "Preferred server unavailable. Switched to \(server)."
    }

    static func downloadStarted(forEpisode number: Int, server: String? = nil) -> String {
        if let server, !server.isEmpty {
            return "Episode \(number) was added to your downloads using \(server)."
        }
        return "Episode \(number) was added to your downloads."
    }

    static func bulkDownloadQueued(_ count: Int, concurrentLimit: Int) -> String {
        if count == 1 {
            return "1 episode was added to your downloads. Up to \(concurrentLimit) will download at the same time."
        }
        return "\(count) episodes were added to your downloads. Up to \(concurrentLimit) will download at the same time."
    }
}
