import Foundation
import SwiftData

struct MonthlyReview {
    var completionRate: Double
    var totalTasks: Int
    var completedTasks: Int
    var migratedTasks: Int
    var cancelledTasks: Int
    var averageMigrationCount: Double
    var thresholdHits: Int
    var habitStats: [HabitStat]
    var mostProductiveDay: String?
}

struct HabitStat {
    var habit: HabitDefinition
    var completionRate: Double
    var streak: Int
}

@Observable
final class ReviewViewModel {
    var review: MonthlyReview?

    func generate(year: Int, month: Int, threshold: Int, context: ModelContext) {
        let startOfMonth = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))!
        let endOfMonth = Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth)!

        let logDescriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date >= startOfMonth && $0.date < endOfMonth }
        )
        let logs = (try? context.fetch(logDescriptor)) ?? []
        let allEntries = logs.flatMap { $0.entries }
        let tasks = allEntries.filter { $0.type == .task }

        let completed = tasks.filter { $0.status == .complete }.count
        let migrated = tasks.filter { $0.status == .migrated }.count
        let cancelled = tasks.filter { $0.status == .cancelled }.count
        let total = tasks.count
        let completionRate = total > 0 ? Double(completed) / Double(total) : 0

        let resolvedWithMigration = tasks.filter { $0.migrationCount > 0 }
        let avgMigration = resolvedWithMigration.isEmpty ? 0.0 :
            Double(resolvedWithMigration.map(\.migrationCount).reduce(0, +)) / Double(resolvedWithMigration.count)
        let thresholdHits = tasks.filter { $0.migrationCount >= threshold }.count

        let completionsByDay = Dictionary(grouping: tasks.filter { $0.status == .complete }) { entry -> String in
            let weekday = Calendar.current.component(.weekday, from: entry.createdAt)
            return Calendar.current.weekdaySymbols[weekday - 1]
        }
        let mostProductiveDay = completionsByDay.max(by: { $0.value.count < $1.value.count })?.key

        let habitDescriptor = FetchDescriptor<HabitDefinition>(
            predicate: #Predicate { $0.isActive }
        )
        let habits = (try? context.fetch(habitDescriptor)) ?? []
        let allCompletions = logs.flatMap { $0.habitCompletions }
        let dayCount = logs.count

        let habitStats: [HabitStat] = habits.map { habit in
            let completions = allCompletions.filter { $0.habit?.id == habit.id }
            let doneCount = completions.filter { $0.completed }.count
            let rate = dayCount > 0 ? Double(doneCount) / Double(dayCount) : 0
            let streak = computeStreak(for: habit, in: logs)
            return HabitStat(habit: habit, completionRate: rate, streak: streak)
        }

        review = MonthlyReview(
            completionRate: completionRate,
            totalTasks: total,
            completedTasks: completed,
            migratedTasks: migrated,
            cancelledTasks: cancelled,
            averageMigrationCount: avgMigration,
            thresholdHits: thresholdHits,
            habitStats: habitStats,
            mostProductiveDay: mostProductiveDay
        )
    }

    private func computeStreak(for habit: HabitDefinition, in logs: [DailyLog]) -> Int {
        let sorted = logs.sorted { $0.date > $1.date }
        var streak = 0
        for log in sorted {
            guard let completion = log.habitCompletions.first(where: { $0.habit?.id == habit.id }) else { break }
            if completion.completed { streak += 1 } else { break }
        }
        return streak
    }
}
