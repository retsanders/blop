import Testing
import Foundation
import SwiftData
@testable import Blop

@Suite("DailyLogViewModel")
struct DailyLogViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: BulletEntry.self, DailyLog.self, MonthlyLog.self,
                HabitDefinition.self, HabitCompletion.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("fetchOrCreateLog creates a new log for an unseen date")
    func fetchOrCreateNew() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = DailyLogViewModel()
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 10))!

        let log = vm.fetchOrCreateLog(for: date, context: context)
        #expect(log.date == Calendar.current.startOfDay(for: date))
        #expect(log.entries.isEmpty)
    }

    @Test("fetchOrCreateLog returns existing log on second call")
    func fetchOrCreateIdempotent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = DailyLogViewModel()
        let date = Date()

        let first = vm.fetchOrCreateLog(for: date, context: context)
        let second = vm.fetchOrCreateLog(for: date, context: context)
        #expect(first.id == second.id)
    }

    @Test("addEntry inserts entry into log with correct type and priority")
    func addEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = DailyLogViewModel()
        let log = vm.fetchOrCreateLog(for: Date(), context: context)

        vm.addEntry(content: "Buy milk", type: .task, priority: true, scheduledDate: nil, to: log, context: context)
        #expect(log.entries.count == 1)
        #expect(log.entries.first?.content == "Buy milk")
        #expect(log.entries.first?.isPriority == true)
    }

    @Test("migrate copies entry to new log and marks original as migrated")
    func migrate() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = DailyLogViewModel()

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let sourceLog = vm.fetchOrCreateLog(for: yesterday, context: context)
        vm.addEntry(content: "Unfinished task", type: .task, to: sourceLog, context: context)
        let entry = sourceLog.entries.first!

        let todayLog = vm.fetchOrCreateLog(for: Date(), context: context)
        vm.migrate(entry, to: todayLog, context: context)

        #expect(entry.status == .migrated)
        #expect(todayLog.entries.count == 1)
        #expect(todayLog.entries.first?.migrationCount == 1)
        #expect(todayLog.entries.first?.content == "Unfinished task")
    }

    @Test("drop marks entry as cancelled")
    func drop() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = DailyLogViewModel()
        let log = vm.fetchOrCreateLog(for: Date(), context: context)
        vm.addEntry(content: "Drop me", type: .task, to: log, context: context)

        let entry = log.entries.first!
        vm.drop(entry)
        #expect(entry.status == .cancelled)
    }

    @Test("schedule moves entry to monthly log and marks original as scheduled")
    func schedule() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = DailyLogViewModel()

        let log = vm.fetchOrCreateLog(for: Date(), context: context)
        vm.addEntry(content: "Monthly task", type: .task, to: log, context: context)
        let entry = log.entries.first!

        let monthLog = MonthlyLog(year: 2026, month: 5)
        context.insert(monthLog)

        vm.schedule(entry, monthlyLog: monthLog, context: context)
        #expect(entry.status == .scheduled)
        #expect(monthLog.entries.count == 1)
        #expect(monthLog.entries.first?.content == "Monthly task")
    }
}
