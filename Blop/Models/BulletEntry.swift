import Foundation
import SwiftData

enum EntryType: String, Codable, CaseIterable {
    case task   // •
    case event  // ○
    case note   // –
}

enum EntryStatus: String, Codable {
    case open
    case complete   // ✕
    case migrated   // >
    case scheduled  // < (moved to monthly log)
    case cancelled  // struck through
}

enum EntrySignifier: String, Codable, CaseIterable {
    case priority    // ★
    case inspiration // !
    case explore     // ✦

    var character: String {
        switch self {
        case .priority:    return "★"
        case .inspiration: return "⚡"
        case .explore:     return "✦"
        }
    }

    var label: String {
        switch self {
        case .priority:    return "Priority"
        case .inspiration: return "Inspiration"
        case .explore:     return "Explore"
        }
    }

    var icon: String {
        switch self {
        case .priority:    return "star.fill"
        case .inspiration: return "bolt.fill"
        case .explore:     return "diamond.fill"
        }
    }
}

@Model
final class BulletEntry {
    var id: UUID
    var content: String
    var type: EntryType
    var status: EntryStatus
    var isPriority: Bool        // kept in schema for data compatibility; use signifier in UI
    var signifier: EntrySignifier?
    var sortOrder: Int
    var migrationCount: Int
    var migratedFrom: Date?
    var createdAt: Date
    var scheduledDate: Date?

    var dailyLog: DailyLog?
    var monthlyLog: MonthlyLog?
    var collection: Collection?

    init(
        content: String,
        type: EntryType = .task,
        sortOrder: Int = 0,
        migratedFrom: Date? = nil,
        migrationCount: Int = 0,
        scheduledDate: Date? = nil
    ) {
        self.id = UUID()
        self.content = content
        self.type = type
        self.status = .open
        self.isPriority = false
        self.signifier = nil
        self.sortOrder = sortOrder
        self.migrationCount = migrationCount
        self.migratedFrom = migratedFrom
        self.createdAt = Date()
        self.scheduledDate = scheduledDate
    }

    func bulletCharacter(atThreshold threshold: Int) -> String {
        switch status {
        case .open:
            return type == .task ? "•" : type == .event ? "○" : "–"
        case .complete:
            return "✕"
        case .migrated:
            return migrationCount >= threshold ? "⚠" : ">"
        case .scheduled:
            return "<"
        case .cancelled:
            return "–"
        }
    }

    func migratedForward(into log: DailyLog) -> BulletEntry {
        let copy = BulletEntry(
            content: content,
            type: type,
            sortOrder: 0,
            migratedFrom: migratedFrom ?? createdAt,
            migrationCount: migrationCount + 1
        )
        copy.signifier = signifier
        copy.isPriority = isPriority
        copy.dailyLog = log
        return copy
    }
}
