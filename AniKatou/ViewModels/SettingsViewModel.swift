import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var preferredServer: String {
        didSet {
            AppSettings.shared.preferredServer = preferredServer
        }
    }
    
    @Published var preferredLanguage: String {
        didSet {
            AppSettings.shared.preferredLanguage = preferredLanguage
        }
    }
    
    @Published var theme: AppSettings.AppTheme {
        didSet {
            AppSettings.shared.theme = theme
        }
    }
    
    @Published var preferredQuality: String {
        didSet {
            AppSettings.shared.preferredQuality = preferredQuality
        }
    }
    
    @Published var autoplayEnabled: Bool {
        didSet {
            AppSettings.shared.autoplayEnabled = autoplayEnabled
        }
    }
    
    init() {
        preferredServer = AppSettings.shared.preferredServer
        preferredLanguage = AppSettings.shared.preferredLanguage
        theme = AppSettings.shared.theme
        preferredQuality = AppSettings.shared.preferredQuality
        autoplayEnabled = AppSettings.shared.autoplayEnabled
    }
} 