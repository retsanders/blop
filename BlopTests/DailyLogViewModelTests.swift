import Testing
import Foundation
import SwiftData
@testable import Blop

@Suite("DailyLogViewModel")
struct DailyLogViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: BulletEntry.self, DailyLog.self, MonthlyLog.self,
                HabitDefinition.self, HabitCompletion.self, Collection.self,
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

        vm.addEntry(content: "Buy milk", type: .task, signifier: .priority, scheduledDate: nil, to: log, context: context)
        #expect(log.entries.count == 1)
        #expect(log.entries.first?.content == "Buy milk")
        #expect(log.entries.first?.signifier == .priority)
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

    // MARK: - toggleComplete

    @Test("toggleComplete sets an open entry to complete")
    func toggleCompleteOpenToComplete() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = DailyLogViewModel()
        let log = vm.fetchOrCreateLog(for: Date(), context: context)
        vm.addEntry(content: "Toggle me", type: .task, to: log, context: context)
        let entry = log.entries.first!

        vm.toggleComplete(entry)
        #expect(entry.status == .complete)
    }

    @Test("toggleComplete sets a complete entry back to open")
    func toggleCompleteCompleteToOpen() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = DailyLogViewModel()
        let log = vm.fetchOrCreateLog(for: Date(), context: context)
        vm.addEntry(content: "Toggle me", type: .task, to: log, context: context)
        let entry = log.entries.first!
        entry.status = .complete

        vm.toggleComplete(entry)
        #expect(entry.status == .open)
    }

    // MARK: - cancel

    @Test("cancel sets entry status to cancelled")
    func cancelEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = DailyLogViewModel()
        let log = vm.fetchOrCreateLog(for: Date(), context: context)
        vm.addEntry(content: "Cancel me", type: .task, to: log, context: context)
        let entry = log.entries.first!

        vm.cancel(entry)
        #expect(entry.status == .cancelled)
    }

    // MARK: - fetchLog

    @Test("fetchLog returns nil when no log exists for the given date")
    func fetchLogReturnsNil() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = DailyLogViewModel()
        let date = Calendar.current.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        #expect(vm.fetchLog(for: date, context: context) == nil)
    }

    @Test("fetchLog returns the existing log for a date that has one")
    func fetchLogReturnsExisting() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = DailyLogViewModel()
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 15))!

        let created = vm.fetchOrCreateLog(for: date, context: context)
        let fetched = vm.fetchLog(for: date, context: context)
        #expect(fetched?.id == created.id)
    }

    // MARK: - ensureHabitCompletions

    @Test("ensureHabitCompletions adds completions for active habits not yet tracked")
    func ensureHabitCompletionsAddsNew() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = DailyLogViewModel()
        let log = vm.fetchOrCreateLog(for: Date(), context: context)

        let h1 = HabitDefinition(name: "Exercise")
        let h2 = HabitDefinition(name: "Read")
        context.insert(h1)
        context.insert(h2)

        vm.ensureHabitCompletions(for: log, habits: [h1, h2], context: context)
        #expect(log.habitCompletions.count == 2)
    }

    @Test("ensureHabitCompletions is idempotent on repeated calls")
    func ensureHabitCompletionsIdempotent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = DailyLogViewModel()
        let log = vm.fetchOrCreateLog(for: Date(), context: context)

        let habit = HabitDefinition(name: "Meditate")
        context.insert(habit)

        vm.ensureHabitCompletions(for: log, habits: [habit], context: context)
        vm.ensureHabitCompletions(for: log, habits: [habit], context: context)
        #expect(log.habitCompletions.count == 1)
    }

    @Test("ensureHabitCompletions skips inactive habits")
    func ensureHabitCompletionsSkipsInactive() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = DailyLogViewModel()
        let log = vm.fetchOrCreateLog(for: Date(), context: context)

        let active = HabitDefinition(name: "Active")
        let inactive = HabitDefinition(name: "Inactive")
        inactive.isActive = false
        context.insert(active)
        context.insert(inactive)

        vm.ensureHabitCompletions(for: log, habits: [active, inactive], context: context)
        #expect(log.habitCompletions.count == 1)
        #expect(log.habitCompletions.first?.habit?.name == "Active")
    }

    // MARK: - Navigation

    @Test("isToday returns true when selectedDate is today")
    func isTodayTrue() {
        let vm = DailyLogViewModel()
        vm.selectedDate = Calendar.current.startOfDay(for: Date())
        #expect(vm.isToday == true)
    }

    @Test("isToday returns false when selectedDate is not today")
    func isTodayFalse() {
        let vm = DailyLogViewModel()
        vm.selectedDate = Calendar.current.date(from: DateComponents(year: 2020, month: 1, day: 1))!
        #expect(vm.isToday == false)
    }

    @Test("goToPreviousDay decrements selectedDate by one day")
    func goToPreviousDay() {
        let vm = DailyLogViewModel()
        vm.selectedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 15))!
        vm.goToPreviousDay()
        let expected = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 14))!
        #expect(vm.selectedDate == expected)
    }

    @Test("goToNextDay increments selectedDate by one day")
    func goToNextDay() {
        let vm = DailyLogViewModel()
        vm.selectedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 15))!
        vm.goToNextDay()
        let expected = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 16))!
        #expect(vm.selectedDate == expected)
    }

    @Test("goToToday resets selectedDate to today regardless of previous value")
    func goToToday() {
        let vm = DailyLogViewModel()
        vm.selectedDate = Calendar.current.date(from: DateComponents(year: 2020, month: 1, day: 1))!
        vm.goToToday()
        #expect(Calendar.current.isDateInToday(vm.selectedDate))
    }
}
