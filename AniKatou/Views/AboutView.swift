import SwiftUI

struct AboutView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("AniWatch")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Version \(viewModel.appVersion)")
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
                Text("AniWatch is a modern anime streaming app that provides high-quality anime content with a beautiful and intuitive interface.")
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