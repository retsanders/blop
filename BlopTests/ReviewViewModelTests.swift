import Testing
import Foundation
import SwiftData
@testable import Blop

@Suite("ReviewViewModel")
struct ReviewViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: BulletEntry.self, DailyLog.self, MonthlyLog.self,
                HabitDefinition.self, HabitCompletion.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test("Completion rate is correct with mix of open and complete tasks")
    func completionRate() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = DailyLog(date: date(year: 2026, month: 5, day: 1))
        context.insert(log)

        for i in 0..<4 {
            let entry = BulletEntry(content: "Task \(i)", type: .task, sortOrder: i)
            entry.status = i < 3 ? .complete : .open
            entry.dailyLog = log
            context.insert(entry)
        }

        let vm = ReviewViewModel()
        vm.generate(year: 2026, month: 5, threshold: 3, context: context)

        let review = try #require(vm.review)
        #expect(review.totalTasks == 4)
        #expect(review.completedTasks == 3)
        #expect(abs(review.completionRate - 0.75) < 0.001)
    }

    @Test("Average migration count is calculated from tasks that were migrated")
    func averageMigrationCount() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = DailyLog(date: date(year: 2026, month: 5, day: 1))
        context.insert(log)

        let counts = [0, 2, 4]
        for (i, count) in counts.enumerated() {
            let entry = BulletEntry(content: "Task \(i)", type: .task, sortOrder: i, migrationCount: count)
            entry.dailyLog = log
            context.insert(entry)
        }

        let vm = ReviewViewModel()
        vm.generate(year: 2026, month: 5, threshold: 3, context: context)

        let review = try #require(vm.review)
        // only entries with migrationCount > 0 are counted
        #expect(abs(review.averageMigrationCount - 3.0) < 0.001)
    }

    @Test("Threshold hits count entries at or above the threshold")
    func thresholdHits() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let log = DailyLog(date: date(year: 2026, month: 5, day: 1))
        context.insert(log)

        for (i, count) in [1, 2, 3, 4].enumerated() {
            let entry = BulletEntry(content: "T\(i)", type: .task, sortOrder: i, migrationCount: count)
            entry.dailyLog = log
            context.insert(entry)
        }

        let vm = ReviewViewModel()
        vm.generate(year: 2026, month: 5, threshold: 3, context: context)

        let review = try #require(vm.review)
        #expect(review.thresholdHits == 2) // migrationCount 3 and 4
    }

    @Test("Habit streak counts consecutive completed days from most recent")
    func habitStreak() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let habit = HabitDefinition(name: "Exercise")
        context.insert(habit)

        let completions = [(1, true), (2, true), (3, true), (4, false), (5, true)]
        for (day, done) in completions {
            let log = DailyLog(date: date(year: 2026, month: 5, day: day))
            context.insert(log)
            let c = HabitCompletion(habit: habit, date: log.date, completed: done)
            c.dailyLog = log
            context.insert(c)
        }

        let vm = ReviewViewModel()
        vm.generate(year: 2026, month: 5, threshold: 3, context: context)

        let review = try #require(vm.review)
        let stat = try #require(review.habitStats.first)
        // streak from day 5 backward: day 5 done, day 4 not done → streak = 1
        #expect(stat.streak == 1)
    }
}
