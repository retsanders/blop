import Testing
import Foundation
import SwiftData
@testable import Blop

@Suite("BulletEntry")
struct BulletEntryTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: BulletEntry.self, DailyLog.self, MonthlyLog.self,
                HabitDefinition.self, HabitCompletion.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("Default init sets open status and zero migrationCount")
    func defaultInit() {
        let entry = BulletEntry(content: "Write tests")
        #expect(entry.status == .open)
        #expect(entry.migrationCount == 0)
        #expect(entry.isPriority == false)
        #expect(entry.type == .task)
        #expect(entry.scheduledDate == nil)
    }

    @Test("scheduledDate is stored and retrievable")
    func scheduledDateStored() {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let entry = BulletEntry(content: "Team offsite", type: .event, scheduledDate: date)
        #expect(entry.scheduledDate == date)
    }

    @Test("migratedForward increments migrationCount and preserves content")
    func migratedForward() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let log = DailyLog(date: Date())
        context.insert(log)

        let entry = BulletEntry(content: "Ship feature", migrationCount: 2)
        context.insert(entry)

        let copy = entry.migratedForward(into: log)
        #expect(copy.content == "Ship feature")
        #expect(copy.migrationCount == 3)
        #expect(copy.migratedFrom != nil)
        #expect(copy.isPriority == entry.isPriority)
    }

    @Test("signifier returns correct characters for each status")
    func signifierCharacters() {
        let task = BulletEntry(content: "t", type: .task)
        #expect(task.signifier(atThreshold: 3) == "•")

        task.status = .complete
        #expect(task.signifier(atThreshold: 3) == "✕")

        task.status = .migrated
        task.migrationCount = 2
        #expect(task.signifier(atThreshold: 3) == ">")

        task.migrationCount = 3
        #expect(task.signifier(atThreshold: 3) == "⚠")

        let event = BulletEntry(content: "e", type: .event)
        #expect(event.signifier(atThreshold: 3) == "○")

        let note = BulletEntry(content: "n", type: .note)
        #expect(note.signifier(atThreshold: 3) == "–")
    }

    @Test("Cancelling an entry sets status to cancelled")
    func cancelStatus() {
        let entry = BulletEntry(content: "Task to cancel")
        entry.status = .cancelled
        #expect(entry.status == .cancelled)
    }
}
