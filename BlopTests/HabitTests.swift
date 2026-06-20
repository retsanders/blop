import Testing
import Foundation
import SwiftData
@testable import Blop

@Suite("HabitDefinition")
struct HabitDefinitionTests {

    @Test("init stores all supplied values")
    func customInit() {
        let habit = HabitDefinition(
            name: "Meditate",
            symbol: "leaf",
            colorHex: "#FF0000",
            sortOrder: 3
        )
        #expect(habit.name == "Meditate")
        #expect(habit.symbol == "leaf")
        #expect(habit.colorHex == "#FF0000")
        #expect(habit.sortOrder == 3)
    }

    @Test("init applies default symbol, colorHex, and sortOrder")
    func defaultInit() {
        let habit = HabitDefinition(name: "Exercise")
        #expect(habit.symbol == "circle")
        #expect(habit.colorHex == "#5C4A3A")
        #expect(habit.sortOrder == 0)
    }

    @Test("init sets isActive to true by default")
    func defaultIsActive() {
        let habit = HabitDefinition(name: "Read")
        #expect(habit.isActive == true)
    }

    @Test("isActive can be set to false")
    func canDeactivate() {
        let habit = HabitDefinition(name: "Run")
        habit.isActive = false
        #expect(habit.isActive == false)
    }
}

@Suite("HabitCompletion")
struct HabitCompletionTests {

    @Test("init normalises date to start of day")
    func normalisesDate() {
        let habit = HabitDefinition(name: "Read")
        let noon = Calendar.current.date(
            from: DateComponents(year: 2026, month: 5, day: 10, hour: 14, minute: 0))!
        let completion = HabitCompletion(habit: habit, date: noon)
        #expect(completion.date == Calendar.current.startOfDay(for: noon))
    }

    @Test("init defaults completed to false")
    func defaultNotCompleted() {
        let habit = HabitDefinition(name: "Run")
        let completion = HabitCompletion(habit: habit, date: Date())
        #expect(completion.completed == false)
    }

    @Test("init stores explicit completed value")
    func completedTrue() {
        let habit = HabitDefinition(name: "Stretch")
        let completion = HabitCompletion(habit: habit, date: Date(), completed: true)
        #expect(completion.completed == true)
    }

    @Test("init links the habit reference")
    func habitReference() {
        let habit = HabitDefinition(name: "Yoga")
        let completion = HabitCompletion(habit: habit, date: Date())
        #expect(completion.habit?.name == "Yoga")
    }
}
