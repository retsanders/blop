import Foundation
import SwiftData

@Observable
final class DailyLogViewModel {
    var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    var previousDate: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
    }

    var nextDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    func goToPreviousDay() {
        selectedDate = previousDate
    }

    func goToNextDay() {
        selectedDate = nextDate
    }

    func goToToday() {
        selectedDate = Calendar.current.startOfDay(for: Date())
    }

    func fetchOrCreateLog(for date: Date, context: ModelContext) -> DailyLog {
        let start = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date == start }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let log = DailyLog(date: start)
        context.insert(log)
        return log
    }

    func fetchLog(for date: Date, context: ModelContext) -> DailyLog? {
        let start = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date == start }
        )
        return try? context.fetch(descriptor).first
    }

    func addEntry(content: String, type: EntryType, signifier: EntrySignifier? = nil, scheduledDate: Date? = nil, to log: DailyLog, context: ModelContext) {
        let order = log.entries.count
        let entry = BulletEntry(content: content, type: type, sortOrder: order, scheduledDate: scheduledDate)
        entry.signifier = signifier
        entry.dailyLog = log
        context.insert(entry)
    }

    func toggleComplete(_ entry: BulletEntry) {
        entry.status = entry.status == .complete ? .open : .complete
    }

    func cancel(_ entry: BulletEntry) {
        entry.status = .cancelled
    }

    func migrate(_ entry: BulletEntry, to log: DailyLog, context: ModelContext) {
        let copy = entry.migratedForward(into: log)
        context.insert(copy)
        entry.status = .migrated
    }

    func schedule(_ entry: BulletEntry, monthlyLog: MonthlyLog, context: ModelContext) {
        let scheduled = BulletEntry(
            content: entry.content,
            type: entry.type,
            sortOrder: monthlyLog.entries.count,
            migratedFrom: entry.migratedFrom ?? entry.createdAt,
            migrationCount: entry.migrationCount
        )
        scheduled.isPriority = entry.isPriority
        scheduled.monthlyLog = monthlyLog
        context.insert(scheduled)
        entry.status = .scheduled
    }

    func drop(_ entry: BulletEntry) {
        entry.status = .cancelled
    }

    func ensureHabitCompletions(for log: DailyLog, habits: [HabitDefinition], context: ModelContext) {
        let existingHabitIDs = Set(log.habitCompletions.compactMap { $0.habit?.id })
        for habit in habits where habit.isActive && !existingHabitIDs.contains(habit.id) {
            let completion = HabitCompletion(habit: habit, date: log.date)
            completion.dailyLog = log
            context.insert(completion)
        }
    }
}
