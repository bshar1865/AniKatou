import Foundation
import AVFoundation

struct WatchProgress: Codable {
    let animeId: String
    let episodeId: String
    let episodeNumber: Int
    let timestamp: Double
    let duration: Double
    let lastWatched: Date
    
    var progress: Double {
        return timestamp / duration
    }
    
    var isCompleted: Bool {
        return progress >= 0.9 // Consider episode completed if watched 90%
    }
}

class WatchProgressManager {
    static let shared = WatchProgressManager()
    
    private let watchProgressKey = "watch_progress"
    private let continueWatchingKey = "continue_watching"
    private let maxContinueWatchingItems = 20
    
    private init() {}
    
    // MARK: - Watch Progress
    
    func saveProgress(animeId: String, episodeId: String, episodeNumber: Int, timestamp: Double, duration: Double) {
        let progress = WatchProgress(
            animeId: animeId,
            episodeId: episodeId,
            episodeNumber: episodeNumber,
            timestamp: timestamp,
            duration: duration,
            lastWatched: Date()
        )
        
        var progressDict = getProgressDict()
        progressDict["\(animeId)_\(episodeId)"] = progress
        
        if let encoded = try? JSONEncoder().encode(progressDict) {
            UserDefaults.standard.set(encoded, forKey: watchProgressKey)
            updateContinueWatching(animeId: animeId, progress: progress)
        }
    }
    
    func getProgress(animeId: String, episodeId: String) -> WatchProgress? {
        let progressDict = getProgressDict()
        return progressDict["\(animeId)_\(episodeId)"]
    }
    
    private func getProgressDict() -> [String: WatchProgress] {
        guard let data = UserDefaults.standard.data(forKey: watchProgressKey),
              let dict = try? JSONDecoder().decode([String: WatchProgress].self, from: data) else {
            return [:]
        }
        return dict
    }
    
    // MARK: - Continue Watching
    
    private func updateContinueWatching(animeId: String, progress: WatchProgress) {
        var continueWatching = getContinueWatching()
        
        // Remove existing entry for this anime if exists
        continueWatching.removeAll { $0.animeId == animeId }
        
        // Add to the beginning of the list
        continueWatching.insert(progress, at: 0)
        
        // Limit the number of items
        if continueWatching.count > maxContinueWatchingItems {
            continueWatching = Array(continueWatching.prefix(maxContinueWatchingItems))
        }
        
        if let encoded = try? JSONEncoder().encode(continueWatching) {
            UserDefaults.standard.set(encoded, forKey: continueWatchingKey)
        }
    }
    
    func getContinueWatching() -> [WatchProgress] {
        guard let data = UserDefaults.standard.data(forKey: continueWatchingKey),
              let list = try? JSONDecoder().decode([WatchProgress].self, from: data) else {
            return []
        }
        return list
    }
    
    func clearContinueWatching() {
        UserDefaults.standard.removeObject(forKey: continueWatchingKey)
    }
} 