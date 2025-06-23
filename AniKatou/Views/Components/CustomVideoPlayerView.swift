import SwiftUI
import AVFoundation
import Combine

struct CustomVideoPlayerView: View {
    let videoURL: URL
    let headers: [String: String]?
    let subtitleTracks: [SubtitleTrack]?
    let intro: IntroOutro?
    let outro: IntroOutro?
    let onDismiss: () -> Void
    
    @State private var player: AVPlayer = AVPlayer()
    @State private var isPlaying: Bool = true
    @State private var duration: Double = 0
    @State private var currentTime: Double = 0
    @State private var isSeeking: Bool = false
    @State private var showControls: Bool = true
    @State private var hideControlsWorkItem: DispatchWorkItem?
    @State private var subtitleCues: [SubtitleManager.SubtitleCue] = []
    @State private var currentSubtitle: String = ""
    @State private var subtitleTimeObserver: Any?
    
    var body: some View {
        ZStack(alignment: .center) {
            ZStack {
                VideoPlayerContainer(player: player)
                    .border(Color.red, width: 2)
                // Debug overlay
                VStack(alignment: .leading) {
                    Text("DEBUG: \(videoURL.absoluteString)")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .padding(2)
                        .background(Color.white.opacity(0.7))
                    Spacer()
                }
                .padding(4)
            }
            .onAppear {
                print("[DEBUG] CustomVideoPlayerView onAppear, url: \(videoURL)")
                let asset: AVURLAsset
                if let headers = headers {
                    asset = AVURLAsset(url: videoURL, options: [
                        "AVURLAssetHTTPHeaderFieldsKey": headers,
                        "AVURLAssetHTTPUserAgentKey": headers["User-Agent"] ?? ""
                    ])
                } else {
                    asset = AVURLAsset(url: videoURL)
                }
                let item = AVPlayerItem(asset: asset)
                player.replaceCurrentItem(with: item)
                player.play()
                isPlaying = true
                observePlayer()
                print("[DEBUG] Player assigned AVPlayerItem, asset: \(asset)")
                // Subtitles
                loadSubtitles()
            }
            .onDisappear {
                print("[DEBUG] CustomVideoPlayerView onDisappear")
                player.pause()
                player.replaceCurrentItem(with: nil)
                hideControlsWorkItem?.cancel()
                if let observer = subtitleTimeObserver {
                    player.removeTimeObserver(observer)
                    subtitleTimeObserver = nil
                }
            }
            .background(Color.black)
            .edgesIgnoringSafeArea(.all)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation { showControls = true }
                autoHideControls()
            }
            // Subtitle overlay (even more bottom, just above safe area and below seek bar)
            if AppSettings.shared.subtitlesEnabled, !currentSubtitle.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(currentSubtitle)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                            .shadow(radius: 4)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(.bottom, 24) // closer to bottom
                }
                .transition(.opacity)
            }
            // Play/Pause button (centered)
            if showControls {
                Button(action: {
                    if isPlaying {
                        player.pause()
                    } else {
                        player.play()
                    }
                    isPlaying.toggle()
                    autoHideControls()
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
                }
                .transition(.opacity)
            }
            // Controls overlay (top and bottom)
            if showControls {
                VStack {
                    HStack {
                        // Modern close button
                        Button(action: {
                            player.pause()
                            onDismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .padding(.top, 24)
                        .padding(.leading, 24)
                        Spacer()
                    }
                    Spacer()
                    // Skip intro/outro buttons (right above seek bar, aligned right)
                    HStack {
                        Spacer()
                        if let intro = intro, !AppSettings.shared.autoSkipIntro {
                            Button(action: {
                                let seekTime = CMTime(seconds: Double(intro.end), preferredTimescale: 600)
                                player.seek(to: seekTime)
                                autoHideControls()
                            }) {
                                Text("Skip Intro")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(8)
                            }
                            .padding(.trailing, 12)
                        }
                        if let outro = outro, !AppSettings.shared.autoSkipOutro {
                            Button(action: {
                                let seekTime = CMTime(seconds: Double(outro.end), preferredTimescale: 600)
                                player.seek(to: seekTime)
                                autoHideControls()
                            }) {
                                Text("Skip Outro")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(8)
                            }
                            .padding(.trailing, 24)
                        }
                    }
                    // Seek bar
                    VStack {
                        Slider(value: Binding(
                            get: { isSeeking ? currentTime : player.currentTime().seconds },
                            set: { newValue in
                                isSeeking = true
                                currentTime = newValue
                            }
                        ), in: 0...(duration > 0 ? duration : 1), onEditingChanged: { editing in
                            if !editing {
                                let seekTime = CMTime(seconds: currentTime, preferredTimescale: 600)
                                player.seek(to: seekTime) { _ in
                                    isSeeking = false
                                }
                                autoHideControls()
                            }
                        })
                        .accentColor(.white)
                        .padding(.horizontal, 24)
                        HStack {
                            Text(formatTime(currentTime))
                                .font(.caption2)
                                .foregroundColor(.white)
                            Spacer()
                            Text(formatTime(duration))
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 16)
                    }
                }
                .transition(.opacity)
            }
        }
    }
    
    private func observePlayer() {
        // Observe duration
        if let item = player.currentItem {
            if #available(iOS 16.0, *) {
                Task {
                    do {
                        let loadedDuration = try await item.asset.load(.duration)
                        await MainActor.run { duration = loadedDuration.seconds }
                    } catch {
                        await MainActor.run { duration = 0 }
                    }
                }
            } else {
                duration = item.asset.duration.seconds
            }
        }
        // Observe time
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main) { time in
            if !isSeeking {
                currentTime = time.seconds
            }
            if let item = player.currentItem {
                if #available(iOS 16.0, *) {
                    Task {
                        do {
                            let loadedDuration = try await item.asset.load(.duration)
                            await MainActor.run { duration = loadedDuration.seconds }
                        } catch {
                            await MainActor.run { duration = 0 }
                        }
                    }
                } else {
                    duration = item.asset.duration.seconds
                }
            }
        }
        autoHideControls()
    }
    
    private func autoHideControls() {
        hideControlsWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation { showControls = false }
        }
        hideControlsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "00:00" }
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    private func loadSubtitles() {
        guard AppSettings.shared.subtitlesEnabled,
              let tracks = subtitleTracks?.filter({ !$0.lang.lowercased().contains("thumbnail") }) else { return }
        // Look for English subtitles
        let selectedSubtitle = tracks.first { track in
            let langParts = track.lang.components(separatedBy: " - ")
            let mainLang = langParts[0].lowercased()
            return mainLang.contains("english")
        }
        guard let subtitle = selectedSubtitle,
              let subtitleURL = URL(string: subtitle.url) else { return }
        Task {
            do {
                let cues = try await SubtitleManager.shared.loadSubtitles(from: subtitleURL)
                await MainActor.run {
                    subtitleCues = cues
                    if let observer = subtitleTimeObserver {
                        player.removeTimeObserver(observer)
                        subtitleTimeObserver = nil
                    }
                    let observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main) { time in
                        let seconds = time.seconds
                        let current = cues.first { $0.startTime <= seconds && seconds <= $0.endTime }
                        currentSubtitle = current?.text ?? ""
                    }
                    subtitleTimeObserver = observer
                }
            } catch {
                print("[DEBUG] Failed to load subtitles: \(error)")
            }
        }
    }
}

// UIViewRepresentable to host AVPlayerLayer
struct VideoPlayerContainer: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.player = player
        view.layer.borderColor = UIColor.red.cgColor
        view.layer.borderWidth = 2
        print("[DEBUG] PlayerView created, frame: \(view.frame), bounds: \(view.bounds)")
        return view
    }
    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.player = player
        print("[DEBUG] updateUIView called, frame: \(uiView.frame), bounds: \(uiView.bounds)")
    }
}

class PlayerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            print("[DEBUG] PlayerView set player: \(String(describing: newValue))")
        }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
        print("[DEBUG] layoutSubviews called, frame: \(frame), bounds: \(bounds), playerLayer.frame: \(playerLayer.frame)")
        if window != nil {
            print("[DEBUG] PlayerView is in window")
        } else {
            print("[DEBUG] PlayerView is NOT in window")
        }
    }
} 