import Foundation

class BookmarkManager {
    static let shared = BookmarkManager()
    private let bookmarksKey = "bookmarked_animes"
    
    private init() {}
    
    var bookmarkedAnimes: [AnimeItem] {
        get {
            guard let data = UserDefaults.standard.data(forKey: bookmarksKey),
                  let bookmarks = try? JSONDecoder().decode([AnimeItem].self, from: data) else {
                return []
            }
            return bookmarks
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: bookmarksKey)
            }
        }
    }
    
    func isBookmarked(_ anime: AnimeItem) -> Bool {
        bookmarkedAnimes.contains { $0.id == anime.id }
    }
    
    func toggleBookmark(_ anime: AnimeItem) {
        var bookmarks = bookmarkedAnimes
        if let index = bookmarks.firstIndex(where: { $0.id == anime.id }) {
            bookmarks.remove(at: index)
        } else {
            bookmarks.append(anime)
        }
        bookmarkedAnimes = bookmarks
    }
} 