import Foundation

struct WatchProgress: Codable, Identifiable {
    let id: UUID
    let animeID: String
    let episodeID: String
    let timestamp: Double
    let duration: Double
    let title: String
    let episodeNumber: String
    let thumbnailURL: String?
    let lastWatched: Date

    init(animeID: String, episodeID: String, timestamp: Double, duration: Double,
         title: String, episodeNumber: String, thumbnailURL: String?, lastWatched: Date) {
        self.id = UUID()
        self.animeID = animeID
        self.episodeID = episodeID
        self.timestamp = timestamp
        self.duration = duration
        self.title = title
        self.episodeNumber = episodeNumber
        self.thumbnailURL = thumbnailURL
        self.lastWatched = lastWatched
    }

    var progressPercentage: Double {
        min(timestamp / max(1, duration), 1.0)
    }

    var formattedTimestamp: String {
        let minutes = Int(timestamp / 60)
        let seconds = Int(timestamp.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
}

final class WatchProgressManager {
    static let shared = WatchProgressManager()
    private let userDefaults = UserDefaults.standard
    private let watchProgressKey = "animeWatchProgress"
    private var cachedHistory: [WatchProgress]

    private init() {
        cachedHistory = Self.loadHistory(from: userDefaults, key: watchProgressKey)
    }

    func saveProgress(animeID: String, episodeID: String, timestamp: Double,
                      duration: Double, title: String, episodeNumber: String,
                      thumbnailURL: String?) {
        let progressPercentage = timestamp / max(1, duration)
        if progressPercentage >= 0.95 {
            removeProgress(for: animeID, episodeID: episodeID)
            return
        }

        cachedHistory.removeAll { $0.animeID == animeID && $0.episodeID == episodeID }
        cachedHistory.insert(
            WatchProgress(
                animeID: animeID,
                episodeID: episodeID,
                timestamp: timestamp,
                duration: duration,
                title: title,
                episodeNumber: episodeNumber,
                thumbnailURL: thumbnailURL,
                lastWatched: Date()
            ),
            at: 0
        )

        if cachedHistory.count > 50 {
            cachedHistory = Array(cachedHistory.prefix(50))
        }

        persist()
    }

    func getWatchHistory() -> [WatchProgress] {
        cachedHistory.sorted { $0.lastWatched > $1.lastWatched }
    }

    func getProgress(for animeID: String, episodeID: String) -> WatchProgress? {
        cachedHistory.first { $0.animeID == animeID && $0.episodeID == episodeID }
    }

    func clearWatchHistory() {
        cachedHistory = []
        userDefaults.removeObject(forKey: watchProgressKey)
    }

    func clearContinueWatching() {
        clearWatchHistory()
    }

    func removeProgress(for animeID: String, episodeID: String) {
        cachedHistory.removeAll { $0.animeID == animeID && $0.episodeID == episodeID }
        persist()
    }

    func cleanupFinishedEpisodes() {
        let originalCount = cachedHistory.count
        cachedHistory.removeAll { ($0.timestamp / max(1, $0.duration)) >= 0.95 }
        if cachedHistory.count != originalCount {
            persist()
        }
    }

    private func persist() {
        if let encoded = try? JSONEncoder().encode(cachedHistory) {
            userDefaults.set(encoded, forKey: watchProgressKey)
        }
    }

    private static func loadHistory(from defaults: UserDefaults, key: String) -> [WatchProgress] {
        guard let data = defaults.data(forKey: key),
              let history = try? JSONDecoder().decode([WatchProgress].self, from: data) else {
            return []
        }
        return history.sorted { $0.lastWatched > $1.lastWatched }
    }
}
