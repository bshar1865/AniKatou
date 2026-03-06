import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showCacheAlert = false
    @State private var showClearCacheAlert = false

    var body: some View {
        List {
            Section("Playback") {
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

                Toggle("Enable Subtitles", isOn: $viewModel.subtitlesEnabled)
                Toggle("Skip Intros Automatically", isOn: $viewModel.autoSkipIntro)
                Toggle("Skip Outros Automatically", isOn: $viewModel.autoSkipOutro)
            }

            Section("Subtitles") {
                NavigationLink(destination: SubtitleSettingsView(viewModel: viewModel)) {
                    HStack(spacing: 12) {
                        Image(systemName: "captions.bubble.fill")
                            .foregroundColor(.accentColor)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Subtitle Style")
                                .font(.headline)
                            Text("Text size, color, shade, and screen position")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Downloads") {
                NavigationLink(destination: DownloadView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Download Queue")
                                .font(.headline)
                            Text("Manage active, failed, and saved offline episodes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Stepper(value: $viewModel.concurrentDownloadsLimit, in: 1...3) {
                    HStack {
                        Text("Simultaneous Downloads")
                        Spacer()
                        Text("\(viewModel.concurrentDownloadsLimit)")
                            .foregroundColor(.secondary)
                    }
                }
            } footer: {
                Text("Additional episodes stay queued until a slot opens.")
            }

            Section("Storage") {
                Button("Manage Cache") {
                    showCacheAlert = true
                }

                if let stats = viewModel.cacheStatistics {
                    LabeledContent("Storage Used", value: formatFileSize(stats.totalSize))
                    LabeledContent("Cached Anime", value: "\(stats.animeCount)")
                    LabeledContent("Cached Images", value: "\(stats.imageCount)")
                }

                Button("Clear All Cache", role: .destructive) {
                    showClearCacheAlert = true
                }
            }

            Section("General") {
                NavigationLink(destination: APIConfigView()) {
                    Label("Server Settings", systemImage: "server.rack")
                }

                NavigationLink(destination: AboutView()) {
                    Label("About", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [Color(.systemGroupedBackground), Color(.secondarySystemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .alert("Cache Management", isPresented: $showCacheAlert) {
            Button("Clear Old Cache") { Task { await viewModel.clearOldCache() } }
            Button("View Statistics") { viewModel.refreshCacheStatistics() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose an action to manage offline cache and artwork.")
        }
        .alert("Clear All Cache", isPresented: $showClearCacheAlert) {
            Button("Clear All", role: .destructive) { viewModel.clearAllCache() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes cached anime details, images, and offline metadata.")
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
    NavigationStack {
        SettingsView()
    }
}
