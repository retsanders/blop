import Foundation
import SwiftData

@Model
final class Collection {
    var id: UUID
    var title: String
    var symbol: String
    var sortOrder: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \BulletEntry.collection)
    var entries: [BulletEntry] = []

    init(title: String, symbol: String, sortOrder: Int) {
        self.id = UUID()
        self.title = title
        self.symbol = symbol
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }

    var sortedEntries: [BulletEntry] {
        entries.sorted { $0.sortOrder < $1.sortOrder }
    }
}
