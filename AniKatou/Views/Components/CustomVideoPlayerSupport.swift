import SwiftUI
import AVFoundation

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

final class PlayerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
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

extension CustomVideoPlayerView {
    @ViewBuilder
    func subtitleOverlay(geometry: GeometryProxy, currentSubtitle: String) -> some View {
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
        default:
            VStack {
                Spacer()
                subtitleView
                    .padding(.bottom, geometry.size.height * 0.08)
            }
        }
    }

    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "00:00" }
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
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
