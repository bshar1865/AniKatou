import Foundation

// MARK: - AniList Status Enum
enum AniListStatus: String, CaseIterable, Codable {
    case current = "CURRENT"
    case planning = "PLANNING"
    case completed = "COMPLETED"
    case dropped = "DROPPED"
    case paused = "PAUSED"
    case repeating = "REPEATING"
    
    var displayName: String {
        switch self {
        case .current:
            return "Watching"
        case .planning:
            return "Plan to Watch"
        case .completed:
            return "Completed"
        case .dropped:
            return "Dropped"
        case .paused:
            return "Paused"
        case .repeating:
            return "Rewatching"
        }
    }
    
    var icon: String {
        switch self {
        case .current:
            return "play.circle.fill"
        case .planning:
            return "clock.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .dropped:
            return "xmark.circle.fill"
        case .paused:
            return "pause.circle.fill"
        case .repeating:
            return "repeat.circle.fill"
        }
    }
}

// MARK: - AniList Library Item
struct AniListLibraryItem: Identifiable, Codable {
    let id: Int
    let mediaId: Int
    let title: String
    let romajiTitle: String
    let nativeTitle: String?
    let imageURL: String?
    let status: AniListStatus
    let progress: Int
    let totalEpisodes: Int?
    let score: Double?
    
    var progressText: String {
        if let total = totalEpisodes, total > 0 {
            return "\(progress)/\(total)"
        } else {
            return "\(progress)"
        }
    }
    
    var scoreText: String {
        if let score = score, score > 0 {
            return String(format: "%.1f", score)
        } else {
            return "—"
        }
    }
}

// MARK: - AniList User Profile
struct AniListUserProfile {
    let id: Int
    let name: String
    let avatarURL: String?
    let animeCount: Int
    let episodesWatched: Int
    let meanScore: Double?
}

// MARK: - AniList Errors
enum AniListError: Error, LocalizedError {
    case notAuthenticated
    case authenticationFailed
    case tokenRefreshFailed
    case noRefreshToken
    case failedToFetchLibrary
    case failedToFetchProfile
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with AniList"
        case .authenticationFailed:
            return "Failed to authenticate with AniList"
        case .tokenRefreshFailed:
            return "Failed to refresh AniList token"
        case .noRefreshToken:
            return "No refresh token available"
        case .failedToFetchLibrary:
            return "Failed to fetch library from AniList"
        case .failedToFetchProfile:
            return "Failed to fetch profile from AniList"
        case .invalidResponse:
            return "Invalid response from AniList"
        }
    }
} 