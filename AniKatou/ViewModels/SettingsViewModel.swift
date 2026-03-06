import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var preferredServer: String {
        didSet { AppSettings.shared.preferredServer = preferredServer }
    }

    @Published var preferredLanguage: String {
        didSet { AppSettings.shared.preferredLanguage = preferredLanguage }
    }

    @Published var preferredQuality: String {
        didSet { AppSettings.shared.preferredQuality = preferredQuality }
    }

    @Published var subtitlesEnabled: Bool {
        didSet { AppSettings.shared.subtitlesEnabled = subtitlesEnabled }
    }

    @Published var autoSkipIntro: Bool {
        didSet { AppSettings.shared.autoSkipIntro = autoSkipIntro }
    }

    @Published var autoSkipOutro: Bool {
        didSet { AppSettings.shared.autoSkipOutro = autoSkipOutro }
    }

    @Published var subtitleTextSize: Double {
        didSet { AppSettings.shared.subtitleTextSize = subtitleTextSize }
    }

    @Published var subtitleBackgroundOpacity: Double {
        didSet { AppSettings.shared.subtitleBackgroundOpacity = subtitleBackgroundOpacity }
    }

    @Published var subtitleTextColor: String {
        didSet { AppSettings.shared.subtitleTextColor = subtitleTextColor }
    }

    @Published var subtitleShowBackground: Bool {
        didSet { AppSettings.shared.subtitleShowBackground = subtitleShowBackground }
    }

    @Published var subtitlePosition: String {
        didSet { AppSettings.shared.subtitlePosition = subtitlePosition }
    }

    @Published var subtitleFontWeight: String {
        didSet { AppSettings.shared.subtitleFontWeight = subtitleFontWeight }
    }

    @Published var subtitleMaxLines: Int {
        didSet { AppSettings.shared.subtitleMaxLines = subtitleMaxLines }
    }

    @Published var cacheStatistics: (totalSize: Int64, animeCount: Int, imageCount: Int)?

    var availableServers: [(id: String, name: String)] { AppSettings.shared.availableServers }
    var availableLanguages: [(id: String, name: String)] { AppSettings.shared.availableLanguages }
    var availableQualities: [(id: String, name: String)] { AppSettings.shared.availableQualities }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    init() {
        preferredServer = AppSettings.shared.preferredServer
        preferredLanguage = AppSettings.shared.preferredLanguage
        preferredQuality = AppSettings.shared.preferredQuality
        subtitlesEnabled = AppSettings.shared.subtitlesEnabled
        autoSkipIntro = AppSettings.shared.autoSkipIntro
        autoSkipOutro = AppSettings.shared.autoSkipOutro

        let textSize = AppSettings.shared.subtitleTextSize > 0 ? AppSettings.shared.subtitleTextSize : AppSettings.defaultSubtitleTextSize
        let bgOpacity = AppSettings.shared.subtitleBackgroundOpacity > 0 ? AppSettings.shared.subtitleBackgroundOpacity : AppSettings.defaultSubtitleBackgroundOpacity
        let maxLines = AppSettings.shared.subtitleMaxLines > 0 ? AppSettings.shared.subtitleMaxLines : AppSettings.defaultSubtitleMaxLines

        subtitleTextSize = textSize
        subtitleBackgroundOpacity = bgOpacity
        subtitleTextColor = AppSettings.shared.subtitleTextColor
        subtitleShowBackground = AppSettings.shared.subtitleShowBackground
        subtitlePosition = AppSettings.shared.subtitlePosition
        subtitleFontWeight = AppSettings.shared.subtitleFontWeight
        subtitleMaxLines = maxLines

        refreshCacheStatistics()
    }

    func refreshCacheStatistics() {
        cacheStatistics = OfflineManager.shared.getCacheStatistics()
    }

    func clearOldCache() async {
        await OfflineManager.shared.clearOldCache()
        refreshCacheStatistics()
    }

    func clearAllCache() {
        OfflineManager.shared.clearAllCache()
        refreshCacheStatistics()
    }
}
