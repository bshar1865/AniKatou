import Foundation
import SwiftUI

@MainActor
class HomeViewModel: ObservableObject {
    @Published var bookmarkedAnimes: [AnimeItem] = []
    
    init() {
        bookmarkedAnimes = BookmarkManager.shared.bookmarkedAnimes
        
        // Observe bookmark changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(bookmarksDidChange),
            name: NSNotification.Name("BookmarksDidChange"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func bookmarksDidChange() {
        bookmarkedAnimes = BookmarkManager.shared.bookmarkedAnimes
    }
} 