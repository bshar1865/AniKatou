import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(0)

            NavigationStack {
                FavoritesView()
            }
            .tabItem {
                Label("Favourites", systemImage: "heart")
            }
            .tag(1)

            NavigationStack {
                LibraryView()
            }
            .tabItem {
                Label("Library", systemImage: "books.vertical")
            }
            .tag(2)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(3)
        }
    }
}
