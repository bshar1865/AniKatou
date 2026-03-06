import SwiftUI

struct SubtitleSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var previewText = "Subtitles should stay readable without covering too much of the video."

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Preview")
                        .font(.headline)

                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.black, Color.black.opacity(0.74), Color.gray.opacity(0.38)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 220)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )

                        VStack {
                            Spacer()

                            Text(previewText)
                                .font(.system(size: viewModel.subtitleTextSize, weight: fontWeight))
                                .foregroundColor(textColor)
                                .multilineTextAlignment(.center)
                                .lineLimit(viewModel.subtitleMaxLines)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background {
                                    if viewModel.subtitleShowBackground {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.black.opacity(viewModel.subtitleBackgroundOpacity))
                                    }
                                }
                                .shadow(color: .black.opacity(viewModel.subtitleShadowOpacity), radius: 10, x: 0, y: 5)
                                .padding(.horizontal, 20)
                                .padding(.bottom, previewBottomPadding)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Text") {
                sliderRow(
                    title: "Text Size",
                    valueText: "\(Int(viewModel.subtitleTextSize))",
                    value: $viewModel.subtitleTextSize,
                    range: 12...32,
                    step: 1
                )

                Picker("Font Weight", selection: $viewModel.subtitleFontWeight) {
                    Text("Light").tag("light")
                    Text("Regular").tag("regular")
                    Text("Medium").tag("medium")
                    Text("Semibold").tag("semibold")
                    Text("Bold").tag("bold")
                }

                Picker("Text Color", selection: $viewModel.subtitleTextColor) {
                    Text("White").tag("white")
                    Text("Yellow").tag("yellow")
                    Text("Cyan").tag("cyan")
                    Text("Green").tag("green")
                    Text("Orange").tag("orange")
                }

                Stepper("Max Lines: \(viewModel.subtitleMaxLines)", value: $viewModel.subtitleMaxLines, in: 1...5)
            }

            Section("Shade & Position") {
                Toggle("Show Background", isOn: $viewModel.subtitleShowBackground)

                if viewModel.subtitleShowBackground {
                    sliderRow(
                        title: "Background Opacity",
                        valueText: "\(Int(viewModel.subtitleBackgroundOpacity * 100))%",
                        value: $viewModel.subtitleBackgroundOpacity,
                        range: 0.15...1.0,
                        step: 0.05
                    )
                }

                sliderRow(
                    title: "Text Shade",
                    valueText: "\(Int(viewModel.subtitleShadowOpacity * 100))%",
                    value: $viewModel.subtitleShadowOpacity,
                    range: 0.1...1.0,
                    step: 0.05
                )

                sliderRow(
                    title: "Bottom Offset",
                    valueText: "\(Int(viewModel.subtitleVerticalOffset)) pt",
                    value: $viewModel.subtitleVerticalOffset,
                    range: 0...40,
                    step: 1
                )

                Picker("Position", selection: $viewModel.subtitlePosition) {
                    Text("Lower").tag("bottom")
                    Text("Raised").tag("middleBottom")
                    Text("Center").tag("center")
                }
            }

            Section {
                Button(action: resetToDefaults) {
                    Label("Reset Subtitle Style", systemImage: "arrow.counterclockwise")
                }
                .foregroundColor(.accentColor)
            }
        }
        .navigationTitle("Subtitles")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
    }

    private var previewBottomPadding: CGFloat {
        let basePadding: CGFloat
        switch viewModel.subtitlePosition {
        case "center":
            basePadding = 78
        case "middleBottom":
            basePadding = 54
        default:
            basePadding = 26
        }
        return basePadding + CGFloat(viewModel.subtitleVerticalOffset)
    }

    private var fontWeight: Font.Weight {
        switch viewModel.subtitleFontWeight {
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        default: return .medium
        }
    }

    private var textColor: Color {
        switch viewModel.subtitleTextColor {
        case "yellow": return .yellow
        case "cyan": return .cyan
        case "green": return .green
        case "orange": return .orange
        default: return .white
        }
    }

    private func sliderRow(title: String, valueText: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(valueText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Slider(value: value, in: range, step: step)
                .tint(.accentColor)
        }
    }

    private func resetToDefaults() {
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.subtitleTextSize = AppSettings.defaultSubtitleTextSize
            viewModel.subtitleBackgroundOpacity = AppSettings.defaultSubtitleBackgroundOpacity
            viewModel.subtitleTextColor = "white"
            viewModel.subtitleShowBackground = true
            viewModel.subtitlePosition = "bottom"
            viewModel.subtitleFontWeight = "medium"
            viewModel.subtitleMaxLines = AppSettings.defaultSubtitleMaxLines
            viewModel.subtitleShadowOpacity = AppSettings.defaultSubtitleShadowOpacity
            viewModel.subtitleVerticalOffset = AppSettings.defaultSubtitleVerticalOffset
        }
    }
}
