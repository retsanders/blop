import Foundation
import SwiftData

@Model
final class HabitDefinition {
    var id: UUID
    var name: String
    var symbol: String
    var colorHex: String
    var startDate: Date
    var isActive: Bool
    var sortOrder: Int

    init(name: String, symbol: String = "circle", colorHex: String = "#5C4A3A", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.symbol = symbol
        self.colorHex = colorHex
        self.startDate = Date()
        self.isActive = true
        self.sortOrder = sortOrder
    }
}
