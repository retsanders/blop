import SwiftUI

struct ContentView: View {
    @StateObject private var appSettings = AppSettings.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DailyLogView()
                .tabItem { Label("Today", systemImage: "calendar.day.timeline.left") }
                .tag(0)

            MonthlyLogView()
                .tabItem { Label("Month", systemImage: "calendar") }
                .tag(1)

            FutureLogView()
                .tabItem { Label("Future", systemImage: "calendar.badge.clock") }
                .tag(2)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(3)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gear") }
            .tag(4)
        }
        .tint(BlopColor.accent)
        .preferredColorScheme(appSettings.preferredColorScheme)
    }
}
