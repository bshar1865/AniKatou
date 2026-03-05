import Foundation
import SwiftUI

@MainActor
class LibraryCollectionViewModel: ObservableObject {
    @Published var libraryItems: [AnimeItem] = []
    private var notificationObserver: NSObjectProtocol?

    init() {
        loadLibrary()
        setupNotificationObserver()
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupNotificationObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LibraryDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadLibrary()
        }
    }

    private func loadLibrary() {
        withAnimation {
            libraryItems = LibraryManager.shared.libraryItems
        }
    }
}
