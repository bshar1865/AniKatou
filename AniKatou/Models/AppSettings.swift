import Foundation

class AppSettings {
    static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    private let serverKey = "preferred_server"
    private let languageKey = "preferred_language"
    private let qualityKey = "video_quality"
    private let subtitlesKey = "subtitles_enabled"
    private let autoSkipIntroKey = "auto_skip_intro"
    private let autoSkipOutroKey = "auto_skip_outro"
    
    private init() {}
    
    // Server Settings
    var preferredServer: String {
        get { defaults.string(forKey: serverKey) ?? "hd-1" }
        set { defaults.set(newValue, forKey: serverKey) }
    }
    
    var availableServers: [(id: String, name: String)] {
        [
            ("hd-1", "HD Server 1"),
            ("hd-2", "HD Server 2")
        ]
    }
    
    // Language Settings
    var preferredLanguage: String {
        get { defaults.string(forKey: languageKey) ?? "sub" }
        set { defaults.set(newValue, forKey: languageKey) }
    }
    
    var availableLanguages: [(id: String, name: String)] {
        [
            ("sub", "Subbed"),
            ("dub", "Dubbed")
        ]
    }
    
    // Video Quality Settings
    var preferredQuality: String {
        get { defaults.string(forKey: qualityKey) ?? "1080p" }
        set { defaults.set(newValue, forKey: qualityKey) }
    }
    
    var availableQualities: [(id: String, name: String)] {
        [
            ("360p", "360p"),
            ("480p", "480p"),
            ("720p", "720p"),
            ("1080p", "1080p")
        ]
    }
    
    // Subtitle Settings
    var subtitlesEnabled: Bool {
        get { defaults.bool(forKey: subtitlesKey) }
        set { defaults.set(newValue, forKey: subtitlesKey) }
    }
    
    // Subtitle Appearance Settings
    var subtitleTextSize: Double {
        get { defaults.double(forKey: "subtitleTextSize") }
        set { defaults.set(newValue, forKey: "subtitleTextSize") }
    }
    
    var subtitleBackgroundOpacity: Double {
        get { defaults.double(forKey: "subtitleBackgroundOpacity") }
        set { defaults.set(newValue, forKey: "subtitleBackgroundOpacity") }
    }
    
    var subtitleTextColor: String {
        get { defaults.string(forKey: "subtitleTextColor") ?? "white" }
        set { defaults.set(newValue, forKey: "subtitleTextColor") }
    }
    
    var subtitleShowBackground: Bool {
        get { defaults.bool(forKey: "subtitleShowBackground") }
        set { defaults.set(newValue, forKey: "subtitleShowBackground") }
    }
    
    var subtitlePosition: String {
        get { defaults.string(forKey: "subtitlePosition") ?? "bottom" }
        set { defaults.set(newValue, forKey: "subtitlePosition") }
    }
    
    var subtitleFontWeight: String {
        get { defaults.string(forKey: "subtitleFontWeight") ?? "medium" }
        set { defaults.set(newValue, forKey: "subtitleFontWeight") }
    }
    
    var subtitleMaxLines: Int {
        get { defaults.integer(forKey: "subtitleMaxLines") }
        set { defaults.set(newValue, forKey: "subtitleMaxLines") }
    }
    
    // Default subtitle settings
    static let defaultSubtitleTextSize: Double = 18.0
    static let defaultSubtitleBackgroundOpacity: Double = 0.8
    static let defaultSubtitleMaxLines: Int = 3
    
    // Auto-Skip Settings
    var autoSkipIntro: Bool {
        get { defaults.bool(forKey: autoSkipIntroKey) }
        set { defaults.set(newValue, forKey: autoSkipIntroKey) }
    }
    
    var autoSkipOutro: Bool {
        get { defaults.bool(forKey: autoSkipOutroKey) }
        set { defaults.set(newValue, forKey: autoSkipOutroKey) }
    }
    
    // Custom Player Setting
    var playerType: String {
        get { defaults.string(forKey: "playerType") ?? "custom" }
        set { defaults.set(newValue, forKey: "playerType") }
    }
    
    // For backwards compatibility
    var useCustomPlayer: Bool {
        get { playerType == "custom" }
        set { playerType = newValue ? "custom" : "ios" }
    }
} 