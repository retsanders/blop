import Testing
import Foundation
import SwiftData
@testable import Blop

@Suite("ExportService")
struct ExportServiceTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: BulletEntry.self, DailyLog.self, MonthlyLog.self,
                HabitDefinition.self, HabitCompletion.self, Collection.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("exportDailyLog produces correct markdown header")
    func dailyLogHeader() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 30))!
        let log = DailyLog(date: date)
        context.insert(log)

        let service = ExportService()
        let output = service.exportDailyLog(log)
        #expect(output.hasPrefix("# 2026-05-30"))
    }

    @Test("exportDailyLog renders open task with bullet signifier")
    func dailyLogTaskEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = DailyLog(date: Date())
        context.insert(log)
        let entry = BulletEntry(content: "Write tests", type: .task)
        entry.dailyLog = log
        context.insert(entry)

        let service = ExportService()
        let output = service.exportDailyLog(log)
        #expect(output.contains("• Write tests"))
    }

    @Test("exportDailyLog renders complete entry with checkmark")
    func dailyLogCompleteEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = DailyLog(date: Date())
        context.insert(log)
        let entry = BulletEntry(content: "Done task", type: .task)
        entry.status = .complete
        entry.dailyLog = log
        context.insert(entry)

        let service = ExportService()
        let output = service.exportDailyLog(log)
        #expect(output.contains("✕ Done task"))
    }

    @Test("exportDailyLog renders priority with asterisk suffix")
    func dailyLogPriorityEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = DailyLog(date: Date())
        context.insert(log)
        let entry = BulletEntry(content: "Important", type: .task)
        entry.isPriority = true
        entry.dailyLog = log
        context.insert(entry)

        let service = ExportService()
        let output = service.exportDailyLog(log)
        #expect(output.contains("• Important *"))
    }

    @Test("exportDailyLog renders cancelled entry with dash")
    func dailyLogCancelledEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = DailyLog(date: Date())
        context.insert(log)
        let entry = BulletEntry(content: "Dropped task", type: .task)
        entry.status = .cancelled
        entry.dailyLog = log
        context.insert(entry)

        let service = ExportService()
        let output = service.exportDailyLog(log)
        #expect(output.contains("– Dropped task"))
    }

    @Test("exportDailyLog renders note entry with dash")
    func dailyLogNoteEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = DailyLog(date: Date())
        context.insert(log)
        let entry = BulletEntry(content: "Interesting observation", type: .note)
        entry.dailyLog = log
        context.insert(entry)

        let service = ExportService()
        let output = service.exportDailyLog(log)
        #expect(output.contains("– Interesting observation"))
    }

    @Test("exportDailyLog renders scheduled entry with left-arrow sigil")
    func dailyLogScheduledEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = DailyLog(date: Date())
        context.insert(log)
        let entry = BulletEntry(content: "Deferred to monthly", type: .task)
        entry.status = .scheduled
        entry.dailyLog = log
        context.insert(entry)

        let service = ExportService()
        let output = service.exportDailyLog(log)
        #expect(output.contains("< Deferred to monthly"))
    }

    @Test("exportMonthlyLog renders tasks and events sections")
    func monthlyLogSections() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = MonthlyLog(year: 2026, month: 5)
        context.insert(log)

        let task = BulletEntry(content: "Monthly goal", type: .task)
        task.monthlyLog = log
        context.insert(task)

        let event = BulletEntry(
            content: "Team offsite",
            type: .event,
            scheduledDate: Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 10))
        )
        event.monthlyLog = log
        context.insert(event)

        let service = ExportService()
        let output = service.exportMonthlyLog(log)
        #expect(output.contains("## Tasks"))
        #expect(output.contains("• Monthly goal"))
        #expect(output.contains("## Events"))
        #expect(output.contains("○ Team offsite"))
    }
}
