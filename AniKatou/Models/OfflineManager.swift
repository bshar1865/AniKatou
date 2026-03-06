import Foundation
import Network
import UIKit

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
        id = animeDetails.id
        title = animeDetails.title
        image = animeDetails.image
        description = animeDetails.description
        type = animeDetails.type
        status = animeDetails.status
        releaseDate = animeDetails.releaseDate
        genres = animeDetails.genres
        rating = animeDetails.rating
        self.episodes = episodes.map { OfflineEpisode(from: $0) }
        cachedDate = Date()
        thumbnailURLs = thumbnails
    }
}

struct OfflineEpisode: Codable {
    let title: String?
    let episodeId: String
    let number: Int
    let isFiller: Bool?

    init(from episode: EpisodeInfo) {
        title = episode.title
        episodeId = episode.episodeId
        number = episode.number
        isFiller = episode.isFiller
    }
}

struct OfflineImageMetadata: Codable {
    let url: String
    let cachedDate: Date
}

struct LegacyOfflineImage: Codable {
    let url: String
    let data: Data
    let cachedDate: Date
}

final class OfflineManager {
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

    private func imageDataURL(for urlString: String) -> URL {
        imageCacheDirectory.appendingPathComponent(cacheKey(for: urlString)).appendingPathExtension("img")
    }

    private func imageMetadataURL(for urlString: String) -> URL {
        imageCacheDirectory.appendingPathComponent(cacheKey(for: urlString)).appendingPathExtension("json")
    }

    func cacheAnimeDetails(_ animeDetails: AnimeDetails, episodes: [EpisodeInfo], thumbnails: [Int: String]) async {
        let offlineDetails = OfflineAnimeDetails(from: animeDetails, episodes: episodes, thumbnails: thumbnails)

        do {
            let data = try JSONEncoder().encode(offlineDetails)
            let fileURL = cacheDirectory.appendingPathComponent("anime_\(animeDetails.id).json")
            try data.write(to: fileURL)

            await cacheImage(from: animeDetails.image)
            await cacheThumbnailImages(thumbnails, for: animeDetails.id)
        } catch {
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
        }
    }

    func cacheImageData(_ data: Data, for urlString: String) {
        guard UIImage(data: data) != nil else { return }

        let metadata = OfflineImageMetadata(url: urlString, cachedDate: Date())
        guard let metadataData = try? JSONEncoder().encode(metadata) else { return }
        try? data.write(to: imageDataURL(for: urlString), options: .atomic)
        try? metadataData.write(to: imageMetadataURL(for: urlString), options: .atomic)
    }

    func getCachedImage(for urlString: String) -> UIImage? {
        let dataURL = imageDataURL(for: urlString)
        let metadataURL = imageMetadataURL(for: urlString)

        if let metadataData = try? Data(contentsOf: metadataURL),
           let metadata = try? JSONDecoder().decode(OfflineImageMetadata.self, from: metadataData),
           let data = try? Data(contentsOf: dataURL),
           let image = UIImage(data: data) {
            if Date().timeIntervalSince(metadata.cachedDate) > maxCacheAge {
                try? fileManager.removeItem(at: dataURL)
                try? fileManager.removeItem(at: metadataURL)
                return nil
            }
            return image
        }

        return getLegacyCachedImage(for: urlString)
    }

    private func getLegacyCachedImage(for urlString: String) -> UIImage? {
        let legacyURL = imageMetadataURL(for: urlString)
        guard let data = try? Data(contentsOf: legacyURL),
              let offlineImage = try? JSONDecoder().decode(LegacyOfflineImage.self, from: data),
              let image = UIImage(data: offlineImage.data) else {
            return nil
        }

        if Date().timeIntervalSince(offlineImage.cachedDate) > maxCacheAge {
            try? fileManager.removeItem(at: legacyURL)
            return nil
        }

        cacheImageData(offlineImage.data, for: urlString)
        return image
    }

    private func cacheThumbnailImages(_ thumbnails: [Int: String], for animeId: String) async {
        let thumbnailDirectory = cacheDirectory.appendingPathComponent("thumbnails_\(animeId)")

        if !fileManager.fileExists(atPath: thumbnailDirectory.path) {
            try? fileManager.createDirectory(at: thumbnailDirectory, withIntermediateDirectories: true)
        }

        for (episodeNumber, thumbnailURL) in thumbnails {
            guard let url = URL(string: thumbnailURL) else { continue }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      UIImage(data: data) != nil else {
                    continue
                }

                let imageFileURL = thumbnailDirectory.appendingPathComponent("episode_\(episodeNumber).img")
                let metaFileURL = thumbnailDirectory.appendingPathComponent("episode_\(episodeNumber).json")
                let metadata = OfflineImageMetadata(url: thumbnailURL, cachedDate: Date())
                let metaData = try JSONEncoder().encode(metadata)

                try data.write(to: imageFileURL, options: .atomic)
                try metaData.write(to: metaFileURL, options: .atomic)
                cacheImageData(data, for: thumbnailURL)
            } catch {
            }
        }
    }

    func getCachedThumbnail(for episodeNumber: Int, animeId: String) -> UIImage? {
        let thumbnailDirectory = cacheDirectory.appendingPathComponent("thumbnails_\(animeId)")
        let imageFileURL = thumbnailDirectory.appendingPathComponent("episode_\(episodeNumber).img")
        let metaFileURL = thumbnailDirectory.appendingPathComponent("episode_\(episodeNumber).json")

        if let metaData = try? Data(contentsOf: metaFileURL),
           let metadata = try? JSONDecoder().decode(OfflineImageMetadata.self, from: metaData),
           let data = try? Data(contentsOf: imageFileURL),
           let image = UIImage(data: data) {
            if Date().timeIntervalSince(metadata.cachedDate) > maxCacheAge {
                removeCachedThumbnail(for: episodeNumber, animeId: animeId)
                return nil
            }
            return image
        }

        let legacyFileURL = thumbnailDirectory.appendingPathComponent("episode_\(episodeNumber).json")
        guard let data = try? Data(contentsOf: legacyFileURL),
              let offlineImage = try? JSONDecoder().decode(LegacyOfflineImage.self, from: data),
              let image = UIImage(data: offlineImage.data) else {
            return nil
        }

        if Date().timeIntervalSince(offlineImage.cachedDate) > maxCacheAge {
            removeCachedThumbnail(for: episodeNumber, animeId: animeId)
            return nil
        }

        try? offlineImage.data.write(to: imageFileURL, options: .atomic)
        if let metadataData = try? JSONEncoder().encode(OfflineImageMetadata(url: offlineImage.url, cachedDate: offlineImage.cachedDate)) {
            try? metadataData.write(to: metaFileURL, options: .atomic)
        }
        return image
    }

    private func removeCachedThumbnail(for episodeNumber: Int, animeId: String) {
        let thumbnailDirectory = cacheDirectory.appendingPathComponent("thumbnails_\(animeId)")
        try? fileManager.removeItem(at: thumbnailDirectory.appendingPathComponent("episode_\(episodeNumber).img"))
        try? fileManager.removeItem(at: thumbnailDirectory.appendingPathComponent("episode_\(episodeNumber).json"))
    }

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
        }
    }

    func isNetworkAvailable() -> Bool {
        networkStatus == .satisfied
    }

    var isOfflineMode: Bool {
        !isNetworkAvailable()
    }

    func getCacheStatistics() -> (totalSize: Int64, animeCount: Int, imageCount: Int) {
        let totalSize = getCacheSize()

        let animeFiles = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("anime_") && $0.pathExtension == "json" }

        let imageFiles = try? fileManager.contentsOfDirectory(at: imageCacheDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "img" || $0.pathExtension == "json" }

        return (
            totalSize: totalSize,
            animeCount: animeFiles?.count ?? 0,
            imageCount: imageFiles?.count ?? 0
        )
    }
}
