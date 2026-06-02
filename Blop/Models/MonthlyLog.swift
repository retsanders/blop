import Foundation
import SwiftData

@Model
final class MonthlyLog {
    var year: Int
    var month: Int
    @Relationship(deleteRule: .cascade, inverse: \BulletEntry.monthlyLog)
    var entries: [BulletEntry]

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
        self.entries = []
    }

    var sortedTasks: [BulletEntry] {
        entries.filter { $0.type == .task || $0.type == .note }
               .sorted { $0.sortOrder < $1.sortOrder }
    }

    var sortedEvents: [BulletEntry] {
        entries.filter { entry in
            guard entry.type == .event else { return false }
            let date = entry.scheduledDate ?? entry.createdAt
            let cal = Calendar.current
            return cal.component(.year, from: date) == year
                && cal.component(.month, from: date) == month
        }
        .sorted { ($0.scheduledDate ?? $0.createdAt) < ($1.scheduledDate ?? $1.createdAt) }
    }

    var displayTitle: String {
        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = Calendar.current.date(from: components) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
