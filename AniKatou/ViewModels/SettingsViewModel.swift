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
    
    @Published var preferredQuality: String {
        didSet {
            AppSettings.shared.preferredQuality = preferredQuality
        }
    }
    
    @Published var subtitlesEnabled: Bool {
        didSet {
            AppSettings.shared.subtitlesEnabled = subtitlesEnabled
        }
    }
    
    init() {
        self.preferredServer = AppSettings.shared.preferredServer
        self.preferredLanguage = AppSettings.shared.preferredLanguage
        self.preferredQuality = AppSettings.shared.preferredQuality
        self.subtitlesEnabled = AppSettings.shared.subtitlesEnabled
    }
} 