import Foundation
import SwiftUI

@MainActor
class LibraryCollectionViewModel: ObservableObject {
    @Published var libraryItems: [AnimeItem] = []
    private var notificationObserver: NSObjectProtocol?

    init() {
        refreshLibrary()
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
            Task { @MainActor in
                self?.refreshLibrary()
            }
        }
    }

    private func refreshLibrary() {
        withAnimation {
            libraryItems = LibraryManager.shared.libraryItems
        }
    }
}
