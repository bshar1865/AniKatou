import Foundation

class AppSettings {
    static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    private let serverKey = "preferred_server"
    private let languageKey = "preferred_language"
    private let autoplayKey = "autoplay_enabled"
    private let qualityKey = "video_quality"
    private let subtitlesKey = "subtitles_enabled"
    private let subtitlesLanguageKey = "subtitles_language"
    
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
    
    // Playback Settings
    var autoplayEnabled: Bool {
        get { defaults.bool(forKey: autoplayKey) }
        set { defaults.set(newValue, forKey: autoplayKey) }
    }
    
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
    
    var preferredSubtitlesLanguage: String {
        get { defaults.string(forKey: subtitlesLanguageKey) ?? "en" }
        set { defaults.set(newValue, forKey: subtitlesLanguageKey) }
    }
    
    var availableSubtitleLanguages: [(id: String, name: String)] {
        [
            ("en", "English"),
            ("es", "Spanish"),
            ("fr", "French"),
            ("de", "German"),
            ("it", "Italian"),
            ("pt", "Portuguese"),
            ("ru", "Russian"),
            ("ja", "Japanese")
        ]
    }
} 