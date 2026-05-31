import SwiftUI

struct EntryRowView: View {
    let entry: BulletEntry
    let threshold: Int
    let onToggleComplete: () -> Void
    let onCancel: () -> Void
    let onTogglePriority: () -> Void
    let onSchedule: () -> Void
    let onDelete: () -> Void

    @Binding var expandedEntryID: UUID?

    private var isExpanded: Bool { expandedEntryID == entry.id }

    private var contentColor: Color {
        if entry.status == .cancelled { return BlopColor.ink.opacity(0.45) }
        if entry.isPriority { return BlopColor.warning }
        return BlopColor.ink
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                LeftAnnotation(entry: entry, threshold: threshold)
                SignifierView(entry: entry, threshold: threshold)
                Text(entry.content)
                    .font(BlopFont.body())
                    .foregroundStyle(contentColor)
                    .strikethrough(entry.status == .cancelled, color: BlopColor.ink.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, BlopSpacing.sm)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expandedEntryID = isExpanded ? nil : entry.id
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isExpanded ? BlopColor.accent : BlopColor.faint)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, BlopSpacing.xs)

            if isExpanded {
                actionPanel
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onCancel) {
                Label("Cancel", systemImage: "xmark")
            }
            .tint(BlopColor.faint)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if entry.type != .event {
                Button(action: onToggleComplete) {
                    Label(entry.status == .complete ? "Reopen" : "Complete", systemImage: "checkmark")
                }
                .tint(BlopColor.accent)
            }
        }
        .contextMenu {
            contextMenuItems
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func collapse() {
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedEntryID = nil
        }
    }

    // MARK: - Action Panel

    private var actionPanel: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(Array(panelActions.enumerated()), id: \.offset) { index, item in
                Button {
                    item.action()
                    collapse()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 16))
                        Text(item.label)
                            .font(BlopFont.mono(9))
                    }
                    .foregroundStyle(item.color)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < panelActions.count - 1 {
                    Divider()
                        .frame(height: 28)
                        .background(BlopColor.faint)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(BlopColor.surface)
    }

    private var panelActions: [PanelAction] {
        switch entry.type {
        case .task:
            var items: [PanelAction] = [
                PanelAction(
                    label: entry.status == .complete ? "Reopen" : "Complete",
                    icon: "checkmark.circle",
                    action: onToggleComplete
                )
            ]
            if entry.status == .open {
                items.append(PanelAction(label: "Schedule", icon: "calendar", action: onSchedule))
            }
            items.append(PanelAction(
                label: entry.isPriority ? "Unstar" : "Star",
                icon: entry.isPriority ? "star.slash" : "star",
                action: onTogglePriority
            ))
            items.append(PanelAction(label: "Cancel", icon: "xmark.circle", color: BlopColor.warning, action: onCancel))
            return items
        case .event:
            return [
                PanelAction(label: "Cancel", icon: "xmark.circle", color: BlopColor.warning, action: onCancel)
            ]
        case .note:
            return [PanelAction(label: "Cancel", icon: "xmark.circle", color: BlopColor.warning, action: onCancel)]
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        switch entry.type {
        case .task:
            Button(action: onToggleComplete) {
                Label(entry.status == .complete ? "Reopen" : "Complete", systemImage: "checkmark.circle")
            }
            if entry.status == .open {
                Button(action: onSchedule) {
                    Label("Schedule to Month", systemImage: "calendar")
                }
            }
            Button(action: onTogglePriority) {
                Label(entry.isPriority ? "Remove Priority" : "Mark Priority", systemImage: "star")
            }
            Button(role: .destructive, action: onCancel) {
                Label("Cancel Entry", systemImage: "xmark.circle")
            }
        case .event:
            Button(role: .destructive, action: onCancel) {
                Label("Cancel Entry", systemImage: "xmark.circle")
            }
        case .note:
            Button(role: .destructive, action: onCancel) {
                Label("Cancel Entry", systemImage: "xmark.circle")
            }
        }
    }
}

// MARK: - Panel Action Model

private struct PanelAction {
    let label: String
    let icon: String
    var color: Color = BlopColor.ink
    let action: () -> Void
}

// MARK: - Left Annotation

private struct LeftAnnotation: View {
    let entry: BulletEntry
    let threshold: Int
    @State private var showStar = true

    private var hasMigrationCount: Bool { entry.migrationCount > 0 }
    private var showAlternating: Bool { entry.isPriority && hasMigrationCount }

    var body: some View {
        Group {
            if showAlternating {
                Group {
                    if showStar {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9, weight: .medium))
                    } else {
                        Text("\(entry.migrationCount)")
                            .font(BlopFont.mono(11, weight: .medium))
                    }
                }
                .foregroundStyle(BlopColor.warning)
            } else if entry.isPriority {
                Image(systemName: "star.fill")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(BlopColor.warning)
            } else if hasMigrationCount {
                Text("\(entry.migrationCount)")
                    .font(BlopFont.mono(10))
                    .foregroundStyle(entry.migrationCount >= threshold ? BlopColor.warning : BlopColor.faint)
            } else {
                Color.clear
            }
        }
        .frame(width: 20, alignment: .center)
        .task(id: showAlternating) {
            guard showAlternating else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeInOut(duration: 0.3)) { showStar.toggle() }
            }
        }
    }
}
