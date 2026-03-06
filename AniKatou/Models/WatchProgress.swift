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

class WatchProgressManager {
    static let shared = WatchProgressManager()
    private let userDefaults = UserDefaults.standard
    private let watchProgressKey = "animeWatchProgress"
    
    private init() {}
    
    func saveProgress(animeID: String, episodeID: String, timestamp: Double, 
                      duration: Double, title: String, episodeNumber: String, 
                      thumbnailURL: String?) {
        let progressPercentage = timestamp / max(1, duration)
        if progressPercentage >= 0.95 {
            removeProgress(for: animeID, episodeID: episodeID)
            return
        }
        
        var history = getWatchHistory()
        history.removeAll { $0.animeID == animeID && $0.episodeID == episodeID }
        
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
        
        history.insert(progress, at: 0)
        
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
        return history.sorted { $0.lastWatched > $1.lastWatched }
    }
    
    func getProgress(for animeID: String, episodeID: String) -> WatchProgress? {
        getWatchHistory().first { $0.animeID == animeID && $0.episodeID == episodeID }
    }
    
    func clearWatchHistory() {
        userDefaults.removeObject(forKey: watchProgressKey)
    }
    
    func clearContinueWatching() {
        clearWatchHistory()
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
        
        history.removeAll { progress in
            let progressPercentage = progress.timestamp / max(1, progress.duration)
            return progressPercentage >= 0.95
        }
        
        if history.count != originalCount,
           let encoded = try? JSONEncoder().encode(history) {
                userDefaults.set(encoded, forKey: watchProgressKey)
        }
    }
}