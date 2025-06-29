import SwiftUI
import AVKit
import AVFoundation

// MARK: - Custom Player View Controller
class CustomPlayerViewController: AVPlayerViewController {
    var onDismiss: (() -> Void)?
    private var subtitleOverlay: SubtitleOverlayView?
    private var timeObservers: [Any] = []
    private var notificationObservers: [NSObjectProtocol] = []
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed {
            cleanup()
            onDismiss?()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMemoryWarningObserver()
    }
    
    private func setupMemoryWarningObserver() {
        let observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        notificationObservers.append(observer)
    }
    
    @objc private func handleMemoryWarning() {
        player?.currentItem?.asset.cancelLoading()
    }
    
    func addTimeObserver(_ observer: Any) {
        timeObservers.append(observer)
    }
    
    func addSubtitleOverlay(_ overlay: SubtitleOverlayView) {
        subtitleOverlay?.removeFromSuperview()
        subtitleOverlay = overlay
        guard let contentView = view.subviews.first else { return }
        contentView.addSubview(overlay)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            overlay.heightAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    private func cleanup() {
        // Remove time observers
        timeObservers.forEach { observer in
            player?.removeTimeObserver(observer)
        }
        timeObservers.removeAll()
        
        // Remove notification observers
        notificationObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
        
        // Clean up player
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        
        // Remove subtitle overlay
        subtitleOverlay?.removeFromSuperview()
        subtitleOverlay = nil
    }
    
    deinit {
        cleanup()
    }
}

// MARK: - Video Player View
struct VideoPlayerView: UIViewControllerRepresentable {
    let streamingData: StreamingData
    let animeId: String
    let episodeId: String
    let animeTitle: String
    let episodeNumber: String
    let episodeTitle: String?
    let thumbnailURL: String?
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> CustomPlayerViewController {
        let playerController = CustomPlayerViewController()
        playerController.onDismiss = onDismiss
        setupPlayer(for: playerController, context: context)
        return playerController
    }
    
    func updateUIViewController(_ uiViewController: CustomPlayerViewController, context: Context) {
        // No-op - player setup is done once
    }
    
    private func setupPlayer(for playerController: CustomPlayerViewController, context: Context) {
        // Select best quality source
        let preferredQuality = AppSettings.shared.preferredQuality
        let source = streamingData.sources.first { source in
            source.quality?.lowercased() == preferredQuality.lowercased()
        } ?? streamingData.sources.sorted { (s1, s2) in
            guard let q1 = s1.quality?.replacingOccurrences(of: "p", with: ""),
                  let q2 = s2.quality?.replacingOccurrences(of: "p", with: ""),
                  let quality1 = Int(q1),
                  let quality2 = Int(q2) else { return false }
            return abs(quality1 - Int(preferredQuality.replacingOccurrences(of: "p", with: ""))!) <
                   abs(quality2 - Int(preferredQuality.replacingOccurrences(of: "p", with: ""))!)
        }.first ?? streamingData.sources.first
        
        guard let source = source,
              let url = URL(string: source.url) else {
            return
        }
        
        // Setup asset with headers
        let headers: [String: String] = streamingData.headers ?? [:]
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": headers,
            "AVURLAssetHTTPUserAgentKey": headers["User-Agent"] ?? ""
        ])
        
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 10
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        player.volume = 1.0
        playerController.player = player
        playerController.modalPresentationStyle = .fullScreen
        playerController.showsPlaybackControls = true
        
        // Setup intro/outro skipping with weak references
        setupIntroOutroSkipping(player: player, streamingData: streamingData, context: context)
        
        // Setup subtitles
        setupSubtitles(player: player, streamingData: streamingData, playerController: playerController)
        
        // Setup UI controls
        setupUIControls(player: player, streamingData: streamingData, playerController: playerController)
        
        // Setup progress tracking
        setupProgressTracking(player: player, playerController: playerController, context: context)
        
        // Restore previous progress
        restoreProgress(player: player)
    }
    
    private func setupIntroOutroSkipping(player: AVPlayer, streamingData: StreamingData, context: Context) {
        if let intro = streamingData.intro {
            let introObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
                queue: .main
            ) { [weak player] time in
                let currentTime = time.seconds
                if currentTime >= Double(intro.start) && currentTime < Double(intro.end) {
                    if AppSettings.shared.autoSkipIntro {
                        player?.seek(to: CMTime(seconds: Double(intro.end), preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
                    }
                }
            }
            context.coordinator.addTimeObserver(introObserver, for: player)
        }
        
        if let outro = streamingData.outro {
            let outroObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
                queue: .main
            ) { [weak player] time in
                let currentTime = time.seconds
                if currentTime >= Double(outro.start) && currentTime < Double(outro.end) {
                    if AppSettings.shared.autoSkipOutro {
                        player?.seek(to: CMTime(seconds: Double(outro.end), preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
                    }
                }
            }
            context.coordinator.addTimeObserver(outroObserver, for: player)
        }
    }
    
    private func setupSubtitles(player: AVPlayer, streamingData: StreamingData, playerController: CustomPlayerViewController) {
        guard AppSettings.shared.subtitlesEnabled,
              let tracks = streamingData.tracks?.filter({ !$0.lang.lowercased().contains("thumbnail") }) else {
            return
        }
        
            let selectedSubtitle = tracks.first { track in
                let langParts = track.lang.components(separatedBy: " - ")
                let mainLang = langParts[0].lowercased()
                return mainLang.contains("english")
            }
        
            if let subtitle = selectedSubtitle,
               let subtitleURL = URL(string: subtitle.url) {
                Task {
                    do {
                        let cues = try await SubtitleManager.shared.loadSubtitles(from: subtitleURL)
                        await MainActor.run {
                            let overlay = SubtitleManager.shared.createSubtitleOverlay(for: cues, player: player)
                            playerController.addSubtitleOverlay(overlay)
                        }
                    } catch {
                    print("Failed to load subtitles: \(error)")
                }
            }
        }
    }
    
    private func setupUIControls(player: AVPlayer, streamingData: StreamingData, playerController: CustomPlayerViewController) {
        // Add skip buttons if auto-skip is disabled
        if !AppSettings.shared.autoSkipIntro || !AppSettings.shared.autoSkipOutro {
            let skipButtonsView = UIStackView()
            skipButtonsView.axis = .vertical
            skipButtonsView.spacing = 8
            skipButtonsView.translatesAutoresizingMaskIntoConstraints = false
            
            if let intro = streamingData.intro, !AppSettings.shared.autoSkipIntro {
                let skipIntroButton = createSkipButton(title: "Skip Intro") { [weak player] in
                    player?.seek(to: CMTime(seconds: Double(intro.end), preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
                }
                skipButtonsView.addArrangedSubview(skipIntroButton)
            }
            
            if let outro = streamingData.outro, !AppSettings.shared.autoSkipOutro {
                let skipOutroButton = createSkipButton(title: "Skip Outro") { [weak player] in
                    player?.seek(to: CMTime(seconds: Double(outro.end), preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
                }
                skipButtonsView.addArrangedSubview(skipOutroButton)
            }
            
            playerController.contentOverlayView?.addSubview(skipButtonsView)
            NSLayoutConstraint.activate([
                skipButtonsView.topAnchor.constraint(equalTo: playerController.contentOverlayView!.topAnchor, constant: 16),
                skipButtonsView.trailingAnchor.constraint(equalTo: playerController.contentOverlayView!.trailingAnchor, constant: -16)
            ])
        }
        
        // Add close button
        let closeButton = createCloseButton { [weak playerController] in
            playerController?.dismiss(animated: true) {
                playerController?.onDismiss?()
            }
        }
        
        playerController.contentOverlayView?.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: playerController.contentOverlayView!.topAnchor, constant: 24),
            closeButton.leadingAnchor.constraint(equalTo: playerController.contentOverlayView!.leadingAnchor, constant: 24),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func createSkipButton(title: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.7)
        button.layer.cornerRadius = 4
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.baseBackgroundColor = .systemBackground.withAlphaComponent(0.7)
            config.cornerStyle = .medium
            config.title = title
            config.titleAlignment = .center
            config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            button.configuration = config
        } else {
            button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        }
        
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }
    
    private func createCloseButton(action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        let closeImage = UIImage(systemName: "xmark", withConfiguration: config)
        button.setImage(closeImage, for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 16
        button.layer.masksToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Add shadow
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }
    
    private func setupProgressTracking(player: AVPlayer, playerController: CustomPlayerViewController, context: Context) {
        // Add watch progress observer (save every 5 seconds)
        let progressObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 5.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: .main
        ) { [weak player] _ in
            guard let player = player,
                  let currentItem = player.currentItem else { return }
            
            let currentTime = player.currentTime().seconds
            
            Task {
                do {
                    let duration = try await currentItem.asset.load(.duration).seconds
                    
                    // Only save if we have valid time and duration
                    if currentTime > 0 && duration > 0 {
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
                } catch {
                    print("Failed to load duration: \(error)")
                }
            }
        }
        
        context.coordinator.addTimeObserver(progressObserver, for: player)
        
        // Add playback end observer
        let endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
        }
        
        context.coordinator.addNotificationObserver(endObserver)
    }
    
    private func restoreProgress(player: AVPlayer) {
        if let existingProgress = WatchProgressManager.shared.getProgress(for: animeId, episodeID: episodeId) {
            let seekTime = CMTime(seconds: existingProgress.timestamp, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            player.seek(to: seekTime)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        private var timeObservers: [(player: AVPlayer, observer: Any)] = []
        private var notificationObservers: [NSObjectProtocol] = []
        
        func addTimeObserver(_ observer: Any, for player: AVPlayer) {
            timeObservers.append((player: player, observer: observer))
        }
        
        func addNotificationObserver(_ observer: NSObjectProtocol) {
            notificationObservers.append(observer)
        }
        
        deinit {
            cleanup()
        }
        
        private func cleanup() {
            // Remove time observers
            timeObservers.forEach { player, observer in
                player.removeTimeObserver(observer)
            }
            timeObservers.removeAll()
            
            // Remove notification observers
            notificationObservers.forEach { observer in
                NotificationCenter.default.removeObserver(observer)
            }
            notificationObservers.removeAll()
        }
    }
} 