import SwiftUI
import SwiftData

@main
struct BlopApp: App {
    let container: ModelContainer
    @AppStorage("signifierMigrated") private var signifierMigrated = false

    init() {
        do {
            container = try ModelContainer(for:
                BulletEntry.self,
                DailyLog.self,
                MonthlyLog.self,
                HabitDefinition.self,
                HabitCompletion.self,
                Collection.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { migrateSignifiersIfNeeded() }
        }
        .modelContainer(container)
    }

    // One-time migration: entries where isPriority=true get signifier=.priority
    private func migrateSignifiersIfNeeded() {
        guard !signifierMigrated else { return }
        let context = ModelContext(container)
        let entries = (try? context.fetch(FetchDescriptor<BulletEntry>())) ?? []
        for entry in entries where entry.isPriority && entry.signifier == nil {
            entry.signifier = .priority
        }
        try? context.save()
        signifierMigrated = true
    }
}
