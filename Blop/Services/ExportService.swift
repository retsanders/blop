import Foundation
import SwiftData

final class ExportService {

    func exportDailyLog(_ log: DailyLog) -> String {
        let dateStr = localDateString(from: log.date)
        var lines = ["# \(dateStr)", ""]

        let completions = log.habitCompletions.sorted { ($0.habit?.sortOrder ?? 0) < ($1.habit?.sortOrder ?? 0) }
        if !completions.isEmpty {
            lines += ["## Habits"]
            for c in completions {
                let name = c.habit?.name ?? "Unknown"
                lines.append(c.completed ? "- [x] \(name)" : "- [ ] \(name)")
            }
            lines.append("")
        }

        lines.append("## Log")
        for entry in log.sortedEntries {
            lines.append(formatEntry(entry))
        }

        return lines.joined(separator: "\n")
    }

    func exportMonthlyLog(_ log: MonthlyLog) -> String {
        var lines = ["# \(log.displayTitle)", ""]

        if !log.sortedTasks.isEmpty {
            lines.append("## Tasks")
            for task in log.sortedTasks {
                lines.append(formatEntry(task))
            }
            lines.append("")
        }

        if !log.sortedEvents.isEmpty {
            lines.append("## Events")
            for event in log.sortedEvents {
                lines.append(formatEntry(event))
            }
        }

        return lines.joined(separator: "\n")
    }

    func writeToDirectory(_ url: URL, context: ModelContext) throws {
        guard url.startAccessingSecurityScopedResource() else {
            throw ExportError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let dailyDescriptor = FetchDescriptor<DailyLog>()
        let dailyLogs = try context.fetch(dailyDescriptor)
        for log in dailyLogs {
            let content = exportDailyLog(log)
            let dateStr = localDateString(from: log.date)
            let file = url.appendingPathComponent("\(dateStr).md")
            try content.write(to: file, atomically: true, encoding: .utf8)
        }

        let monthlyDescriptor = FetchDescriptor<MonthlyLog>()
        let monthlyLogs = try context.fetch(monthlyDescriptor)
        for log in monthlyLogs {
            let content = exportMonthlyLog(log)
            let name = String(format: "%04d-%02d", log.year, log.month)
            let file = url.appendingPathComponent("\(name).md")
            try content.write(to: file, atomically: true, encoding: .utf8)
        }
    }

    private func localDateString(from date: Date) -> String {
        let cal = Calendar.current
        return String(format: "%04d-%02d-%02d",
            cal.component(.year, from: date),
            cal.component(.month, from: date),
            cal.component(.day, from: date))
    }

    private func formatEntry(_ entry: BulletEntry) -> String {
        var sigil: String
        switch entry.status {
        case .open:
            sigil = entry.type == .task ? "•" : entry.type == .event ? "○" : "–"
        case .complete:   sigil = "✕"
        case .migrated:   sigil = ">"
        case .scheduled:  sigil = "<"
        case .cancelled:  sigil = "–"
        }
        let priority = entry.isPriority ? " *" : ""
        return "\(sigil) \(entry.content)\(priority)"
    }
}

enum ExportError: LocalizedError {
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .accessDenied: return "Could not access the selected directory."
        }
    }
}
