import Foundation
import Network
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
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "AniKatou.NetworkMonitor")
    private var networkStatus: NWPath.Status = .requiresConnection

    private var imageCacheDirectory: URL {
        cacheDirectory.appendingPathComponent("images", isDirectory: true)
    }

    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("OfflineCache")
        createCacheDirectoryIfNeeded()
        startNetworkMonitor()
    }

    // MARK: - Cache Directory Management
    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: imageCacheDirectory.path) {
            try? fileManager.createDirectory(at: imageCacheDirectory, withIntermediateDirectories: true)
        }
    }

    private func startNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.networkStatus = path.status
        }
        networkMonitor.start(queue: monitorQueue)
    }

    private func cacheKey(for urlString: String) -> String {
        Data(urlString.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }

    private func imageFileURL(for urlString: String) -> URL {
        imageCacheDirectory.appendingPathComponent(cacheKey(for: urlString)).appendingPathExtension("json")
    }

    // MARK: - Anime Details Caching
    func cacheAnimeDetails(_ animeDetails: AnimeDetails, episodes: [EpisodeInfo], thumbnails: [Int: String]) async {
        let offlineDetails = OfflineAnimeDetails(from: animeDetails, episodes: episodes, thumbnails: thumbnails)

        do {
            let data = try JSONEncoder().encode(offlineDetails)
            let fileURL = cacheDirectory.appendingPathComponent("anime_\(animeDetails.id).json")
            try data.write(to: fileURL)

            await cacheImage(from: animeDetails.image)
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

    // MARK: - Generic Image Caching
    func cacheImage(from urlString: String) async {
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return
            }
            cacheImageData(data, for: urlString)
        } catch {
            // Failed to cache image
        }
    }

    func cacheImageData(_ data: Data, for urlString: String) {
        guard UIImage(data: data) != nil else { return }

        let offlineImage = OfflineImage(url: urlString, data: data, cachedDate: Date())
        guard let imageData = try? JSONEncoder().encode(offlineImage) else { return }
        try? imageData.write(to: imageFileURL(for: urlString), options: .atomic)
    }

    func getCachedImage(for urlString: String) -> UIImage? {
        let fileURL = imageFileURL(for: urlString)

        guard let data = try? Data(contentsOf: fileURL),
              let offlineImage = try? JSONDecoder().decode(OfflineImage.self, from: data),
              let image = UIImage(data: offlineImage.data) else {
            return nil
        }

        if Date().timeIntervalSince(offlineImage.cachedDate) > maxCacheAge {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }

        return image
    }

    // MARK: - Thumbnail Image Caching
    private func cacheThumbnailImages(_ thumbnails: [Int: String], for animeId: String) async {
        let thumbnailDirectory = cacheDirectory.appendingPathComponent("thumbnails_\(animeId)")

        if !fileManager.fileExists(atPath: thumbnailDirectory.path) {
            try? fileManager.createDirectory(at: thumbnailDirectory, withIntermediateDirectories: true)
        }

        for (episodeNumber, thumbnailURL) in thumbnails {
            guard let url = URL(string: thumbnailURL) else { continue }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let offlineImage = OfflineImage(url: thumbnailURL, data: data, cachedDate: Date())
                let imageData = try JSONEncoder().encode(offlineImage)

                let imageFileURL = thumbnailDirectory.appendingPathComponent("episode_\(episodeNumber).json")
                try imageData.write(to: imageFileURL)
                cacheImageData(data, for: thumbnailURL)
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
            createCacheDirectoryIfNeeded()
        } catch {
            // Failed to clear cache
        }
    }

    // MARK: - Network Status
    func isNetworkAvailable() -> Bool {
        networkStatus == .satisfied
    }

    // MARK: - Offline Mode Detection
    var isOfflineMode: Bool {
        !isNetworkAvailable()
    }

    // MARK: - Cache Statistics
    func getCacheStatistics() -> (totalSize: Int64, animeCount: Int, imageCount: Int) {
        let totalSize = getCacheSize()

        let animeFiles = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("anime_") && $0.pathExtension == "json" }

        let imageFiles = try? fileManager.contentsOfDirectory(at: imageCacheDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }

        return (
            totalSize: totalSize,
            animeCount: animeFiles?.count ?? 0,
            imageCount: imageFiles?.count ?? 0
        )
    }
}
