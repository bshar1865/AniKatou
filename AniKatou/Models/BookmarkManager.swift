import Foundation

class BookmarkManager {
    static let shared = BookmarkManager()
    private let bookmarksKey = "bookmarked_animes"
    private var cachedBookmarks: [AnimeItem] = []
    
    private init() {
        loadBookmarks()
    }
    
    private func loadBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey),
              let bookmarks = try? JSONDecoder().decode([AnimeItem].self, from: data) else {
            cachedBookmarks = []
            return
        }
        cachedBookmarks = bookmarks
    }
    
    private func saveBookmarks() {
        if let data = try? JSONEncoder().encode(cachedBookmarks) {
            UserDefaults.standard.set(data, forKey: bookmarksKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    var bookmarkedAnimes: [AnimeItem] {
        get {
            cachedBookmarks
        }
        set {
            cachedBookmarks = newValue
            saveBookmarks()
        }
    }
    
    func isBookmarked(_ anime: AnimeItem) -> Bool {
        cachedBookmarks.contains { $0.id == anime.id }
    }
    
    func toggleBookmark(_ anime: AnimeItem) {
        if let index = cachedBookmarks.firstIndex(where: { $0.id == anime.id }) {
            cachedBookmarks.remove(at: index)
        } else {
            cachedBookmarks.append(anime)
        }
        saveBookmarks()
    }
} 