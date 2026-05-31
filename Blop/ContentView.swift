import SwiftUI

struct ContentView: View {
    @StateObject private var appSettings = AppSettings.shared

    var body: some View {
        TabView {
            DailyLogView()
                .tabItem {
                    Label("Today", systemImage: "calendar.day.timeline.left")
                }

            MonthlyLogView()
                .tabItem {
                    Label("Month", systemImage: "calendar")
                }

            MonthlyReviewView()
                .tabItem {
                    Label("Review", systemImage: "chart.bar")
                }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
        .tint(BlopColor.accent)
        .preferredColorScheme(appSettings.preferredColorScheme)
    }
}
