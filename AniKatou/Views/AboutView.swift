import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("AniKatou")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Version \(appVersion)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            Section("Creator") {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Made with love by")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Bshar Esfky")
                            .font(.headline)
                    }
                }
            }

            Section("Description") {
                Text("AniKatou is a client app for user-configured, self-hosted API backends. The app does not bundle content sources or API endpoints.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Section("Legal") {
                Text("AniKatou does not host, distribute, or bundle copyrighted media. Users are responsible for how they configure and use their own backend.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationView {
        AboutView()
    }
}
