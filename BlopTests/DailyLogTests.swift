import Testing
import Foundation
import SwiftData
@testable import Blop

@Suite("DailyLog")
struct DailyLogTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: BulletEntry.self, DailyLog.self, MonthlyLog.self,
                HabitDefinition.self, HabitCompletion.self, Collection.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("init normalises date to start of day")
    func initNormalisesDate() {
        let noon = Calendar.current.date(
            from: DateComponents(year: 2026, month: 5, day: 15, hour: 12, minute: 30))!
        let log = DailyLog(date: noon)
        #expect(log.date == Calendar.current.startOfDay(for: noon))
    }

    @Test("sortedEntries orders entries by sortOrder ascending")
    func sortedEntries() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = DailyLog(date: Date())
        context.insert(log)

        let e1 = BulletEntry(content: "Third", type: .task, sortOrder: 2)
        e1.dailyLog = log
        context.insert(e1)

        let e2 = BulletEntry(content: "First", type: .task, sortOrder: 0)
        e2.dailyLog = log
        context.insert(e2)

        let e3 = BulletEntry(content: "Second", type: .task, sortOrder: 1)
        e3.dailyLog = log
        context.insert(e3)

        let sorted = log.sortedEntries
        #expect(sorted[0].content == "First")
        #expect(sorted[1].content == "Second")
        #expect(sorted[2].content == "Third")
    }

    @Test("openTasks returns only open task-type entries")
    func openTasksFiltersCorrectly() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = DailyLog(date: Date())
        context.insert(log)

        let open = BulletEntry(content: "Open task", type: .task)
        open.dailyLog = log
        context.insert(open)

        let complete = BulletEntry(content: "Done task", type: .task)
        complete.status = .complete
        complete.dailyLog = log
        context.insert(complete)

        let note = BulletEntry(content: "A note", type: .note)
        note.dailyLog = log
        context.insert(note)

        let event = BulletEntry(content: "An event", type: .event)
        event.dailyLog = log
        context.insert(event)

        #expect(log.openTasks.count == 1)
        #expect(log.openTasks.first?.content == "Open task")
    }

    @Test("openTasks returns empty when all tasks are resolved")
    func openTasksEmptyWhenAllResolved() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = DailyLog(date: Date())
        context.insert(log)

        for status in [EntryStatus.complete, .migrated, .cancelled, .scheduled] {
            let entry = BulletEntry(content: "Task", type: .task)
            entry.status = status
            entry.dailyLog = log
            context.insert(entry)
        }

        #expect(log.openTasks.isEmpty)
    }
}
