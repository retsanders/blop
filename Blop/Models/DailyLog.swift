import Foundation
import SwiftData

@Model
final class DailyLog {
    var date: Date
    @Relationship(deleteRule: .cascade, inverse: \BulletEntry.dailyLog)
    var entries: [BulletEntry]
    @Relationship(deleteRule: .cascade, inverse: \HabitCompletion.dailyLog)
    var habitCompletions: [HabitCompletion]

    init(date: Date) {
        self.date = Calendar.current.startOfDay(for: date)
        self.entries = []
        self.habitCompletions = []
    }

    var sortedEntries: [BulletEntry] {
        entries.sorted { $0.sortOrder < $1.sortOrder }
    }

    var openTasks: [BulletEntry] {
        entries.filter { $0.type == .task && $0.status == .open }
    }
}
