import Foundation
import UIKit

// MARK: - Offline Cache Models
struct OfflineAnimeDetails: Codable {
    let id: String
    let title: String
    let image: String
    let description: String?
    let type: String?
    let status: String?
    let releaseDate: String?
    let genres: [String]?
    let rating: String?
    let episodes: [OfflineEpisode]
    let cachedDate: Date
    let thumbnailURLs: [Int: String]
    
    init(from animeDetails: AnimeDetails, episodes: [EpisodeInfo], thumbnails: [Int: String]) {
        self.id = animeDetails.id
        self.title = animeDetails.title
        self.image = animeDetails.image
        self.description = animeDetails.description
        self.type = animeDetails.type
        self.status = animeDetails.status
        self.releaseDate = animeDetails.releaseDate
        self.genres = animeDetails.genres
        self.rating = animeDetails.rating
        self.episodes = episodes.map { OfflineEpisode(from: $0) }
        self.cachedDate = Date()
        self.thumbnailURLs = thumbnails
    }
}

struct OfflineEpisode: Codable {
    let title: String?
    let episodeId: String
    let number: Int
    let isFiller: Bool?
    
    init(from episode: EpisodeInfo) {
        self.title = episode.title
        self.episodeId = episode.episodeId
        self.number = episode.number
        self.isFiller = episode.isFiller
    }
}

struct OfflineImage: Codable {
    let url: String
    let data: Data
    let cachedDate: Date
}

// MARK: - Offline Manager
class OfflineManager {
    static let shared = OfflineManager()
    
    private let fileManager = FileManager.default
    internal let cacheDirectory: URL
    private let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500MB
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("OfflineCache")
        createCacheDirectoryIfNeeded()
    }
    
    // MARK: - Cache Directory Management
    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Anime Details Caching
    func cacheAnimeDetails(_ animeDetails: AnimeDetails, episodes: [EpisodeInfo], thumbnails: [Int: String]) async {
        let offlineDetails = OfflineAnimeDetails(from: animeDetails, episodes: episodes, thumbnails: thumbnails)
        
        do {
            let data = try JSONEncoder().encode(offlineDetails)
            let fileURL = cacheDirectory.appendingPathComponent("anime_\(animeDetails.id).json")
            try data.write(to: fileURL)
            
            // Cache thumbnail images
            await cacheThumbnailImages(thumbnails, for: animeDetails.id)
            
        } catch {
            // Failed to cache anime details
        }
    }
    
    func getCachedAnimeDetails(_ id: String) -> OfflineAnimeDetails? {
        let fileURL = cacheDirectory.appendingPathComponent("anime_\(id).json")
        
        guard let data = try? Data(contentsOf: fileURL),
              let offlineDetails = try? JSONDecoder().decode(OfflineAnimeDetails.self, from: data) else {
            return nil
        }
        
        // Check if cache is still valid
        if Date().timeIntervalSince(offlineDetails.cachedDate) > maxCacheAge {
            removeCachedAnimeDetails(id)
            return nil
        }
        
        return offlineDetails
    }
    
    func removeCachedAnimeDetails(_ id: String) {
        let fileURL = cacheDirectory.appendingPathComponent("anime_\(id).json")
        let thumbnailDirectory = cacheDirectory.appendingPathComponent("thumbnails_\(id)")
        
        try? fileManager.removeItem(at: fileURL)
        try? fileManager.removeItem(at: thumbnailDirectory)
    }
    
    // MARK: - Thumbnail Image Caching
    private func cacheThumbnailImages(_ thumbnails: [Int: String], for animeId: String) async {
        let thumbnailDirectory = cacheDirectory.appendingPathComponent("thumbnails_\(animeId)")
        
        // Create thumbnail directory
        if !fileManager.fileExists(atPath: thumbnailDirectory.path) {
            try? fileManager.createDirectory(at: thumbnailDirectory, withIntermediateDirectories: true)
        }
        
        // Download and cache each thumbnail
        for (episodeNumber, thumbnailURL) in thumbnails {
            guard let url = URL(string: thumbnailURL) else { continue }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let offlineImage = OfflineImage(url: thumbnailURL, data: data, cachedDate: Date())
                let imageData = try JSONEncoder().encode(offlineImage)
                
                let imageFileURL = thumbnailDirectory.appendingPathComponent("episode_\(episodeNumber).json")
                try imageData.write(to: imageFileURL)
            } catch {
                // Failed to cache thumbnail
            }
        }
    }
    
    func getCachedThumbnail(for episodeNumber: Int, animeId: String) -> UIImage? {
        let thumbnailDirectory = cacheDirectory.appendingPathComponent("thumbnails_\(animeId)")
        let imageFileURL = thumbnailDirectory.appendingPathComponent("episode_\(episodeNumber).json")
        
        guard let data = try? Data(contentsOf: imageFileURL),
              let offlineImage = try? JSONDecoder().decode(OfflineImage.self, from: data),
              let image = UIImage(data: offlineImage.data) else {
            return nil
        }
        
        // Check if cache is still valid
        if Date().timeIntervalSince(offlineImage.cachedDate) > maxCacheAge {
            removeCachedThumbnail(for: episodeNumber, animeId: animeId)
            return nil
        }
        
        return image
    }
    
    private func removeCachedThumbnail(for episodeNumber: Int, animeId: String) {
        let thumbnailDirectory = cacheDirectory.appendingPathComponent("thumbnails_\(animeId)")
        let imageFileURL = thumbnailDirectory.appendingPathComponent("episode_\(episodeNumber).json")
        try? fileManager.removeItem(at: imageFileURL)
    }
    
    // MARK: - Bookmark Offline Sync
    func syncBookmarksOffline() {
        let bookmarks = BookmarkManager.shared.bookmarkedAnimes
        
        do {
            let data = try JSONEncoder().encode(bookmarks)
            let fileURL = cacheDirectory.appendingPathComponent("offline_bookmarks.json")
            try data.write(to: fileURL)
        } catch {
            // Failed to sync bookmarks offline
        }
    }
    
    func getOfflineBookmarks() -> [AnimeItem] {
        let fileURL = cacheDirectory.appendingPathComponent("offline_bookmarks.json")
        
        guard let data = try? Data(contentsOf: fileURL),
              let bookmarks = try? JSONDecoder().decode([AnimeItem].self, from: data) else {
            return []
        }
        
        return bookmarks
    }
    
    // MARK: - Watch Progress Offline Sync
    func syncWatchProgressOffline() {
        let watchHistory = WatchProgressManager.shared.getWatchHistory()
        
        do {
            let data = try JSONEncoder().encode(watchHistory)
            let fileURL = cacheDirectory.appendingPathComponent("offline_watch_progress.json")
            try data.write(to: fileURL)
        } catch {
            // Failed to sync watch progress offline
        }
    }
    
    func getOfflineWatchProgress() -> [WatchProgress] {
        let fileURL = cacheDirectory.appendingPathComponent("offline_watch_progress.json")
        
        guard let data = try? Data(contentsOf: fileURL),
              let watchProgress = try? JSONDecoder().decode([WatchProgress].self, from: data) else {
            return []
        }
        
        return watchProgress
    }
    
    // MARK: - Cache Management
    func getCacheSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(fileSize)
            }
        }
        
        return totalSize
    }
    
    func clearOldCache() async {
        let currentDate = Date()
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            for fileURL in contents {
                if let creationDate = try? fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   currentDate.timeIntervalSince(creationDate) > maxCacheAge {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            // Failed to clear old cache
        }
    }
    
    func clearAllCache() {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in contents {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            // Failed to clear cache
        }
    }
    
    // MARK: - Network Status
    func isNetworkAvailable() -> Bool {
        // Simple network check - you might want to use Reachability library for more robust checking
        guard let url = URL(string: "https://www.apple.com") else { return false }
        
        let semaphore = DispatchSemaphore(value: 0)
        var isReachable = false
        
        URLSession.shared.dataTask(with: url) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                isReachable = httpResponse.statusCode == 200
            }
            semaphore.signal()
        }.resume()
        
        _ = semaphore.wait(timeout: .now() + 3.0)
        return isReachable
    }
    
    // MARK: - Offline Mode Detection
    var isOfflineMode: Bool {
        return !isNetworkAvailable()
    }
    
    // MARK: - Cache Statistics
    func getCacheStatistics() -> (totalSize: Int64, animeCount: Int, imageCount: Int) {
        let totalSize = getCacheSize()
        
        let animeFiles = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("anime_") && $0.pathExtension == "json" }
        
        let imageFiles = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("thumbnails_") }
            .compactMap { thumbnailDir in
                try? fileManager.contentsOfDirectory(at: thumbnailDir, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "json" }
            }
            .flatMap { $0 }
        
        return (
            totalSize: totalSize,
            animeCount: animeFiles?.count ?? 0,
            imageCount: imageFiles?.count ?? 0
        )
    }
} 