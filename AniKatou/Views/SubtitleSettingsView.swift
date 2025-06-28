import SwiftUI

struct SubtitleSettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var previewText = "This is a preview of how your subtitles will look"
    
    var body: some View {
        List {
            Section {
                // Preview
                VStack(spacing: 16) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    ZStack {
                        // Video background simulation
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.3)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 200)
                            .cornerRadius(12)
                        
                        // Subtitle preview
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text(previewText)
                                    .font(.system(size: viewModel.subtitleTextSize, weight: fontWeight))
                                    .foregroundColor(textColor)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(viewModel.subtitleMaxLines)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(
                                        Group {
                                            if viewModel.subtitleShowBackground {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.black.opacity(viewModel.subtitleBackgroundOpacity))
                                            }
                                        }
                                    )
                                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                                Spacer()
                            }
                            .padding(.bottom, 20)
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Preview")
            }
            
            Section {
                // Text Size
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Text Size")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(viewModel.subtitleTextSize))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $viewModel.subtitleTextSize, in: 12...32, step: 1)
                        .accentColor(.blue)
                }
                
                // Font Weight
                Picker("Font Weight", selection: $viewModel.subtitleFontWeight) {
                    Text("Light").tag("light")
                    Text("Regular").tag("regular")
                    Text("Medium").tag("medium")
                    Text("Semibold").tag("semibold")
                    Text("Bold").tag("bold")
                }
                
                // Text Color
                Picker("Text Color", selection: $viewModel.subtitleTextColor) {
                    HStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                            .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                        Text("White").tag("white")
                    }
                    
                    HStack {
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 20, height: 20)
                        Text("Yellow").tag("yellow")
                    }
                    
                    HStack {
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 20, height: 20)
                        Text("Cyan").tag("cyan")
                    }
                    
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 20, height: 20)
                        Text("Green").tag("green")
                    }
                    
                    HStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 20, height: 20)
                        Text("Orange").tag("orange")
                    }
                }
                
                // Max Lines
                Stepper("Max Lines: \(viewModel.subtitleMaxLines)", value: $viewModel.subtitleMaxLines, in: 1...5)
            } header: {
                Text("Text Appearance")
            }
            
            Section {
                // Background Toggle
                Toggle("Show Background", isOn: $viewModel.subtitleShowBackground)
                
                // Background Opacity (only show if background is enabled)
                if viewModel.subtitleShowBackground {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Background Opacity")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(viewModel.subtitleBackgroundOpacity * 100))%")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $viewModel.subtitleBackgroundOpacity, in: 0.1...1.0, step: 0.1)
                            .accentColor(.blue)
                    }
                }
                
                // Position
                Picker("Position", selection: $viewModel.subtitlePosition) {
                    Text("Bottom").tag("bottom")
                    Text("Middle Bottom").tag("middleBottom")
                    Text("Center").tag("center")
                }
            } header: {
                Text("Background & Position")
            }
            
            Section {
                // Reset to Defaults
                Button(action: resetToDefaults) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Reset to Defaults")
                    }
                    .foregroundColor(.blue)
                }
            } header: {
                Text("Actions")
            }
        }
        .navigationTitle("Subtitle Settings")
        .navigationBarTitleDisplayMode(.inline)
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
    
    private func resetToDefaults() {
        withAnimation {
            viewModel.subtitleTextSize = AppSettings.defaultSubtitleTextSize
            viewModel.subtitleBackgroundOpacity = AppSettings.defaultSubtitleBackgroundOpacity
            viewModel.subtitleTextColor = "white"
            viewModel.subtitleShowBackground = true
            viewModel.subtitlePosition = "bottom"
            viewModel.subtitleFontWeight = "medium"
            viewModel.subtitleMaxLines = AppSettings.defaultSubtitleMaxLines
        }
    }
} 