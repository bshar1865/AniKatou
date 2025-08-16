import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showCacheAlert = false
    @State private var showClearCacheAlert = false
    
    var body: some View {
        NavigationView {
        List {
                // API Configuration Section
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
                
                // AniList Integration Section
                Section("AniList") {
                    NavigationLink(destination: AniListAuthView()) {
                            HStack {
                            Image(systemName: "person.circle")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AniList Account")
                                        .font(.headline)
                                Text("Sync your anime library and progress")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Video Playback Section
                Section("Video Playback") {
                    // Server Selection
                    Picker("Preferred Server", selection: $viewModel.preferredServer) {
                        ForEach(viewModel.availableServers, id: \.id) { server in
                            Text(server.name).tag(server.id)
                        }
                    }
                    
                    // Language Selection
                    Picker("Audio Language", selection: $viewModel.preferredLanguage) {
                        ForEach(viewModel.availableLanguages, id: \.id) { language in
                            Text(language.name).tag(language.id)
                        }
                    }
                    
                    // Quality Selection
                    Picker("Video Quality", selection: $viewModel.preferredQuality) {
                        ForEach(viewModel.availableQualities, id: \.id) { quality in
                            Text(quality.name).tag(quality.id)
                        }
                    }
                    
                    // Player Type
                    Picker("Video Player", selection: $viewModel.playerType) {
                        Text("AniKatou Player").tag("custom")
                        Text("Native Player").tag("ios")
                    }
                }
                
                // Subtitle Settings Section
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
                
                // Auto-Skip Settings Section
                Section("Auto-Skip Settings") {
                    Toggle("Skip Intros Automatically", isOn: $viewModel.autoSkipIntro)
                    Toggle("Skip Outros Automatically", isOn: $viewModel.autoSkipOutro)
                }
                
                // Offline Cache Section
                Section("Offline Storage") {
                    HStack {
                        Image(systemName: "externaldrive")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cache Management")
                                .font(.headline)
                            Text("Manage offline content and storage")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Manage") {
                            showCacheAlert = true
                        }
                        .foregroundColor(.blue)
                    }
                    
                    // Cache Statistics
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
                        
                        HStack {
                            Text("Cached Images")
                            Spacer()
                            Text("\(stats.imageCount)")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Clear All Cache moved here
                    Button(action: {
                        showClearCacheAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear All Cache")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // Community Section
                Section("Community & Support") {
                    Button(action: {
                        if let url = URL(string: "https://discord.gg/EE3xSCSqgC") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Join Discord Community")
                                    .font(.headline)
                                Text("Join for support and talk")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    // About Section
                    NavigationLink(destination: AboutView()) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("About")
                                    .font(.headline)
                                Text("App information and credits")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Data Management Section - removed clear cache from here
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Cache Management", isPresented: $showCacheAlert) {
            Button("Clear Old Cache") {
                Task {
                    await viewModel.clearOldCache()
                }
            }
            Button("View Statistics") {
                viewModel.refreshCacheStatistics()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose an action to manage your offline cache.")
        }
        .alert("Clear All Cache", isPresented: $showClearCacheAlert) {
            Button("Clear All", role: .destructive) {
                viewModel.clearAllCache()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all cached anime details, images, and offline data. This action cannot be undone.")
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