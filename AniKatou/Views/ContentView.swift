import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            TabView {
                NavigationView {
                    HomeView()
                }
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)
                
                NavigationView {
                    BookmarksView()
                }
                .tabItem {
                    Label("Bookmarks", systemImage: "bookmark")
                }
                .tag(1)
                
                NavigationView {
                    SearchView()
                }
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(2)
                
                NavigationView {
                    SettingsView()
                }
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
            }
        }
    }
}

#Preview {
    ContentView()
} 