import Foundation
import AVFoundation

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
    private let storageURL: URL

    private override init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.storageURL = docs.appendingPathComponent("hls_downloads.json")
        super.init()
        loadStoredDownloads()
    }

    func startDownload(streamURL: URL, animeId: String, episodeId: String, animeTitle: String, episodeNumber: String, headers: [String: String]? = nil) {
        if downloads.contains(where: { $0.episodeId == episodeId && $0.state == .downloading }) {
            return
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
            localPath: nil,
            progress: 0,
            state: .queued,
            errorMessage: nil,
            createdAt: Date()
        )

        downloads.insert(item, at: 0)
        taskMap[task.taskIdentifier] = item.id
        setState(for: item.id, state: .downloading)
        persist()
        task.resume()
    }

    func cancelDownload(_ item: HLSDownloadItem) {
        if let taskID = taskMap.first(where: { $0.value == item.id })?.key,
           let task = session.getAllTasksSync().first(where: { $0.taskIdentifier == taskID }) {
            task.cancel()
        }
        setState(for: item.id, state: .cancelled)
    }

    func removeDownload(_ item: HLSDownloadItem) {
        if let localPath = item.localPath {
            try? FileManager.default.removeItem(atPath: localPath)
        }
        downloads.removeAll { $0.id == item.id }
        taskMap = taskMap.filter { $0.value != item.id }
        persist()
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
}

extension HLSDownloadManager: AVAssetDownloadDelegate {
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = taskMap[assetDownloadTask.taskIdentifier] else { return }
        setLocalPath(for: id, path: location.path)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = taskMap[task.taskIdentifier] else { return }
        defer { taskMap.removeValue(forKey: task.taskIdentifier) }

        if let error {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled {
                setState(for: id, state: .cancelled)
            } else {
                setState(for: id, state: .failed, error: error.localizedDescription)
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

private extension AVAssetDownloadURLSession {
    func getAllTasksSync() -> [URLSessionTask] {
        let semaphore = DispatchSemaphore(value: 0)
        var fetchedTasks: [URLSessionTask] = []
        getAllTasks { tasks in
            fetchedTasks = tasks
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 2)
        return fetchedTasks
    }
}
