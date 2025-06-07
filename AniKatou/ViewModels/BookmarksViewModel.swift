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
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.loadBookmarks()
            }
        }
    }
    
    private func loadBookmarks() {
        withAnimation {
            bookmarkedAnimes = BookmarkManager.shared.bookmarkedAnimes
        }
    }
} 