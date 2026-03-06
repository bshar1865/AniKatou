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
        let textSize = AppSettings.shared.subtitleTextSize
        let bgOpacity = AppSettings.shared.subtitleBackgroundOpacity
        let textColor = colorFromString(AppSettings.shared.subtitleTextColor)
        let showBg = AppSettings.shared.subtitleShowBackground
        let fontWeight = fontWeightFromString(AppSettings.shared.subtitleFontWeight)
        let maxLines = AppSettings.shared.subtitleMaxLines
        let position = AppSettings.shared.subtitlePosition
        let shadowOpacity = AppSettings.shared.subtitleShadowOpacity
        let verticalOffset = CGFloat(AppSettings.shared.subtitleVerticalOffset)

        let subtitleView = HStack {
            Spacer()
            Text(currentSubtitle)
                .font(.system(size: textSize, weight: fontWeight))
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)
                .lineLimit(maxLines)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background {
                    if showBg {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(bgOpacity))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                }
                .shadow(color: .black.opacity(shadowOpacity), radius: 10, x: 0, y: 5)
            Spacer()
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))

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
                    .padding(.bottom, geometry.size.height * 0.16 + verticalOffset)
            }
        default:
            VStack {
                Spacer()
                subtitleView
                    .padding(.bottom, geometry.safeAreaInsets.bottom + geometry.size.height * 0.06 + verticalOffset)
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
