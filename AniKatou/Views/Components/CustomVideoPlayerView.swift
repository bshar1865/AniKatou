import SwiftUI
import AVFoundation

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
    @State private var isPlaying = true
    @State private var duration: Double = 0
    @State private var currentTime: Double = 0
    @State private var isSeeking = false
    @State private var showControls = true
    @State private var hideControlsWorkItem: DispatchWorkItem?
    @State private var currentSubtitle = ""
    @State private var subtitleTimeObserver: Any?
    @State private var playbackTimeObserver: Any?
    @State private var progressSaveTimer: Timer?
    @State private var bufferingProgress: Double = 0
    @State private var isBuffering = false
    @State private var hasSkippedIntro = false
    @State private var hasSkippedOutro = false
    @State private var showAutoSkipNotification = false
    @State private var autoSkipMessage = ""
    @State private var isAutoSkipping = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                ZStack {
                    VideoPlayerContainer(player: player)
                        .ignoresSafeArea()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    LinearGradient(
                        colors: [Color.black.opacity(showControls ? 0.22 : 0.08), .clear, Color.black.opacity(showControls ? 0.32 : 0.16)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                    if isBuffering {
                        VStack(spacing: 14) {
                            ProgressView()
                                .scaleEffect(1.4)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))

                            Text("Loading video")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(width: 138, height: 118)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .transition(.opacity)
                    }
                }

                VStack {
                    HStack(spacing: 12) {
                        Button(action: {
                            withAnimation(.spring()) {
                                onDismiss()
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 42, height: 42)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(animeTitle)
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Text(episodeTitle?.isEmpty == false ? "Episode \(episodeNumber) • \(episodeTitle!)" : "Episode \(episodeNumber)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer()
                }
                .opacity(showControls ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: showControls)

                if showControls {
                    HStack(spacing: 24) {
                        playerControlButton(symbol: "gobackward.5") {
                            let newTime = max(0, currentTime - 5)
                            let seekTime = CMTime(seconds: newTime, preferredTimescale: 600)
                            player.seek(to: seekTime)
                            autoHideControls()
                        }

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
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 86, height: 86)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                        }
                        .scaleEffect(isPlaying ? 1 : 1.07)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPlaying)

                        playerControlButton(symbol: "goforward.5") {
                            let newTime = min(duration, currentTime + 5)
                            let seekTime = CMTime(seconds: newTime, preferredTimescale: 600)
                            player.seek(to: seekTime)
                            autoHideControls()
                        }
                    }
                }

                VStack {
                    Spacer()

                    VStack(spacing: 10) {
                        VStack(spacing: 4) {
                            GeometryReader { barGeometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.22))
                                        .frame(height: 5)

                                    Capsule()
                                        .fill(Color.white.opacity(0.35))
                                        .frame(width: barGeometry.size.width * bufferingProgress, height: 5)

                                    Capsule()
                                        .fill(.white)
                                        .frame(width: barGeometry.size.width * (currentTime / max(duration, 1)), height: 5)
                                        .shadow(color: .white.opacity(0.45), radius: 2, x: 0, y: 0)

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

                        HStack {
                            Text(formatTime(currentTime))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.92))

                            Spacer()

                            Text(formatTime(duration))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.92))
                        }
                        .padding(.horizontal, 28)
                    }
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal, 18)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 10))
                    .opacity(showControls ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: showControls)
                }

                if AppSettings.shared.subtitlesEnabled, !currentSubtitle.isEmpty {
                    subtitleOverlay(geometry: geometry, currentSubtitle: currentSubtitle)
                }

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
                                .fill(.ultraThinMaterial)
                                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                        )
                        .transition(.scale.combined(with: .opacity))

                        Spacer()
                    }
                    .animation(.easeInOut(duration: 0.3), value: showAutoSkipNotification)
                }
            }
        }
        .onAppear(perform: setupPlayer)
        .onDisappear(perform: cleanupPlayer)
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

    private func playerControlButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
    }

    private func setupPlayer() {
        let asset: AVURLAsset
        if let headers = headers {
            asset = AVURLAsset(url: videoURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        } else {
            asset = AVURLAsset(url: videoURL)
        }

        let item = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: item)

        hasSkippedIntro = false
        hasSkippedOutro = false
        isAutoSkipping = false

        updateDuration()
        observePlayer()
        loadSubtitles()
        startProgressSaving()

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
        hideControlsWorkItem = nil
        progressSaveTimer?.invalidate()
        progressSaveTimer = nil

        if let observer = playbackTimeObserver {
            player.removeTimeObserver(observer)
            playbackTimeObserver = nil
        }

        if let observer = subtitleTimeObserver {
            player.removeTimeObserver(observer)
            subtitleTimeObserver = nil
        }
    }

    private func observePlayer() {
        if let observer = playbackTimeObserver {
            player.removeTimeObserver(observer)
            playbackTimeObserver = nil
        }

        playbackTimeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main) { time in
            if !isSeeking && !isAutoSkipping {
                currentTime = time.seconds
            }

            if let intro = intro, AppSettings.shared.autoSkipIntro, !hasSkippedIntro, !isAutoSkipping, !isSeeking {
                let introStart = Double(intro.start)
                let introEnd = Double(intro.end)

                if introEnd > introStart, time.seconds >= introStart, time.seconds <= introEnd {
                    isAutoSkipping = true
                    let seekTime = CMTime(seconds: introEnd, preferredTimescale: 600)
                    player.seek(to: seekTime) { _ in
                        DispatchQueue.main.async {
                            self.isAutoSkipping = false
                        }
                    }
                    hasSkippedIntro = true
                    showAutoSkip(message: "Skipped Intro")
                }
            }

            if let outro = outro, AppSettings.shared.autoSkipOutro, !hasSkippedOutro, !isAutoSkipping, !isSeeking {
                let outroStart = Double(outro.start)
                let outroEnd = Double(outro.end)

                if outroEnd > outroStart, time.seconds >= outroStart, time.seconds <= outroEnd {
                    isAutoSkipping = true
                    let seekTime = CMTime(seconds: outroEnd, preferredTimescale: 600)
                    player.seek(to: seekTime) { _ in
                        DispatchQueue.main.async {
                            self.isAutoSkipping = false
                        }
                    }
                    hasSkippedOutro = true
                    showAutoSkip(message: "Skipped Outro")
                }
            }

            if let item = player.currentItem {
                let loadedRanges = item.loadedTimeRanges
                if let timeRange = loadedRanges.first?.timeRangeValue {
                    let bufferedDuration = timeRange.duration.seconds
                    let playbackTime = time.seconds
                    bufferingProgress = min(1.0, bufferedDuration / max(duration, 1))
                    let timeToEnd = bufferedDuration - playbackTime
                    isBuffering = timeToEnd < 5.0 && !item.isPlaybackLikelyToKeepUp
                }
            }
        }

        autoHideControls()
    }

    private func showAutoSkip(message: String) {
        autoSkipMessage = message
        withAnimation(.easeInOut(duration: 0.3)) {
            showAutoSkipNotification = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showAutoSkipNotification = false
            }
        }
    }

    private func updateDuration() {
        guard let item = player.currentItem else {
            duration = 0
            return
        }

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

    private func loadSubtitles() {
        guard AppSettings.shared.subtitlesEnabled,
              let tracks = subtitleTracks?.filter({ !$0.lang.lowercased().contains("thumbnail") }) else {
            return
        }

        let selectedSubtitle = tracks.first { track in
            let langParts = track.lang.components(separatedBy: " - ")
            let mainLang = langParts[0].lowercased()
            return mainLang.contains("english")
        }

        guard let subtitle = selectedSubtitle,
              let subtitleURL = URL(string: subtitle.url) else {
            return
        }

        Task {
            do {
                let cues = try await SubtitleManager.shared.loadSubtitles(from: subtitleURL, headers: headers)
                await MainActor.run {
                    if let observer = subtitleTimeObserver {
                        player.removeTimeObserver(observer)
                        subtitleTimeObserver = nil
                    }
                    subtitleTimeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main) { time in
                        let seconds = time.seconds
                        let current = cues.first { $0.startTime <= seconds && seconds <= $0.endTime }
                        currentSubtitle = current?.text ?? ""
                    }
                }
            } catch {
            }
        }
    }

    private func startProgressSaving() {
        progressSaveTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            saveWatchProgress()
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
