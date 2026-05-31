import SwiftUI
import SwiftData

@main
struct BlopApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for:
                BulletEntry.self,
                DailyLog.self,
                MonthlyLog.self,
                HabitDefinition.self,
                HabitCompletion.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
