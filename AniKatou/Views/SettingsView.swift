import SwiftUI

struct SettingsView: View {
    @State private var showingAPIConfig = false
    @AppStorage(APIConfig.apiConfigKey) private var apiBaseURL: String?
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        List {
            Section {
                Button(action: {
                    showingAPIConfig = true
                }) {
                    HStack {
                        Label("API Configuration", systemImage: "server.rack")
                        Spacer()
                        Text(apiBaseURL ?? "Not configured")
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            } header: {
                Text("Server")
            } footer: {
                Text("Configure your self-hosted AniWatch API instance.")
            }
            
            Section {
                Picker("Preferred Server", selection: $viewModel.preferredServer) {
                    ForEach(AppSettings.shared.availableServers, id: \.id) { server in
                        Text(server.name).tag(server.id)
                    }
                }
                
                Picker("Language", selection: $viewModel.preferredLanguage) {
                    ForEach(AppSettings.shared.availableLanguages, id: \.id) { language in
                        Text(language.name).tag(language.id)
                    }
                }
                
                Picker("Video Quality", selection: $viewModel.preferredQuality) {
                    ForEach(AppSettings.shared.availableQualities, id: \.id) { quality in
                        Text(quality.name).tag(quality.id)
                    }
                }
            } header: {
                Text("Streaming")
            } footer: {
                Text("Configure your streaming preferences including video quality and language.")
            }
            
            Section {
                Toggle("Auto-Skip Intro", isOn: $viewModel.autoSkipIntro)
                Toggle("Auto-Skip Outro", isOn: $viewModel.autoSkipOutro)
                Toggle("Enable Subtitles", isOn: $viewModel.subtitlesEnabled)
                Picker("Video Player", selection: $viewModel.playerType) {
                    Text("iOS Player").tag("ios")
                    Text("AniKatou Player").tag("custom")
                }
                
                if viewModel.subtitlesEnabled {
                    NavigationLink {
                        SubtitleSettingsView()
                    } label: {
                        Label("Subtitle Settings", systemImage: "text.bubble")
                    }
                }
            } header: {
                Text("Playback")
            } footer: {
                Text("Configure playback preferences including auto-skip, subtitles, and video player selection.")
            }
            
            Section {
                Link(destination: URL(string: "https://github.com/ghoshRitesh12/aniwatch-api")!) {
                    Label("API Documentation", systemImage: "doc.text")
                }
                
                NavigationLink {
                    AboutView()
                } label: {
                    Label("About", systemImage: "info.circle")
                }
            } header: {
                Text("Info")
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingAPIConfig) {
            NavigationView {
                APIConfigView()
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "play.tv")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)
                    
                    Text("AniKatou")
                        .font(.title.bold())
                    
                    Text("Version 1.0")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                
                Link(destination: URL(string: "https://github.com/bshar1865/AniKatou")!) {
                    Label("View on GitHub", systemImage: "link")
                }
                
                Label("Made with ❤️ by Bshar Esfky", systemImage: "heart.fill")
            }
            
            Section {
                Text("AniKatou is a modern anime streaming client that connects to your self-hosted AniWatch API instance.")
            } header: {
                Text("About")
            }
            
            Section {
                Text("This app uses the unofficial AniWatch API. All content is sourced from various providers and we do not host any content.")
            } header: {
                Text("Disclaimer")
            }
        }
        .navigationTitle("About")
    }
} 