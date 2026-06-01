import SwiftUI

struct ContentView: View {
    @AppStorage("themePreference") private var themePreference: String = "system"
    @SceneStorage("selectedTab") private var selectedTab: Int = 0
    @State private var toastMessage: String? = nil

    private var preferredColorScheme: ColorScheme? {
        switch themePreference {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

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
        .preferredColorScheme(preferredColorScheme)
        .overlay(alignment: .bottom) {
            if let msg = toastMessage {
                Text(msg)
                    .font(BlopFont.mono(12))
                    .foregroundStyle(BlopColor.background)
                    .padding(.horizontal, BlopSpacing.md)
                    .padding(.vertical, BlopSpacing.sm)
                    .background(BlopColor.ink.opacity(0.8))
                    .clipShape(Capsule())
                    .padding(.bottom, 100)
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: toastMessage)
        .onReceive(NotificationCenter.default.publisher(for: .signifierToast)) { note in
            toastMessage = note.object as? String
            Task {
                try? await Task.sleep(for: .milliseconds(1500))
                toastMessage = nil
            }
        }
    }
}
