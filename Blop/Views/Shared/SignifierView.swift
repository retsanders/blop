import SwiftUI

struct SignifierView: View {
    let entry: BulletEntry
    let threshold: Int

    private var isAtThreshold: Bool {
        entry.migrationCount >= threshold && entry.status == .migrated
    }

    private var character: String {
        switch entry.status {
        case .open, .cancelled:
            switch entry.type {
            case .task:  return "•"
            case .event: return "○"
            case .note:  return "–"
            }
        case .complete:   return "✕"
        case .migrated:   return ">"
        case .scheduled:  return "<"
        }
    }

    private var color: Color {
        switch entry.status {
        case .complete:  return BlopColor.accent
        case .cancelled: return BlopColor.ink.opacity(0.4)
        case .migrated:  return isAtThreshold ? BlopColor.warning : BlopColor.ink
        default:         return BlopColor.ink
        }
    }

    var body: some View {
        Text(character)
            .font(BlopFont.signifier)
            .foregroundStyle(color)
            .frame(width: 20, alignment: .center)
    }
}

struct PriorityMarker: View {
    var body: some View {
        Text("*")
            .font(BlopFont.mono(12, weight: .bold))
            .foregroundStyle(BlopColor.warning)
    }
}
