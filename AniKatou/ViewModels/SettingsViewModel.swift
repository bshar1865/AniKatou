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
    
    @Published var autoSkipIntro: Bool {
        didSet {
            AppSettings.shared.autoSkipIntro = autoSkipIntro
        }
    }
    
    @Published var autoSkipOutro: Bool {
        didSet {
            AppSettings.shared.autoSkipOutro = autoSkipOutro
        }
    }
    
    @Published var playerType: String {
        didSet {
            AppSettings.shared.playerType = playerType
        }
    }
    
    // Subtitle Appearance Settings
    @Published var subtitleTextSize: Double {
        didSet {
            AppSettings.shared.subtitleTextSize = subtitleTextSize
        }
    }
    
    @Published var subtitleBackgroundOpacity: Double {
        didSet {
            AppSettings.shared.subtitleBackgroundOpacity = subtitleBackgroundOpacity
        }
    }
    
    @Published var subtitleTextColor: String {
        didSet {
            AppSettings.shared.subtitleTextColor = subtitleTextColor
        }
    }
    
    @Published var subtitleShowBackground: Bool {
        didSet {
            AppSettings.shared.subtitleShowBackground = subtitleShowBackground
        }
    }
    
    @Published var subtitlePosition: String {
        didSet {
            AppSettings.shared.subtitlePosition = subtitlePosition
        }
    }
    
    @Published var subtitleFontWeight: String {
        didSet {
            AppSettings.shared.subtitleFontWeight = subtitleFontWeight
        }
    }
    
    @Published var subtitleMaxLines: Int {
        didSet {
            AppSettings.shared.subtitleMaxLines = subtitleMaxLines
        }
    }
    
    // Cache management
    @Published var showCacheClearedAlert = false
    @Published var showContinueWatchingClearedAlert = false
    @Published var cacheStatistics: (totalSize: Int64, animeCount: Int, imageCount: Int)?
    
    // Computed properties for available options
    var availableServers: [(id: String, name: String)] {
        AppSettings.shared.availableServers
    }
    
    var availableLanguages: [(id: String, name: String)] {
        AppSettings.shared.availableLanguages
    }
    
    var availableQualities: [(id: String, name: String)] {
        AppSettings.shared.availableQualities
    }
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    init() {
        self.preferredServer = AppSettings.shared.preferredServer
        self.preferredLanguage = AppSettings.shared.preferredLanguage
        self.preferredQuality = AppSettings.shared.preferredQuality
        self.subtitlesEnabled = AppSettings.shared.subtitlesEnabled
        self.autoSkipIntro = AppSettings.shared.autoSkipIntro
        self.autoSkipOutro = AppSettings.shared.autoSkipOutro
        self.playerType = AppSettings.shared.playerType
        
        // Initialize subtitle settings with defaults if not set
        let textSize = AppSettings.shared.subtitleTextSize > 0 ? AppSettings.shared.subtitleTextSize : AppSettings.defaultSubtitleTextSize
        let bgOpacity = AppSettings.shared.subtitleBackgroundOpacity > 0 ? AppSettings.shared.subtitleBackgroundOpacity : AppSettings.defaultSubtitleBackgroundOpacity
        let maxLines = AppSettings.shared.subtitleMaxLines > 0 ? AppSettings.shared.subtitleMaxLines : AppSettings.defaultSubtitleMaxLines
        
        self.subtitleTextSize = textSize
        self.subtitleBackgroundOpacity = bgOpacity
        self.subtitleTextColor = AppSettings.shared.subtitleTextColor
        self.subtitleShowBackground = AppSettings.shared.subtitleShowBackground
        self.subtitlePosition = AppSettings.shared.subtitlePosition
        self.subtitleFontWeight = AppSettings.shared.subtitleFontWeight
        self.subtitleMaxLines = maxLines
        
        // Load initial cache statistics
        refreshCacheStatistics()
    }
    
    // MARK: - Cache Management
    
    func refreshCacheStatistics() {
        cacheStatistics = OfflineManager.shared.getCacheStatistics()
    }
    
    func clearOldCache() async {
        await OfflineManager.shared.clearOldCache()
        refreshCacheStatistics()
        showCacheClearedAlert = true
    }
    
    func clearAllCache() {
        OfflineManager.shared.clearAllCache()
        refreshCacheStatistics()
        showCacheClearedAlert = true
    }
    
    func clearSearchHistory() {
        // Clear search history from UserDefaults
        UserDefaults.standard.removeObject(forKey: "searchHistory")
        showCacheClearedAlert = true
    }
    
    func syncOfflineData() {
        // Sync bookmarks and watch progress for offline use
        OfflineManager.shared.syncBookmarksOffline()
        OfflineManager.shared.syncWatchProgressOffline()
    }
    
    // MARK: - Network Status
    
    var isOfflineMode: Bool {
        OfflineManager.shared.isOfflineMode
    }
    
    func checkNetworkStatus() -> Bool {
        return OfflineManager.shared.isNetworkAvailable()
    }
    
    // MARK: - Formatting Helpers
    
    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    func formatCacheAge(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
} 