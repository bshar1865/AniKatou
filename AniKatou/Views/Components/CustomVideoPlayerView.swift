import SwiftUI
import AVFoundation
import Combine

struct CustomVideoPlayerView: View {
    let videoURL: URL
    let headers: [String: String]?
    let subtitleTracks: [SubtitleTrack]?
    let intro: IntroOutro?
    let outro: IntroOutro?
    let animeId: String
    let episodeId: String
    let animeTitle: String
    let episodeNumber: String
    let episodeTitle: String?
    let thumbnailURL: String?
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
    @State private var progressSaveTimer: Timer?
    @State private var isFullscreen: Bool = false
    @State private var showQualityMenu: Bool = false
    @State private var showSubtitleMenu: Bool = false
    @State private var bufferingProgress: Double = 0
    @State private var isBuffering: Bool = false
    @State private var hasSkippedIntro: Bool = false
    @State private var hasSkippedOutro: Bool = false
    @State private var showAutoSkipNotification: Bool = false
    @State private var autoSkipMessage: String = ""
    @State private var isAutoSkipping: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video Player Background
                Color.black
                    .ignoresSafeArea()
                
                // Video Player Container
                ZStack {
                    VideoPlayerContainer(player: player)
                        .ignoresSafeArea()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Buffering Indicator
                    if isBuffering {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            
                            Text("Loading...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(width: 120, height: 120)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(16)
                        .transition(.opacity)
                    }
                }
                
                // Top Controls Overlay
                VStack {
                    HStack {
                        // Back Button
                        Button(action: {
                            withAnimation(.spring()) {
                                onDismiss()
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        
                        Spacer()
                        
                        // Title
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(animeTitle)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text("Episode \(episodeNumber)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    
                    Spacer()
                }
                .opacity(showControls ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: showControls)
                
                // Center Play/Pause Button and Seek Controls
                if showControls {
                    HStack(spacing: 25) {
                        // Rewind 5 seconds
                        Button(action: {
                            let newTime = max(0, currentTime - 5)
                            let seekTime = CMTime(seconds: newTime, preferredTimescale: 600)
                            player.seek(to: seekTime)
                            autoHideControls()
                        }) {
                            Image(systemName: "gobackward.5")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                        }
                        
                        // Play/Pause Button
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                if isPlaying {
                                    player.pause()
                                } else {
                                    player.play()
                                }
                                isPlaying.toggle()
                            }
                            autoHideControls()
                        }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 80, height: 80)
                        }
                        .scaleEffect(isPlaying ? 1 : 1.1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPlaying)
                        
                        // Forward 5 seconds
                        Button(action: {
                            let newTime = min(duration, currentTime + 5)
                            let seekTime = CMTime(seconds: newTime, preferredTimescale: 600)
                            player.seek(to: seekTime)
                            autoHideControls()
                        }) {
                            Image(systemName: "goforward.5")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                        }
                    }
                }
                
                // Bottom Controls Overlay
                VStack {
                    Spacer()
                    
                    // Skip Buttons
                    if showControls {
                        HStack {
                            Spacer()
                            
                            if let intro = intro, !AppSettings.shared.autoSkipIntro {
                                Button(action: {
                                    let seekTime = CMTime(seconds: Double(intro.end), preferredTimescale: 600)
                                    player.seek(to: seekTime)
                                    autoHideControls()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "forward.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Skip Intro")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.black.opacity(0.7))
                                            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                                    )
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                            
                            if let outro = outro, !AppSettings.shared.autoSkipOutro {
                                Button(action: {
                                    let seekTime = CMTime(seconds: Double(outro.end), preferredTimescale: 600)
                                    player.seek(to: seekTime)
                                    autoHideControls()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "forward.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Skip Outro")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.black.opacity(0.7))
                                            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                                    )
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                    }
                    
                    // Progress Bar and Time
                    VStack(spacing: 8) {
                        // Custom Progress Bar
                        VStack(spacing: 4) {
                            // Progress Bar Background
                            GeometryReader { barGeometry in
                                ZStack(alignment: .leading) {
                                    // Background Track
                                    Rectangle()
                                        .fill(Color.white.opacity(0.3))
                                        .frame(height: 4)
                                        .cornerRadius(2)
                                    
                                    // Buffering Progress
                                    Rectangle()
                                        .fill(Color.white.opacity(0.5))
                                        .frame(width: barGeometry.size.width * bufferingProgress, height: 4)
                                        .cornerRadius(2)
                                    
                                    // Playback Progress
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(width: barGeometry.size.width * (currentTime / max(duration, 1)), height: 4)
                                        .cornerRadius(2)
                                        .shadow(color: .white.opacity(0.5), radius: 2, x: 0, y: 0)
                                    
                                    // Seek Handle
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 16, height: 16)
                                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                        .offset(x: (barGeometry.size.width * (currentTime / max(duration, 1))) - 8)
                                        .opacity(showControls ? 1 : 0)
                                }
                            }
                            .frame(height: 16)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let percentage = value.location.x / (UIScreen.main.bounds.width - 48)
                                        let newTime = percentage * duration
                                        currentTime = max(0, min(newTime, duration))
                                        isSeeking = true
                                    }
                                    .onEnded { _ in
                                        let seekTime = CMTime(seconds: currentTime, preferredTimescale: 600)
                                        player.seek(to: seekTime) { _ in
                                            isSeeking = false
                                        }
                                        autoHideControls()
                                    }
                            )
                        }
                        .padding(.horizontal, 24)
                        
                        // Time Labels
                        HStack {
                            Text(formatTime(currentTime))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            
                            Spacer()
                            
                            Text(formatTime(duration))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 40)
                    }
                    .opacity(showControls ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: showControls)
                }
                
                // Subtitle Overlay
                if AppSettings.shared.subtitlesEnabled, !currentSubtitle.isEmpty {
                    subtitleOverlay(geometry: geometry)
                }
                
                // Auto-skip Notification
                if showAutoSkipNotification {
                    VStack {
                        Spacer()
                        
                        HStack {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text(autoSkipMessage)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.8))
                                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                        )
                        .transition(.scale.combined(with: .opacity))
                        
                        Spacer()
                    }
                    .animation(.easeInOut(duration: 0.3), value: showAutoSkipNotification)
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls.toggle()
            }
            if showControls {
                autoHideControls()
            }
        }
        .statusBarHidden(true)
    }
    
    private func setupPlayer() {
        let asset: AVURLAsset
        if let headers = headers {
            asset = AVURLAsset(url: videoURL, options: [
                "AVURLAssetHTTPHeaderFieldsKey": headers,
            ])
        } else {
            asset = AVURLAsset(url: videoURL)
        }
        
        let item = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: item)
        
        // Reset skip flags for new episode
        hasSkippedIntro = false
        hasSkippedOutro = false
        isAutoSkipping = false
        
        observePlayer()
        loadSubtitles()
        startProgressSaving()
        
        // Check for existing progress and seek to it
        if let existingProgress = WatchProgressManager.shared.getProgress(for: animeId, episodeID: episodeId) {
            let seekTime = CMTime(seconds: existingProgress.timestamp, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            player.seek(to: seekTime)
        }
        
        player.play()
        isPlaying = true
    }
    
    private func cleanupPlayer() {
        saveWatchProgress()
        player.pause()
        player.replaceCurrentItem(with: nil)
        hideControlsWorkItem?.cancel()
        progressSaveTimer?.invalidate()
        if let observer = subtitleTimeObserver {
            player.removeTimeObserver(observer)
            subtitleTimeObserver = nil
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
        
        // Observe time and buffering
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main) { time in
            if !isSeeking && !isAutoSkipping {
                currentTime = time.seconds
            }
            
            // Auto-skip intro - only skip when we enter the intro range
            if let intro = intro, AppSettings.shared.autoSkipIntro, !hasSkippedIntro, !isAutoSkipping {
                let introStart = Double(intro.start)
                let introEnd = Double(intro.end)
                
                // Only skip if we're within the intro range and haven't skipped yet
                if currentTime >= introStart && currentTime <= introEnd {
                    isAutoSkipping = true
                    let seekTime = CMTime(seconds: introEnd, preferredTimescale: 600)
                    player.seek(to: seekTime) { finished in
                        DispatchQueue.main.async {
                            self.isAutoSkipping = false
                        }
                    }
                    hasSkippedIntro = true
                    
                    // Show auto-skip notification
                    autoSkipMessage = "Skipped Intro"
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAutoSkipNotification = true
                    }
                    
                    // Hide notification after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAutoSkipNotification = false
                        }
                    }
                }
            }
            
            // Auto-skip outro - only skip when we enter the outro range
            if let outro = outro, AppSettings.shared.autoSkipOutro, !hasSkippedOutro, !isAutoSkipping {
                let outroStart = Double(outro.start)
                let outroEnd = Double(outro.end)
                
                // Only skip if we're within the outro range and haven't skipped yet
                if currentTime >= outroStart && currentTime <= outroEnd {
                    isAutoSkipping = true
                    let seekTime = CMTime(seconds: outroEnd, preferredTimescale: 600)
                    player.seek(to: seekTime) { finished in
                        DispatchQueue.main.async {
                            self.isAutoSkipping = false
                        }
                    }
                    hasSkippedOutro = true
                    
                    // Show auto-skip notification
                    autoSkipMessage = "Skipped Outro"
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAutoSkipNotification = true
                    }
                    
                    // Hide notification after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAutoSkipNotification = false
                        }
                    }
                }
            }
            
            // Update buffering status
            if let item = player.currentItem {
                let loadedRanges = item.loadedTimeRanges
                if let timeRange = loadedRanges.first?.timeRangeValue {
                    let bufferedDuration = timeRange.duration.seconds
                    let currentTime = time.seconds
                    bufferingProgress = min(1.0, bufferedDuration / max(duration, 1))
                    
                    // Check if we're buffering
                    let timeToEnd = bufferedDuration - currentTime
                    isBuffering = timeToEnd < 5.0 && !item.isPlaybackLikelyToKeepUp
                }
                
                // Update duration
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
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = false
            }
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
                // Subtitle loading failed silently
            }
        }
    }
    
    private func startProgressSaving() {
        progressSaveTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            self.saveWatchProgress()
        }
    }
    
    private func saveWatchProgress() {
        guard currentTime > 0 && duration > 0 else { return }
        
        WatchProgressManager.shared.saveProgress(
            animeID: animeId,
            episodeID: episodeId,
            timestamp: currentTime,
            duration: duration,
            title: animeTitle,
            episodeNumber: episodeNumber,
            thumbnailURL: thumbnailURL
        )
    }
}

// UIViewRepresentable to host AVPlayerLayer
struct VideoPlayerContainer: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.player = player
        return view
    }
    
    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.player = player
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
            playerLayer.videoGravity = .resizeAspect
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

// MARK: - Subtitle Overlay View
private extension CustomVideoPlayerView {
    @ViewBuilder
    func subtitleOverlay(geometry: GeometryProxy) -> some View {
        // Read settings
        let textSize = AppSettings.shared.subtitleTextSize > 0 ? AppSettings.shared.subtitleTextSize : AppSettings.defaultSubtitleTextSize
        let bgOpacity = AppSettings.shared.subtitleBackgroundOpacity > 0 ? AppSettings.shared.subtitleBackgroundOpacity : AppSettings.defaultSubtitleBackgroundOpacity
        let textColor = colorFromString(AppSettings.shared.subtitleTextColor)
        let showBg = AppSettings.shared.subtitleShowBackground
        let fontWeight = fontWeightFromString(AppSettings.shared.subtitleFontWeight)
        let maxLines = AppSettings.shared.subtitleMaxLines > 0 ? AppSettings.shared.subtitleMaxLines : AppSettings.defaultSubtitleMaxLines
        let position = AppSettings.shared.subtitlePosition
        
        let subtitleView = HStack {
            Spacer()
            Text(currentSubtitle)
                .font(.system(size: textSize, weight: fontWeight))
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)
                .lineLimit(maxLines)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Group {
                        if showBg {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(bgOpacity))
                        }
                    }
                )
                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
            Spacer()
        }
        .transition(.opacity)
        
        switch position {
        case "center":
            VStack {
                Spacer()
                subtitleView
                Spacer()
            }
        case "middleBottom":
            VStack {
                Spacer()
                subtitleView
                    .padding(.bottom, geometry.size.height * 0.18)
            }
        default: // "bottom"
            VStack {
                Spacer()
                subtitleView
                    .padding(.bottom, geometry.size.height * 0.08)
            }
        }
    }
    
    func colorFromString(_ str: String) -> Color {
        switch str {
        case "yellow": return .yellow
        case "cyan": return .cyan
        case "green": return .green
        case "orange": return .orange
        default: return .white
        }
    }
    
    func fontWeightFromString(_ str: String) -> Font.Weight {
        switch str {
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        default: return .medium
        }
    }
} 