import Testing
import Foundation
import SwiftData
@testable import Blop

@Suite("Collection")
struct CollectionTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: BulletEntry.self, DailyLog.self, MonthlyLog.self,
                HabitDefinition.self, HabitCompletion.self, Collection.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("Collection initialises with correct properties")
    func initProperties() {
        let col = Collection(title: "Reading List", symbol: "book", sortOrder: 0)
        #expect(col.title == "Reading List")
        #expect(col.symbol == "book")
        #expect(col.sortOrder == 0)
        #expect(col.entries.isEmpty)
    }

    @Test("sortedEntries returns entries ordered by sortOrder ascending")
    func sortedEntries() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let col = Collection(title: "Projects", symbol: "folder", sortOrder: 0)
        context.insert(col)

        let e1 = BulletEntry(content: "First", type: .task, sortOrder: 2)
        e1.collection = col
        context.insert(e1)

        let e2 = BulletEntry(content: "Second", type: .task, sortOrder: 0)
        e2.collection = col
        context.insert(e2)

        let e3 = BulletEntry(content: "Third", type: .task, sortOrder: 1)
        e3.collection = col
        context.insert(e3)

        let sorted = col.sortedEntries
        #expect(sorted.count == 3)
        #expect(sorted[0].content == "Second")
        #expect(sorted[1].content == "Third")
        #expect(sorted[2].content == "First")
    }
}
