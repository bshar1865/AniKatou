import SwiftUI
import WebKit

struct AniListAuthView: View {
    @StateObject private var viewModel = AniListAuthViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingWebView = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("AniList Integration")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Connect your AniList account to sync your anime library")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                if viewModel.isAuthenticated {
                    // Authenticated State
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Connected to AniList")
                                .font(.headline)
                        }
                        
                        if viewModel.isLoading {
                            ProgressView("Loading library...")
                        } else {
                            VStack(spacing: 8) {
                                Text("\(viewModel.userLibrary.count) anime in your library")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                if !viewModel.userLibrary.isEmpty {
                                    VStack(spacing: 4) {
                                        HStack {
                                            Text("Watching:")
                                            Spacer()
                                            Text("\(viewModel.getWatchingList().count)")
                                                .fontWeight(.semibold)
                                        }
                                        
                                        HStack {
                                            Text("Plan to Watch:")
                                            Spacer()
                                            Text("\(viewModel.getPlanToWatchList().count)")
                                                .fontWeight(.semibold)
                                        }
                                        
                                        HStack {
                                            Text("Completed:")
                                            Spacer()
                                            Text("\(viewModel.getCompletedList().count)")
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Button("Disconnect") {
                            viewModel.logout()
                        }
                        .foregroundColor(.red)
                    }
                } else {
                    // Not Authenticated State
                    VStack(spacing: 16) {
                        Text("Connect your AniList account")
                            .font(.headline)
                        
                        Text("Tap the button below to authorize AniKatou with your AniList account. You'll be redirected to AniList to complete the authorization.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Connect to AniList") {
                            showingWebView = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                Spacer()
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
            .navigationTitle("AniList")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingWebView) {
            AniListWebView(viewModel: viewModel) { success in
                showingWebView = false
                if success {
                    // Authentication was successful, dismiss the sheet
                    dismiss()
                }
            }
        }
    }
}

struct AniListWebView: UIViewControllerRepresentable {
    let viewModel: AniListAuthViewModel
    let onCompletion: (Bool) -> Void
    
    func makeUIViewController(context: Context) -> AniListWebViewController {
        let controller = AniListWebViewController()
        controller.viewModel = viewModel
        controller.onCompletion = onCompletion
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AniListWebViewController, context: Context) {}
}

class AniListWebViewController: UIViewController, WKNavigationDelegate {
    var webView: WKWebView!
    var viewModel: AniListAuthViewModel!
    var onCompletion: ((Bool) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add close button
        let closeButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeButtonTapped))
        navigationItem.rightBarButtonItem = closeButton
        
        webView = WKWebView()
        webView.navigationDelegate = self
        view = webView
        
        // AniList OAuth URL - Using Implicit Grant for mobile apps
        let clientId = "28000" // AniList application ID
        
        let authURL = "https://anilist.co/api/v2/oauth/authorize?client_id=\(clientId)&response_type=token"
        
        if let url = URL(string: authURL) {
            webView.load(URLRequest(url: url))
        }
    }
    
    @objc func closeButtonTapped() {
        onCompletion?(false)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            // Check if this is the redirect with access token in fragment
            if url.absoluteString.contains("access_token=") {
                // Extract access token from URL fragment (Implicit Grant flow)
                if let fragment = url.fragment,
                   let accessToken = URLComponents(string: "?\(fragment)")?.queryItems?.first(where: { $0.name == "access_token" })?.value {
                    Task {
                        // Store the access token directly
                        await viewModel.storeAccessToken(accessToken)
                        DispatchQueue.main.async {
                            self.onCompletion?(true)
                        }
                    }
                } else if let error = URLComponents(string: "?\(url.fragment ?? "")")?.queryItems?.first(where: { $0.name == "error" })?.value {
                    // User denied authorization or there was an error
                    print("AniList authorization error: \(error)")
                    DispatchQueue.main.async {
                        self.onCompletion?(false)
                    }
                } else {
                    // No access token found - this might be an error or user cancelled
                    print("AniList redirect detected but no access token found")
                    DispatchQueue.main.async {
                        self.onCompletion?(false)
                    }
                }
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
} 