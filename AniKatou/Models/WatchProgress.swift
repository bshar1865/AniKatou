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
        return min(timestamp / max(1, duration), 1.0)
    }
    
    var formattedTimestamp: String {
        let minutes = Int(timestamp / 60)
        let seconds = Int(timestamp.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
}

class WatchProgressManager {
    static let shared = WatchProgressManager()
    private let userDefaults = UserDefaults.standard
    private let watchProgressKey = "animeWatchProgress"
    
    private init() {}
    
    func saveProgress(animeID: String, episodeID: String, timestamp: Double, 
                      duration: Double, title: String, episodeNumber: String, 
                      thumbnailURL: String?) {
        // Check if episode is finished (95% or more watched)
        let progressPercentage = timestamp / max(1, duration)
        if progressPercentage >= 0.95 {
            // Episode is finished, remove it from continue watching
            removeProgress(for: animeID, episodeID: episodeID)
            return
        }
        
        var history = getWatchHistory()
        
        // Remove any previous episodes of the same anime (user moved to next episode)
        history.removeAll { $0.animeID == animeID }
        
        // Add new entry
        let progress = WatchProgress(
            animeID: animeID,
            episodeID: episodeID,
            timestamp: timestamp,
            duration: duration,
            title: title,
            episodeNumber: episodeNumber,
            thumbnailURL: thumbnailURL,
            lastWatched: Date()
        )
        
        // Insert at beginning (most recent)
        history.insert(progress, at: 0)
        
        // Limit to most recent 50 items
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        
        if let encoded = try? JSONEncoder().encode(history) {
            userDefaults.set(encoded, forKey: watchProgressKey)
        }
    }
    
    func getWatchHistory() -> [WatchProgress] {
        guard let data = userDefaults.data(forKey: watchProgressKey),
              let history = try? JSONDecoder().decode([WatchProgress].self, from: data) else {
            return []
        }
        return history
    }
    
    func getProgress(for animeID: String, episodeID: String) -> WatchProgress? {
        return getWatchHistory().first { $0.animeID == animeID && $0.episodeID == episodeID }
    }
    
    func clearWatchHistory() {
        userDefaults.removeObject(forKey: watchProgressKey)
    }
    
    func removeProgress(for animeID: String, episodeID: String) {
        var history = getWatchHistory()
        history.removeAll { $0.animeID == animeID && $0.episodeID == episodeID }
        
        if let encoded = try? JSONEncoder().encode(history) {
            userDefaults.set(encoded, forKey: watchProgressKey)
        }
    }
    
    func cleanupFinishedEpisodes() {
        var history = getWatchHistory()
        let originalCount = history.count
        
        // Remove episodes that are 95% or more watched
        history.removeAll { progress in
            let progressPercentage = progress.timestamp / max(1, progress.duration)
            return progressPercentage >= 0.95
        }
        
        // Only save if we actually removed something
        if history.count != originalCount {
            if let encoded = try? JSONEncoder().encode(history) {
                userDefaults.set(encoded, forKey: watchProgressKey)
            }
        }
    }
}