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
    var useCustomPlayer: Bool {
        get { defaults.object(forKey: "useCustomPlayer") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "useCustomPlayer") }
    }
} 