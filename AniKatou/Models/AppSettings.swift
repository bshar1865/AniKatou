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
    private let concurrentDownloadsKey = "concurrent_downloads_limit"
    private let subtitleTextSizeKey = "subtitleTextSize"
    private let subtitleBackgroundOpacityKey = "subtitleBackgroundOpacity"
    private let subtitleTextColorKey = "subtitleTextColor"
    private let subtitleShowBackgroundKey = "subtitleShowBackground"
    private let subtitlePositionKey = "subtitlePosition"
    private let subtitleFontWeightKey = "subtitleFontWeight"
    private let subtitleMaxLinesKey = "subtitleMaxLines"
    private let subtitleShadowOpacityKey = "subtitleShadowOpacity"
    private let subtitleVerticalOffsetKey = "subtitleVerticalOffset"

    private init() {}

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

    var subtitlesEnabled: Bool {
        get {
            if defaults.object(forKey: subtitlesKey) == nil {
                return true
            }
            return defaults.bool(forKey: subtitlesKey)
        }
        set { defaults.set(newValue, forKey: subtitlesKey) }
    }

    var subtitleTextSize: Double {
        get {
            let value = defaults.double(forKey: subtitleTextSizeKey)
            return value > 0 ? value : Self.defaultSubtitleTextSize
        }
        set { defaults.set(newValue, forKey: subtitleTextSizeKey) }
    }

    var subtitleBackgroundOpacity: Double {
        get {
            let value = defaults.double(forKey: subtitleBackgroundOpacityKey)
            return value > 0 ? value : Self.defaultSubtitleBackgroundOpacity
        }
        set { defaults.set(newValue, forKey: subtitleBackgroundOpacityKey) }
    }

    var subtitleTextColor: String {
        get { defaults.string(forKey: subtitleTextColorKey) ?? "white" }
        set { defaults.set(newValue, forKey: subtitleTextColorKey) }
    }

    var subtitleShowBackground: Bool {
        get {
            if defaults.object(forKey: subtitleShowBackgroundKey) == nil {
                return true
            }
            return defaults.bool(forKey: subtitleShowBackgroundKey)
        }
        set { defaults.set(newValue, forKey: subtitleShowBackgroundKey) }
    }

    var subtitlePosition: String {
        get { defaults.string(forKey: subtitlePositionKey) ?? "bottom" }
        set { defaults.set(newValue, forKey: subtitlePositionKey) }
    }

    var subtitleFontWeight: String {
        get { defaults.string(forKey: subtitleFontWeightKey) ?? "medium" }
        set { defaults.set(newValue, forKey: subtitleFontWeightKey) }
    }

    var subtitleMaxLines: Int {
        get {
            let value = defaults.integer(forKey: subtitleMaxLinesKey)
            return value > 0 ? value : Self.defaultSubtitleMaxLines
        }
        set { defaults.set(newValue, forKey: subtitleMaxLinesKey) }
    }

    var subtitleShadowOpacity: Double {
        get {
            let value = defaults.double(forKey: subtitleShadowOpacityKey)
            return value > 0 ? value : Self.defaultSubtitleShadowOpacity
        }
        set { defaults.set(newValue, forKey: subtitleShadowOpacityKey) }
    }

    var subtitleVerticalOffset: Double {
        get {
            if defaults.object(forKey: subtitleVerticalOffsetKey) == nil {
                return Self.defaultSubtitleVerticalOffset
            }
            return defaults.double(forKey: subtitleVerticalOffsetKey)
        }
        set { defaults.set(newValue, forKey: subtitleVerticalOffsetKey) }
    }

    static let defaultSubtitleTextSize: Double = 18.0
    static let defaultSubtitleBackgroundOpacity: Double = 0.8
    static let defaultSubtitleMaxLines: Int = 3
    static let defaultSubtitleShadowOpacity: Double = 0.65
    static let defaultSubtitleVerticalOffset: Double = 14

    var autoSkipIntro: Bool {
        get {
            if defaults.object(forKey: autoSkipIntroKey) == nil {
                return true
            }
            return defaults.bool(forKey: autoSkipIntroKey)
        }
        set { defaults.set(newValue, forKey: autoSkipIntroKey) }
    }

    var autoSkipOutro: Bool {
        get {
            if defaults.object(forKey: autoSkipOutroKey) == nil {
                return true
            }
            return defaults.bool(forKey: autoSkipOutroKey)
        }
        set { defaults.set(newValue, forKey: autoSkipOutroKey) }
    }

    var concurrentDownloadsLimit: Int {
        get {
            let value = defaults.integer(forKey: concurrentDownloadsKey)
            return max(1, min(value == 0 ? 2 : value, 3))
        }
        set {
            defaults.set(max(1, min(newValue, 3)), forKey: concurrentDownloadsKey)
        }
    }
}
