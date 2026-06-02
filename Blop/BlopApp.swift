import SwiftUI
import SwiftData

@main
struct BlopApp: App {
    let container: ModelContainer
    @AppStorage("signifierMigrated") private var signifierMigrated = false

    init() {
        let schema = Schema([
            BulletEntry.self, DailyLog.self, MonthlyLog.self,
            HabitDefinition.self, HabitCompletion.self, Collection.self
        ])
        do {
            container = try ModelContainer(for: schema)
        } catch {
            // Schema mismatch or store corruption — wipe and start fresh.
            // The user will see a one-time alert in ContentView explaining the reset.
            let supportDir = URL.applicationSupportDirectory
            for ext in ["default.store", "default.store-shm", "default.store-wal"] {
                try? FileManager.default.removeItem(at: supportDir.appending(path: ext))
            }
            UserDefaults.standard.set(true, forKey: "dataWipedAfterCrash")
            container = try! ModelContainer(for: schema)
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
