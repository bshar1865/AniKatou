import SwiftUI

struct DownloadView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Downloads")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Coming Soon")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text("Download functionality will be available in a future update.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    DownloadView()
} 