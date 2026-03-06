import Foundation

class SubtitleManager {
    static let shared = SubtitleManager()
    private init() {}

    struct SubtitleCue {
        let startTime: Double
        let endTime: Double
        let text: String
    }

    enum SubtitleError: Error {
        case invalidFormat
        case decodingFailed
        case emptyContent
        case networkError
        case fileReadError
    }

    func loadSubtitles(from url: URL, headers: [String: String]? = nil) async throws -> [SubtitleCue] {
        let data: Data

        if url.isFileURL {
            do {
                data = try Data(contentsOf: url)
            } catch {
                throw SubtitleError.fileReadError
            }
        } else {
            data = try await loadRemoteSubtitleData(from: url, headers: headers)
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw SubtitleError.decodingFailed
        }

        guard !content.isEmpty else {
            throw SubtitleError.emptyContent
        }

        let lines = content.components(separatedBy: .newlines)
        var cues: [SubtitleCue] = []
        var currentStartTime: Double?
        var currentEndTime: Double?
        var currentText = ""
        var isParsingCue = false

        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedLine.isEmpty || trimmedLine == "WEBVTT" || trimmedLine.starts(with: "NOTE") {
                if isParsingCue && !currentText.isEmpty {
                    if let start = currentStartTime, let end = currentEndTime {
                        cues.append(SubtitleCue(startTime: start, endTime: end, text: currentText))
                    }
                    isParsingCue = false
                    currentStartTime = nil
                    currentEndTime = nil
                    currentText = ""
                }
                continue
            }

            if trimmedLine.contains("-->") {
                if isParsingCue && !currentText.isEmpty,
                   let start = currentStartTime,
                   let end = currentEndTime {
                    cues.append(SubtitleCue(startTime: start, endTime: end, text: currentText))
                }

                let times = trimmedLine.components(separatedBy: "-->").map { $0.trimmingCharacters(in: .whitespaces) }
                if times.count == 2 {
                    currentStartTime = parseVTTTime(times[0])
                    currentEndTime = parseVTTTime(times[1])
                    currentText = ""
                    isParsingCue = true
                }
            } else if isParsingCue {
                if !currentText.isEmpty {
                    currentText += "\n"
                }
                currentText += trimmedLine

                let isLastLine = index == lines.count - 1
                let nextLine = isLastLine ? "" : lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                if isLastLine || nextLine.isEmpty || nextLine.contains("-->") {
                    if let start = currentStartTime, let end = currentEndTime {
                        cues.append(SubtitleCue(startTime: start, endTime: end, text: currentText))
                        currentStartTime = nil
                        currentEndTime = nil
                        currentText = ""
                        isParsingCue = false
                    }
                }
            }
        }

        return cues
    }

    private func loadRemoteSubtitleData(from url: URL, headers: [String: String]?) async throws -> Data {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 5
        let session = URLSession(configuration: config)
        let deadline = Date().addingTimeInterval(5)
        var lastError: Error?

        while Date() < deadline {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 5
                headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
                let (remoteData, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw SubtitleError.networkError
                }
                return remoteData
            } catch {
                lastError = error
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        throw lastError ?? SubtitleError.networkError
    }

    private func parseVTTTime(_ timeString: String) -> Double {
        let components = timeString.components(separatedBy: ":")
        guard components.count >= 2 else { return 0 }

        var hours = 0.0
        var minutes = 0.0
        var seconds = 0.0

        if components.count == 3 {
            hours = Double(components[0]) ?? 0
            minutes = Double(components[1]) ?? 0
            let secondsParts = components[2].components(separatedBy: ".")
            seconds = Double(secondsParts[0]) ?? 0
            if secondsParts.count > 1 {
                seconds += Double("0." + secondsParts[1]) ?? 0
            }
        } else {
            minutes = Double(components[0]) ?? 0
            let secondsParts = components[1].components(separatedBy: ".")
            seconds = Double(secondsParts[0]) ?? 0
            if secondsParts.count > 1 {
                seconds += Double("0." + secondsParts[1]) ?? 0
            }
        }

        return hours * 3600 + minutes * 60 + seconds
    }
}
