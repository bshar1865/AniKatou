import Foundation

class LibraryManager {
    static let shared = LibraryManager()

    private let libraryKey = "library_animes"
    private let legacyBookmarksKey = "bookmarked_animes"
    private var cachedItems: [AnimeItem] = []

    private init() {
        loadLibrary()
    }

    private func loadLibrary() {
        if let data = UserDefaults.standard.data(forKey: libraryKey),
           let items = try? JSONDecoder().decode([AnimeItem].self, from: data) {
            cachedItems = items
            return
        }

        // Migrate old bookmarks key if present.
        if let data = UserDefaults.standard.data(forKey: legacyBookmarksKey),
           let items = try? JSONDecoder().decode([AnimeItem].self, from: data) {
            cachedItems = items
            saveLibrary()
            UserDefaults.standard.removeObject(forKey: legacyBookmarksKey)
            return
        }

        cachedItems = []
    }

    private func saveLibrary() {
        if let data = try? JSONEncoder().encode(cachedItems) {
            UserDefaults.standard.set(data, forKey: libraryKey)
            UserDefaults.standard.synchronize()
        }
    }

    var libraryItems: [AnimeItem] {
        get { cachedItems }
        set {
            cachedItems = newValue
            saveLibrary()
        }
    }

    func contains(_ anime: AnimeItem) -> Bool {
        cachedItems.contains { $0.id == anime.id }
    }

    func toggle(_ anime: AnimeItem) {
        if let index = cachedItems.firstIndex(where: { $0.id == anime.id }) {
            cachedItems.remove(at: index)
        } else {
            cachedItems.append(anime)
        }
        saveLibrary()
    }

    func remove(_ anime: AnimeItem) {
        cachedItems.removeAll { $0.id == anime.id }
        saveLibrary()
    }
}

// Backward compatibility during refactor.
typealias BookmarkManager = LibraryManager
