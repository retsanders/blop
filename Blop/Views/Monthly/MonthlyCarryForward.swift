import SwiftUI

struct MonthlyCarryForward: View {
    let entries: [BulletEntry]
    let threshold: Int
    let currentMonthlyLog: MonthlyLog
    let onMigrate: (BulletEntry) -> Void
    let onDrop: (BulletEntry) -> Void

    @State private var isExpanded = true

    var pendingEntries: [BulletEntry] {
        entries.filter { $0.status == .open }
    }

    var body: some View {
        if pendingEntries.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    HStack {
                        Text("FROM LAST MONTH")
                            .font(BlopFont.sectionHeader)
                            .foregroundStyle(BlopColor.accent)
                        Spacer()
                        Text("\(pendingEntries.count)")
                            .font(BlopFont.mono(11))
                            .foregroundStyle(BlopColor.accent)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(BlopColor.accent)
                    }
                    .padding(.horizontal, BlopSpacing.md)
                    .padding(.vertical, BlopSpacing.sm)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Divider().background(BlopColor.faint)

                    ForEach(pendingEntries) { entry in
                        MonthlyCarryRow(
                            entry: entry,
                            threshold: threshold,
                            onMigrate: { onMigrate(entry) },
                            onDrop: { onDrop(entry) }
                        )
                        Divider()
                            .background(BlopColor.faint)
                            .padding(.leading, BlopSpacing.md)
                    }
                }

                Divider().background(BlopColor.accent.opacity(0.3))
            }
            .background(BlopColor.surface)
        }
    }
}

private struct MonthlyCarryRow: View {
    let entry: BulletEntry
    let threshold: Int
    let onMigrate: () -> Void
    let onDrop: () -> Void

    private var isAtThreshold: Bool { entry.migrationCount >= threshold }

    var body: some View {
        VStack(alignment: .leading, spacing: BlopSpacing.xs) {
            HStack(alignment: .top, spacing: BlopSpacing.sm) {
                SignifierView(entry: entry, threshold: threshold)
                Text(entry.content)
                    .font(BlopFont.body(15))
                    .foregroundStyle(BlopColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if entry.migrationCount > 0 {
                    Text("×\(entry.migrationCount)")
                        .font(BlopFont.mono(10))
                        .foregroundStyle(isAtThreshold ? BlopColor.warning : BlopColor.faint)
                }
            }

            if isAtThreshold {
                Text("Migrated \(entry.migrationCount) times — consider dropping")
                    .font(BlopFont.mono(10))
                    .foregroundStyle(BlopColor.warning)
                    .padding(.leading, 28)
            }

            HStack(spacing: BlopSpacing.md) {
                Spacer()
                CarryActionButton(label: ">", hint: "Migrate", color: BlopColor.ink, action: onMigrate)
                CarryActionButton(label: "✕", hint: "Drop", color: BlopColor.faint, action: onDrop)
            }
            .padding(.leading, 28)
        }
        .padding(.horizontal, BlopSpacing.md)
        .padding(.vertical, BlopSpacing.sm)
    }
}

private struct CarryActionButton: View {
    let label: String
    let hint: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(BlopFont.signifier)
                    .foregroundStyle(color)
                Text(hint)
                    .font(BlopFont.mono(9))
                    .foregroundStyle(color.opacity(0.7))
            }
        }
        .buttonStyle(.plain)
    }
}
