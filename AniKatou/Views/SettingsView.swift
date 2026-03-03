import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showCacheAlert = false
    @State private var showClearCacheAlert = false

    var body: some View {
        NavigationView {
            List {
                Section("API Configuration") {
                    NavigationLink(destination: APIConfigView()) {
                        HStack {
                            Image(systemName: "server.rack")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Server Settings")
                                    .font(.headline)
                                Text("Configure your AniWatch API endpoint")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("Video Playback") {
                    Picker("Preferred Server", selection: $viewModel.preferredServer) {
                        ForEach(viewModel.availableServers, id: \.id) { server in
                            Text(server.name).tag(server.id)
                        }
                    }

                    Picker("Audio Language", selection: $viewModel.preferredLanguage) {
                        ForEach(viewModel.availableLanguages, id: \.id) { language in
                            Text(language.name).tag(language.id)
                        }
                    }

                    Picker("Video Quality", selection: $viewModel.preferredQuality) {
                        ForEach(viewModel.availableQualities, id: \.id) { quality in
                            Text(quality.name).tag(quality.id)
                        }
                    }

                    Picker("Video Player", selection: $viewModel.playerType) {
                        Text("AniKatou Player").tag("custom")
                        Text("Native Player").tag("ios")
                    }
                }

                Section("Subtitle Settings") {
                    NavigationLink(destination: SubtitleSettingsView()) {
                        HStack {
                            Image(systemName: "text.bubble")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Subtitle Preferences")
                                    .font(.headline)
                                Text("Customize subtitle appearance and behavior")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Toggle("Enable Subtitles", isOn: $viewModel.subtitlesEnabled)
                }

                Section("Auto-Skip") {
                    Toggle("Skip Intros Automatically", isOn: $viewModel.autoSkipIntro)
                    Toggle("Skip Outros Automatically", isOn: $viewModel.autoSkipOutro)
                }

                Section("Offline Storage") {
                    Button("Manage Cache") {
                        showCacheAlert = true
                    }

                    if let stats = viewModel.cacheStatistics {
                        HStack {
                            Text("Storage Used")
                            Spacer()
                            Text(formatFileSize(stats.totalSize))
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Cached Anime")
                            Spacer()
                            Text("\(stats.animeCount)")
                                .foregroundColor(.secondary)
                        }
                    }

                    Button(role: .destructive) {
                        showClearCacheAlert = true
                    } label: {
                        Text("Clear All Cache")
                    }
                }

                Section("Community & Support") {
                    Button(action: {
                        if let url = URL(string: "https://discord.gg/EE3xSCSqgC") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Join Discord Community")
                    }

                    NavigationLink(destination: AboutView()) {
                        Text("About")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Cache Management", isPresented: $showCacheAlert) {
            Button("Clear Old Cache") { Task { await viewModel.clearOldCache() } }
            Button("View Statistics") { viewModel.refreshCacheStatistics() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose an action to manage your offline cache.")
        }
        .alert("Clear All Cache", isPresented: $showClearCacheAlert) {
            Button("Clear All", role: .destructive) { viewModel.clearAllCache() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all cached anime details, images, and offline data.")
        }
        .onAppear {
            viewModel.refreshCacheStatistics()
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#Preview {
    SettingsView()
}
