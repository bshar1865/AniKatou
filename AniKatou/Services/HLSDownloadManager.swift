import Foundation
import AVFoundation

struct DownloadedSubtitleTrack: Codable {
    let lang: String
    let remoteURL: String
    var localPath: String?
}

struct HLSDownloadItem: Identifiable, Codable {
    enum State: String, Codable {
        case queued
        case downloading
        case completed
        case failed
        case cancelled
    }

    let id: UUID
    let animeId: String
    let episodeId: String
    let animeTitle: String
    let episodeNumber: String
    let streamURL: String
    var subtitleTracks: [DownloadedSubtitleTrack]
    var intro: IntroOutro?
    var outro: IntroOutro?
    var localPath: String?
    var progress: Double
    var state: State
    var errorMessage: String?
    let createdAt: Date
}

final class HLSDownloadManager: NSObject, ObservableObject {
    static let shared = HLSDownloadManager()

    @Published private(set) var downloads: [HLSDownloadItem] = []

    private lazy var session: AVAssetDownloadURLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "me.bshar.AniKatou.hls-downloads")
        config.waitsForConnectivity = true
        config.httpMaximumConnectionsPerHost = 2
        return AVAssetDownloadURLSession(configuration: config, assetDownloadDelegate: self, delegateQueue: .main)
    }()

    private var taskMap: [Int: UUID] = [:]
    private var activeTasks: [UUID: AVAssetDownloadTask] = [:]
    private let storageURL: URL

    private override init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        storageURL = docs.appendingPathComponent("hls_downloads.json")
        super.init()
        loadStoredDownloads()
    }

    func startDownload(
        streamURL: URL,
        animeId: String,
        episodeId: String,
        animeTitle: String,
        episodeNumber: String,
        headers: [String: String]? = nil,
        subtitleTracks: [SubtitleTrack]? = nil,
        intro: IntroOutro? = nil,
        outro: IntroOutro? = nil
    ) {
        if let existingIndex = downloads.firstIndex(where: { $0.episodeId == episodeId }) {
            let existingState = downloads[existingIndex].state
            switch existingState {
            case .queued, .downloading:
                return
            case .completed:
                if let path = downloads[existingIndex].localPath,
                   FileManager.default.fileExists(atPath: path) {
                    return
                }
                downloads.remove(at: existingIndex)
                persist()
            case .failed, .cancelled:
                downloads.remove(at: existingIndex)
                persist()
            }
        }

        let options = headers == nil ? nil : ["AVURLAssetHTTPHeaderFieldsKey": headers!]
        let asset = AVURLAsset(url: streamURL, options: options)

        guard let task = session.makeAssetDownloadTask(
            asset: asset,
            assetTitle: "\(animeTitle) - Episode \(episodeNumber)",
            assetArtworkData: nil,
            options: nil
        ) else {
            return
        }

        let item = HLSDownloadItem(
            id: UUID(),
            animeId: animeId,
            episodeId: episodeId,
            animeTitle: animeTitle,
            episodeNumber: episodeNumber,
            streamURL: streamURL.absoluteString,
            subtitleTracks: (subtitleTracks ?? []).map {
                DownloadedSubtitleTrack(lang: $0.lang, remoteURL: $0.url, localPath: nil)
            },
            intro: intro,
            outro: outro,
            localPath: nil,
            progress: 0,
            state: .queued,
            errorMessage: nil,
            createdAt: Date()
        )

        downloads.insert(item, at: 0)
        taskMap[task.taskIdentifier] = item.id
        activeTasks[item.id] = task
        setState(for: item.id, state: .downloading)
        persist()
        task.resume()

        if let subtitleTracks, !subtitleTracks.isEmpty {
            Task { [weak self] in
                await self?.cacheSubtitleFiles(forEpisodeId: episodeId, tracks: subtitleTracks, headers: headers)
            }
        }
    }

    func cancelDownload(_ item: HLSDownloadItem) {
        activeTasks[item.id]?.cancel()
        setState(for: item.id, state: .cancelled)
    }

    func removeDownload(_ item: HLSDownloadItem) {
        if item.state == .queued || item.state == .downloading {
            activeTasks[item.id]?.cancel()
        }

        if let localPath = item.localPath {
            try? FileManager.default.removeItem(atPath: localPath)
        }
        for track in item.subtitleTracks {
            if let localPath = track.localPath {
                try? FileManager.default.removeItem(atPath: localPath)
            }
        }

        downloads.removeAll { $0.id == item.id }
        activeTasks.removeValue(forKey: item.id)
        taskMap = taskMap.filter { $0.value != item.id }
        persist()
    }

    func removeDownloads(for animeId: String) {
        let items = downloads.filter { $0.animeId == animeId }
        for item in items {
            removeDownload(item)
        }
    }

    func downloadedItem(for episodeId: String) -> HLSDownloadItem? {
        downloads.first { item in
            guard item.episodeId == episodeId,
                  item.state == .completed,
                  let path = item.localPath else {
                return false
            }
            return FileManager.default.fileExists(atPath: path)
        }
    }

    func isEpisodeDownloaded(_ episodeId: String) -> Bool {
        downloadedItem(for: episodeId) != nil
    }

    func downloadedEpisodeCount(for animeId: String) -> Int {
        downloads.filter { $0.animeId == animeId && downloadedItem(for: $0.episodeId) != nil }.count
    }

    func localFileURL(for episodeId: String) -> URL? {
        guard let path = downloadedItem(for: episodeId)?.localPath else { return nil }
        return URL(fileURLWithPath: path)
    }

    func localSubtitleTracks(for episodeId: String) -> [SubtitleTrack]? {
        guard let item = downloadedItem(for: episodeId) else { return nil }
        let localTracks = item.subtitleTracks.compactMap { track -> SubtitleTrack? in
            guard let localPath = track.localPath else { return nil }
            return SubtitleTrack(url: URL(fileURLWithPath: localPath).absoluteString, lang: track.lang)
        }
        return localTracks.isEmpty ? nil : localTracks
    }

    func introOutro(for episodeId: String) -> (intro: IntroOutro?, outro: IntroOutro?) {
        guard let item = downloads.first(where: { $0.episodeId == episodeId }) else {
            return (nil, nil)
        }
        return (item.intro, item.outro)
    }

    private func setState(for id: UUID, state: HLSDownloadItem.State, error: String? = nil) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[index].state = state
        downloads[index].errorMessage = error
        persist()
    }

    private func updateProgress(for id: UUID, progress: Double) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[index].progress = max(0, min(progress, 1))
        persist()
    }

    private func setLocalPath(for id: UUID, path: String) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[index].localPath = path
        downloads[index].progress = 1
        downloads[index].state = .completed
        persist()
    }

    private func updateSubtitlePath(for episodeId: String, remoteURL: String, localPath: String) {
        guard let itemIndex = downloads.firstIndex(where: { $0.episodeId == episodeId }) else { return }
        guard let trackIndex = downloads[itemIndex].subtitleTracks.firstIndex(where: { $0.remoteURL == remoteURL }) else { return }
        downloads[itemIndex].subtitleTracks[trackIndex].localPath = localPath
        persist()
    }

    private func friendlyDownloadErrorMessage(for error: NSError) -> String {
        switch error.code {
        case NSURLErrorNotConnectedToInternet:
            return "Needs internet to continue"
        case NSURLErrorTimedOut:
            return "Download timed out"
        case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
            return "Unable to reach the video server"
        default:
            return "Download could not be completed"
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(downloads) {
            try? data.write(to: storageURL)
        }
    }

    private func loadStoredDownloads() {
        guard let data = try? Data(contentsOf: storageURL),
              let saved = try? JSONDecoder().decode([HLSDownloadItem].self, from: data) else {
            downloads = []
            return
        }
        downloads = saved
    }

    private func cacheSubtitleFiles(forEpisodeId episodeId: String, tracks: [SubtitleTrack], headers: [String: String]?) async {
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let subtitleDir = docs.appendingPathComponent("DownloadedSubtitles", isDirectory: true)
        try? fileManager.createDirectory(at: subtitleDir, withIntermediateDirectories: true)

        for (index, track) in tracks.enumerated() {
            guard let remoteURL = URL(string: track.url) else { continue }

            do {
                var request = URLRequest(url: remoteURL)
                headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode) else {
                    continue
                }

                let safeEpisodeId = episodeId.replacingOccurrences(of: "/", with: "_")
                let safeLang = track.lang.replacingOccurrences(of: " ", with: "_")
                let localURL = subtitleDir.appendingPathComponent("\(safeEpisodeId)_\(safeLang)_\(index).vtt")
                try data.write(to: localURL, options: .atomic)

                DispatchQueue.main.async { [weak self] in
                    self?.updateSubtitlePath(for: episodeId, remoteURL: track.url, localPath: localURL.path)
                }
            } catch {
                continue
            }
        }
    }
}

extension HLSDownloadManager: AVAssetDownloadDelegate {
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = taskMap[assetDownloadTask.taskIdentifier] else { return }
        setLocalPath(for: id, path: location.path)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = taskMap[task.taskIdentifier] else { return }
        defer {
            taskMap.removeValue(forKey: task.taskIdentifier)
            activeTasks.removeValue(forKey: id)
        }

        if let error = error {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled {
                setState(for: id, state: .cancelled)
            } else {
                setState(for: id, state: .failed, error: friendlyDownloadErrorMessage(for: nsError))
            }
        } else {
            setState(for: id, state: .completed)
        }
    }

    func urlSession(
        _ session: URLSession,
        assetDownloadTask: AVAssetDownloadTask,
        didLoad timeRange: CMTimeRange,
        totalTimeRangesLoaded loadedTimeRanges: [NSValue],
        timeRangeExpectedToLoad: CMTimeRange
    ) {
        guard let id = taskMap[assetDownloadTask.taskIdentifier] else { return }
        let loadedDuration = loadedTimeRanges
            .map { $0.timeRangeValue.duration.seconds }
            .reduce(0, +)
        let expectedDuration = timeRangeExpectedToLoad.duration.seconds
        guard expectedDuration > 0 else { return }
        updateProgress(for: id, progress: loadedDuration / expectedDuration)
    }
}
