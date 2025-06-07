import Foundation
import SwiftUI

@MainActor
class BookmarksViewModel: ObservableObject {
    @Published var bookmarkedAnimes: [AnimeItem] = []
    private var notificationObserver: NSObjectProtocol?
    
    init() {
        loadBookmarks()
        setupNotificationObserver()
    }
    
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupNotificationObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("BookmarksDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                // If we have the anime ID that was changed, only update that one
                if let animeId = notification.userInfo?["animeId"] as? String {
                    self?.updateSingleBookmark(animeId)
                } else {
                    // Otherwise reload all bookmarks
                    self?.loadBookmarks()
                }
            }
        }
    }
    
    private func updateSingleBookmark(_ animeId: String) {
        let isBookmarked = BookmarkManager.shared.bookmarkedAnimes.contains { $0.id == animeId }
        
        if isBookmarked {
            // Add the anime if it's not already in the list
            if !bookmarkedAnimes.contains(where: { $0.id == animeId }) {
                if let anime = BookmarkManager.shared.bookmarkedAnimes.first(where: { $0.id == animeId }) {
                    withAnimation {
                        bookmarkedAnimes.append(anime)
                    }
                }
            }
        } else {
            // Remove the anime if it's in the list
            withAnimation {
                bookmarkedAnimes.removeAll { $0.id == animeId }
            }
        }
    }
    
    private func loadBookmarks() {
        withAnimation {
            bookmarkedAnimes = BookmarkManager.shared.bookmarkedAnimes
        }
    }
} 