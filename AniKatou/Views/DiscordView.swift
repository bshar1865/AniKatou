import SwiftUI

struct DiscordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var discordServerURL = "https://discord.gg/EE3xSCSqgC"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Discord Icon
                Image(systemName: "message.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.top, 40)
                
                // Title
                Text("Join Our Discord Community")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                // Description
                VStack(spacing: 16) {
                    Text("Connect with fellow anime enthusiasts!")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("• Get help and support\n• Share recommendations\n• Discuss latest episodes\n• Report bugs and suggest features\n• Stay updated with app news")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Join Button
                Button(action: {
                    if let url = URL(string: discordServerURL) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "link")
                            .font(.headline)
                        Text("Join Discord Server")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Copy Link Button
                Button(action: {
                    UIPasteboard.general.string = discordServerURL
                }) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                            .font(.headline)
                        Text("Copy Link")
                            .font(.headline)
                        .fontWeight(.semibold)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Close Button
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    DiscordView()
} 