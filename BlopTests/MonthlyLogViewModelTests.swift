import Testing
import Foundation
import SwiftData
@testable import Blop

@Suite("MonthlyLogViewModel")
struct MonthlyLogViewModelTests {

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

    @Test("fetchOrCreate creates a new log for an unseen year/month")
    func fetchOrCreateNew() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = MonthlyLogViewModel()

        let log = vm.fetchOrCreate(year: 2025, month: 3, context: context)
        #expect(log.year == 2025)
        #expect(log.month == 3)
        #expect(log.entries.isEmpty)
    }

    @Test("fetchOrCreate returns same log on repeated calls")
    func fetchOrCreateIdempotent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = MonthlyLogViewModel()

        let first = vm.fetchOrCreate(year: 2025, month: 6, context: context)
        let second = vm.fetchOrCreate(year: 2025, month: 6, context: context)
        #expect(first.id == second.id)
    }

    @Test("previousMonthComponents rolls back one month within a year")
    func previousMonthNormal() {
        let vm = MonthlyLogViewModel()
        vm.selectedYear = 2026
        vm.selectedMonth = 5

        let prev = vm.previousMonthComponents
        #expect(prev.year == 2026)
        #expect(prev.month == 4)
    }

    @Test("previousMonthComponents wraps January back to December of previous year")
    func previousMonthWrapsYear() {
        let vm = MonthlyLogViewModel()
        vm.selectedYear = 2026
        vm.selectedMonth = 1

        let prev = vm.previousMonthComponents
        #expect(prev.year == 2025)
        #expect(prev.month == 12)
    }

    @Test("addTask inserts a task entry into the monthly log")
    func addTask() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = MonthlyLogViewModel()
        let log = vm.fetchOrCreate(year: 2026, month: 5, context: context)

        vm.addTask(content: "Finish Q2 report", to: log, context: context)

        #expect(log.entries.count == 1)
        let entry = try #require(log.entries.first)
        #expect(entry.content == "Finish Q2 report")
        #expect(entry.type == .task)
    }

    @Test("addEvent inserts an event entry with scheduledDate")
    func addEvent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = MonthlyLogViewModel()
        let log = vm.fetchOrCreate(year: 2026, month: 5, context: context)
        let eventDate = date(year: 2026, month: 5, day: 15)

        vm.addEvent(content: "Team offsite", scheduledDate: eventDate, to: log, context: context)

        #expect(log.entries.count == 1)
        let entry = try #require(log.entries.first)
        #expect(entry.content == "Team offsite")
        #expect(entry.type == .event)
        #expect(entry.scheduledDate == eventDate)
    }

    @Test("carryForwardTasks returns open tasks from previous month's daily logs")
    func carryForwardTasks() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = MonthlyLogViewModel()
        vm.selectedYear = 2026
        vm.selectedMonth = 5

        // Create a daily log in April with one open task and one complete task
        let aprilDay = date(year: 2026, month: 4, day: 10)
        let aprilLog = DailyLog(date: aprilDay)
        context.insert(aprilLog)

        let openTask = BulletEntry(content: "Carry me forward", type: .task)
        openTask.dailyLog = aprilLog
        context.insert(openTask)

        let doneTask = BulletEntry(content: "Already done", type: .task)
        doneTask.status = .complete
        doneTask.dailyLog = aprilLog
        context.insert(doneTask)

        try context.save()

        let carried = vm.carryForwardTasks(from: context)
        #expect(carried.count == 1)
        #expect(carried.first?.content == "Carry me forward")
    }

    @Test("carryForwardTasks excludes daily logs outside the previous month")
    func carryForwardExcludesOtherMonths() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = MonthlyLogViewModel()
        vm.selectedYear = 2026
        vm.selectedMonth = 5

        // March log should NOT be included (two months back)
        let marchDay = date(year: 2026, month: 3, day: 20)
        let marchLog = DailyLog(date: marchDay)
        context.insert(marchLog)
        let marchTask = BulletEntry(content: "March task", type: .task)
        marchTask.dailyLog = marchLog
        context.insert(marchTask)

        try context.save()

        let carried = vm.carryForwardTasks(from: context)
        #expect(carried.isEmpty)
    }

    @Test("carryForwardTasks excludes notes and events from the previous month")
    func carryForwardExcludesNonTasks() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = MonthlyLogViewModel()
        vm.selectedYear = 2026
        vm.selectedMonth = 5

        let aprilDay = date(year: 2026, month: 4, day: 10)
        let aprilLog = DailyLog(date: aprilDay)
        context.insert(aprilLog)

        let note = BulletEntry(content: "A note", type: .note)
        note.dailyLog = aprilLog
        context.insert(note)

        let event = BulletEntry(content: "An event", type: .event)
        event.dailyLog = aprilLog
        context.insert(event)

        try context.save()

        let carried = vm.carryForwardTasks(from: context)
        #expect(carried.isEmpty)
    }

    @Test("fetchOrCreateLog delegates to fetchOrCreate using the selected year and month")
    func fetchOrCreateLogUsesSelectedYearMonth() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = MonthlyLogViewModel()
        vm.selectedYear = 2025
        vm.selectedMonth = 8

        let log = vm.fetchOrCreateLog(context: context)
        #expect(log.year == 2025)
        #expect(log.month == 8)
    }
}
