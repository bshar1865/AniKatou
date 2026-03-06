import SwiftUI
import UIKit

struct ContentView: View {
    @State private var selectedTab = 0

    init() {
        configureTabBarAppearance()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
            }
            .tag(0)

            NavigationStack {
                LibraryView()
            }
            .tabItem {
                Label("Library", systemImage: selectedTab == 1 ? "books.vertical.fill" : "books.vertical")
            }
            .tag(1)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: selectedTab == 2 ? "gearshape.fill" : "gearshape")
            }
            .tag(2)

            NavigationStack {
                SearchView()
            }
            .tabItem {
                Label("Search", systemImage: selectedTab == 3 ? "magnifyingglass.circle.fill" : "magnifyingglass")
            }
            .tag(3)
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.72)
        appearance.shadowColor = UIColor.separator.withAlphaComponent(0.08)

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor.secondaryLabel
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.secondaryLabel]
        itemAppearance.selected.iconColor = UIColor.label
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.label]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
