import Foundation
import SwiftData

@Model
final class HabitCompletion {
    var date: Date
    var completed: Bool
    var habit: HabitDefinition?
    var dailyLog: DailyLog?

    init(habit: HabitDefinition, date: Date, completed: Bool = false) {
        self.habit = habit
        self.date = Calendar.current.startOfDay(for: date)
        self.completed = completed
    }
}
