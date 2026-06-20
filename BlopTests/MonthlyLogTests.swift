import Testing
import Foundation
import SwiftData
@testable import Blop

@Suite("MonthlyLog")
struct MonthlyLogTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: BulletEntry.self, DailyLog.self, MonthlyLog.self,
                HabitDefinition.self, HabitCompletion.self, Collection.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test("displayTitle formats month and year correctly")
    func displayTitle() {
        #expect(MonthlyLog(year: 2026, month: 5).displayTitle == "May 2026")
        #expect(MonthlyLog(year: 2025, month: 1).displayTitle == "January 2025")
        #expect(MonthlyLog(year: 2024, month: 12).displayTitle == "December 2024")
    }

    @Test("displayTitle returns empty string for invalid month/year combination")
    func displayTitleInvalid() {
        // month 0 is not a valid DateComponents month
        #expect(MonthlyLog(year: 2026, month: 0).displayTitle == "")
    }

    @Test("sortedTasks returns tasks and notes ordered by sortOrder, excluding events")
    func sortedTasks() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = MonthlyLog(year: 2026, month: 5)
        context.insert(log)

        let task = BulletEntry(content: "Task", type: .task, sortOrder: 1)
        task.monthlyLog = log
        context.insert(task)

        let note = BulletEntry(content: "Note", type: .note, sortOrder: 0)
        note.monthlyLog = log
        context.insert(note)

        let event = BulletEntry(content: "Event", type: .event, sortOrder: 2)
        event.monthlyLog = log
        context.insert(event)

        let sorted = log.sortedTasks
        #expect(sorted.count == 2)
        #expect(sorted[0].content == "Note")
        #expect(sorted[1].content == "Task")
    }

    @Test("sortedEvents includes only events whose scheduledDate falls within the log month")
    func sortedEventsFiltersByMonth() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = MonthlyLog(year: 2026, month: 5)
        context.insert(log)

        let inMonth = BulletEntry(
            content: "May event",
            type: .event,
            scheduledDate: date(year: 2026, month: 5, day: 10)
        )
        inMonth.monthlyLog = log
        context.insert(inMonth)

        let wrongMonth = BulletEntry(
            content: "June event",
            type: .event,
            scheduledDate: date(year: 2026, month: 6, day: 1)
        )
        wrongMonth.monthlyLog = log
        context.insert(wrongMonth)

        let wrongYear = BulletEntry(
            content: "May 2025 event",
            type: .event,
            scheduledDate: date(year: 2025, month: 5, day: 10)
        )
        wrongYear.monthlyLog = log
        context.insert(wrongYear)

        #expect(log.sortedEvents.count == 1)
        #expect(log.sortedEvents.first?.content == "May event")
    }

    @Test("sortedEvents orders events by scheduledDate ascending")
    func sortedEventsOrdering() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = MonthlyLog(year: 2026, month: 5)
        context.insert(log)

        let later = BulletEntry(
            content: "Later",
            type: .event,
            scheduledDate: date(year: 2026, month: 5, day: 20)
        )
        later.monthlyLog = log
        context.insert(later)

        let earlier = BulletEntry(
            content: "Earlier",
            type: .event,
            scheduledDate: date(year: 2026, month: 5, day: 5)
        )
        earlier.monthlyLog = log
        context.insert(earlier)

        let sorted = log.sortedEvents
        #expect(sorted.count == 2)
        #expect(sorted[0].content == "Earlier")
        #expect(sorted[1].content == "Later")
    }

    @Test("sortedEvents excludes tasks and notes")
    func sortedEventsExcludesNonEvents() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = MonthlyLog(year: 2026, month: 5)
        context.insert(log)

        let task = BulletEntry(
            content: "Task",
            type: .task,
            scheduledDate: date(year: 2026, month: 5, day: 1)
        )
        task.monthlyLog = log
        context.insert(task)

        let note = BulletEntry(
            content: "Note",
            type: .note,
            scheduledDate: date(year: 2026, month: 5, day: 1)
        )
        note.monthlyLog = log
        context.insert(note)

        #expect(log.sortedEvents.isEmpty)
    }

    @Test("sortedEvents excludes an event whose createdAt falls outside the log month when scheduledDate is nil")
    func sortedEventsExcludesEventWithCreatedAtOutsideMonth() {
        // Use a clearly historical log so Date() (today) is guaranteed to be outside it
        let log = MonthlyLog(year: 2020, month: 1)
        let event = BulletEntry(content: "No scheduled date", type: .event)
        event.monthlyLog = log
        #expect(log.sortedEvents.isEmpty)
    }
}
