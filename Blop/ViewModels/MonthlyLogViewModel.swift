import Foundation
import SwiftData

@Observable
final class MonthlyLogViewModel {
    var selectedYear: Int
    var selectedMonth: Int

    init() {
        let now = Date()
        selectedYear = Calendar.current.component(.year, from: now)
        selectedMonth = Calendar.current.component(.month, from: now)
    }

    var previousMonthComponents: (year: Int, month: Int) {
        var components = DateComponents(year: selectedYear, month: selectedMonth - 1)
        if components.month! < 1 {
            components.month = 12
            components.year = selectedYear - 1
        }
        return (components.year!, components.month!)
    }

    func fetchOrCreateLog(context: ModelContext) -> MonthlyLog {
        fetchOrCreate(year: selectedYear, month: selectedMonth, context: context)
    }

    func fetchOrCreate(year: Int, month: Int, context: ModelContext) -> MonthlyLog {
        let descriptor = FetchDescriptor<MonthlyLog>(
            predicate: #Predicate { $0.year == year && $0.month == month }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let log = MonthlyLog(year: year, month: month)
        context.insert(log)
        return log
    }

    func carryForwardTasks(from context: ModelContext) -> [BulletEntry] {
        let (py, pm) = previousMonthComponents
        let startOfPrevMonth = Calendar.current.date(from: DateComponents(year: py, month: pm, day: 1))!
        let endOfPrevMonth = Calendar.current.date(byAdding: .month, value: 1, to: startOfPrevMonth)!

        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date >= startOfPrevMonth && $0.date < endOfPrevMonth }
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        return logs.flatMap { $0.entries }.filter { $0.type == .task && $0.status == .open }
    }

    func addTask(content: String, to log: MonthlyLog, context: ModelContext) {
        let entry = BulletEntry(content: content, type: .task, sortOrder: log.entries.count)
        entry.monthlyLog = log
        context.insert(entry)
    }

    func addEvent(content: String, scheduledDate: Date? = nil, to log: MonthlyLog, context: ModelContext) {
        let entry = BulletEntry(content: content, type: .event, sortOrder: log.entries.count, scheduledDate: scheduledDate)
        entry.monthlyLog = log
        context.insert(entry)
    }
}
