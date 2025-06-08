import Foundation
import AVFoundation
import UIKit

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
    }
    
    func loadSubtitles(from url: URL) async throws -> [SubtitleCue] {
        print("\n[Subtitles] Loading subtitles from URL: \(url)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SubtitleError.networkError
        }
        
        guard let content = String(data: data, encoding: .utf8) else {
            throw SubtitleError.decodingFailed
        }
        
        guard !content.isEmpty else {
            throw SubtitleError.emptyContent
        }
        
        print("\n[Subtitles] Parsing subtitle content")
        
        // Parse VTT format
        let lines = content.components(separatedBy: .newlines)
        var cues: [SubtitleCue] = []
        var currentStartTime: Double?
        var currentEndTime: Double?
        var currentText: String = ""
        var isParsingCue = false
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines, WEBVTT header, and NOTE lines
            if trimmedLine.isEmpty || trimmedLine == "WEBVTT" || trimmedLine.starts(with: "NOTE") {
                if isParsingCue && !currentText.isEmpty {
                    // Save current cue if we were parsing one
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
            
            // Parse timestamp line (e.g., "00:00:01.000 --> 00:00:04.000")
            if trimmedLine.contains("-->") {
                // Save previous cue if exists
                if isParsingCue && !currentText.isEmpty {
                    if let start = currentStartTime, let end = currentEndTime {
                        cues.append(SubtitleCue(startTime: start, endTime: end, text: currentText))
                    }
                }
                
                let times = trimmedLine.components(separatedBy: "-->").map { $0.trimmingCharacters(in: .whitespaces) }
                if times.count == 2 {
                    currentStartTime = parseVTTTime(times[0])
                    currentEndTime = parseVTTTime(times[1])
                    currentText = ""
                    isParsingCue = true
                }
            }
            // Parse text content
            else if isParsingCue {
                if !currentText.isEmpty {
                    currentText += "\n"
                }
                currentText += trimmedLine
                
                // If this is the last line or next line is a new cue, save current cue
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
        
        print("\n[Subtitles] Successfully parsed \(cues.count) subtitle cues")
        return cues
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
    
    func createSubtitleOverlay(for subtitles: [SubtitleCue], player: AVPlayer) -> SubtitleOverlayView {
        let overlayView = SubtitleOverlayView(frame: .zero)
        overlayView.subtitles = subtitles
        
        // Add time observer to update subtitles
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak overlayView] time in
            overlayView?.updateSubtitles(for: time.seconds)
        }
        
        return overlayView
    }
}

class SubtitleOverlayView: UIView {
    var subtitles: [SubtitleManager.SubtitleCue] = []
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 1, height: 1)
        label.layer.shadowOpacity = 0.8
        label.layer.shadowRadius = 2
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        addSubview(subtitleLabel)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -32)
        ])
    }
    
    func updateSubtitles(for time: Double) {
        let currentSubtitle = subtitles.first { subtitle in
            time >= subtitle.startTime && time <= subtitle.endTime
        }
        
        subtitleLabel.text = currentSubtitle?.text ?? ""
    }
} 