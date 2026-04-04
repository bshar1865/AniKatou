import SwiftUI

fileprivate enum LibraryTab {
    case recents
    case downloads
}

struct LibraryView: View {
    @State private var selectedTab: LibraryTab = .recents

    var body: some View {
        VStack(spacing: 0) {
            LibrarySegmentedControl(selectedTab: $selectedTab)
            Divider()

            Group {
                switch selectedTab {
                case .recents:
                    RecentsListView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .downloads:
                    DownloadsListView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle("Library")
    }
}

private struct LibrarySegmentedControl: View {
    @Binding var selectedTab: LibraryTab

    var body: some View {
        HStack(spacing: 24) {
            segmentButton(title: "Recents", tab: .recents)
            segmentButton(title: "Downloads", tab: .downloads)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }

    private func segmentButton(title: String, tab: LibraryTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                    .foregroundColor(selectedTab == tab ? .primary : .secondary)

                Capsule()
                    .fill(selectedTab == tab ? Color.blue : Color.clear)
                    .frame(height: 3)
                    .frame(maxWidth: 40)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        LibraryView()
    }
}
