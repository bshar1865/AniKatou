import SwiftUI

struct APIConfigView: View {
    @StateObject private var viewModel = APIConfigViewModel()
    @Environment(\.dismiss) private var dismiss
    let isInitialSetup: Bool
    
    init(isInitialSetup: Bool = false) {
        self.isInitialSetup = isInitialSetup
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("API Base URL", text: $viewModel.apiURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .disabled(viewModel.isValidating)
                } header: {
                    Text("API Configuration")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter the base URL of your self-hosted API instance.")
                        Text("The URL will be automatically prefixed with https:// if not provided.")
                            .foregroundColor(.secondary)
                        
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            if await viewModel.saveAPIConfig() {
                                dismiss()
                            }
                        }
                    }) {
                        HStack {
                            Text("Save Configuration")
                            if viewModel.isValidating {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isValidating || viewModel.apiURL.isEmpty)
                    
                    if !isInitialSetup && viewModel.isConfigured {
                        Button(role: .destructive, action: {
                            viewModel.clearConfig()
                        }) {
                            Text("Clear Configuration")
                        }
                        .disabled(viewModel.isValidating)
                    }
                }
                
                Section {
                    Link(destination: URL(string: "https://github.com/ghoshRitesh12/aniwatch-api")!) {
                        HStack {
                            Text("Setup Guide")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                    }
                } footer: {
                    Text("You must provide a valid API URL to use this app.")
                }
            }
            .navigationTitle(isInitialSetup ? "API Configuration Required" : "API Settings")
            .navigationBarTitleDisplayMode(.large)
            .interactiveDismissDisabled(isInitialSetup)
        }
    }
}

#Preview {
    APIConfigView()
} 