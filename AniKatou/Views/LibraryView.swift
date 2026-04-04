import SwiftUI

struct LibraryView: View {
    @StateObject private var downloadManager = HLSDownloadManager.shared
    @State private var recentCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Library")
                        .font(.title2.weight(.bold))
                    Text("Quick access to your recent episodes and offline downloads.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                VStack(spacing: 12) {
                    NavigationLink(destination: RecentsView()) {
                        LibraryHubCard(
                            title: "Recents",
                            subtitle: recentSubtitle,
                            systemImage: "clock.arrow.circlepath"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: DownloadView()) {
                        LibraryHubCard(
                            title: "Downloads",
                            subtitle: downloadsSubtitle,
                            systemImage: "arrow.down.circle"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)

                if recentCount == 0 && downloadManager.downloads.isEmpty {
                    ContentUnavailableView(
                        "Nothing Here Yet",
                        systemImage: "tray",
                        description: Text("Watch an episode or start a download to see it here.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 260)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 14)
        }
        .navigationTitle("Library")
        .onAppear {
            refreshRecents()
        }
    }

    private var recentSubtitle: String {
        recentCount == 0 ? "No recent episodes" : "\(recentCount) recent episode\(recentCount == 1 ? "" : "s")"
    }

    private var downloadsSubtitle: String {
        let count = downloadManager.downloads.count
        return count == 0 ? "No downloads" : "\(count) download\(count == 1 ? "" : "s")"
    }

    private func refreshRecents() {
        WatchProgressManager.shared.cleanupFinishedEpisodes()
        recentCount = WatchProgressManager.shared.getWatchHistory().count
    }
}

private struct LibraryHubCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        LibraryView()
    }
}
