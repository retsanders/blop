import SwiftUI

struct EntryRowView: View {
    let entry: BulletEntry
    let threshold: Int
    let onToggleComplete: () -> Void
    let onCancel: () -> Void
    let onRestore: () -> Void
    let onSetSignifier: (EntrySignifier?) -> Void
    let onSchedule: (Date) -> Void
    let onDelete: () -> Void

    @Binding var expandedEntryID: UUID?

    @State private var isEditing = false
    @State private var editText = ""
    @State private var celebrating = false
    @State private var showSchedulePicker = false
    @State private var toastLabel: String? = nil
    @FocusState private var isEditFocused: Bool

    private var isExpanded: Bool { expandedEntryID == entry.id }

    init(
        entry: BulletEntry,
        threshold: Int,
        onToggleComplete: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onRestore: @escaping () -> Void = {},
        onSetSignifier: @escaping (EntrySignifier?) -> Void,
        onSchedule: @escaping (Date) -> Void = { _ in },
        onDelete: @escaping () -> Void,
        expandedEntryID: Binding<UUID?>
    ) {
        self.entry = entry
        self.threshold = threshold
        self.onToggleComplete = onToggleComplete
        self.onCancel = onCancel
        self.onRestore = onRestore
        self.onSetSignifier = onSetSignifier
        self.onSchedule = onSchedule
        self.onDelete = onDelete
        self._expandedEntryID = expandedEntryID
    }

    private var contentColor: Color {
        if entry.status == .cancelled { return BlopColor.ink.opacity(0.45) }
        switch entry.signifier {
        case .priority:    return BlopColor.warning
        case .inspiration: return BlopColor.accent
        case .explore, nil: return BlopColor.ink
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainRow
                .zIndex(1)

            if isExpanded {
                actionPanel
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
                    .zIndex(0)
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            if !expanded { isEditing = false; isEditFocused = false }
        }
        .sheet(isPresented: $showSchedulePicker) {
            MonthPickerSheet { date in
                onSchedule(date)
                showSchedulePicker = false
                collapse()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onCancel) {
                Label("Cancel", systemImage: "xmark")
            }
            .tint(BlopColor.faint)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if entry.type != .event && entry.status != .cancelled {
                Button(action: triggerComplete) {
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

    // MARK: - Main Row

    private var mainRow: some View {
        HStack(alignment: .center, spacing: 0) {
            LeftAnnotation(entry: entry, threshold: threshold)
            SignifierView(entry: entry, threshold: threshold)

            if isEditing {
                TextField("", text: $editText)
                    .font(BlopFont.body())
                    .foregroundStyle(contentColor)
                    .focused($isEditFocused)
                    .submitLabel(.done)
                    .onSubmit { saveEdit(); collapse() }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, BlopSpacing.sm)
            } else {
                Text(entry.content)
                    .font(BlopFont.body())
                    .foregroundStyle(contentColor)
                    .strikethrough(entry.status == .cancelled, color: BlopColor.ink.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, BlopSpacing.sm)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedEntryID = isExpanded ? nil : entry.id
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isExpanded ? BlopColor.accent : BlopColor.ink.opacity(0.35))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, BlopSpacing.xs)
        .scaleEffect(celebrating ? 1.04 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: celebrating)
        .overlay(alignment: .top) {
            if let label = toastLabel {
                Text(label)
                    .font(BlopFont.mono(11))
                    .foregroundStyle(BlopColor.background)
                    .padding(.horizontal, BlopSpacing.sm)
                    .padding(.vertical, BlopSpacing.xs)
                    .background(BlopColor.ink.opacity(0.75))
                    .clipShape(Capsule())
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toastLabel)
    }

    private func collapse() {
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedEntryID = nil
        }
    }

    private func triggerComplete() {
        if entry.status == .open {
            celebrating = true
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                celebrating = false
            }
        }
        onToggleComplete()
    }

    private func startEditing() {
        editText = entry.content
        isEditing = true
        isEditFocused = true
    }

    private func saveEdit() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { entry.content = trimmed }
        isEditing = false
        isEditFocused = false
    }

    private func showToast(_ label: String) {
        toastLabel = label
        Task {
            try? await Task.sleep(for: .milliseconds(1500))
            toastLabel = nil
        }
    }

    // MARK: - Action Panel

    private var actionPanel: some View {
        mainActionRow
            .frame(maxWidth: .infinity)
            .background(BlopColor.surface)
    }

    private var mainActionRow: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(Array(panelActions.enumerated()), id: \.offset) { index, item in
                Button {
                    item.action()
                    if item.collapseAfter { collapse() }
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
    }

    private var panelActions: [PanelAction] {
        var items: [PanelAction] = []

        if entry.type == .task && entry.status != .cancelled {
            items.append(PanelAction(
                label: entry.status == .complete ? "Reopen" : "Complete",
                icon: "checkmark.circle",
                action: triggerComplete
            ))
        }

        if entry.type == .task && entry.status == .open {
            items.append(PanelAction(
                label: "Schedule",
                icon: "calendar",
                collapseAfter: false,
                action: { showSchedulePicker = true }
            ))
        }

        if entry.type != .event && entry.status != .cancelled {
            let next = nextSignifier(after: entry.signifier)
            let sigLabel = entry.signifier?.label ?? "Signifier"
            let sigIcon  = entry.signifier?.icon  ?? "star"
            items.append(PanelAction(
                label: sigLabel,
                icon: sigIcon,
                collapseAfter: false,
                action: {
                    onSetSignifier(next)
                    showToast(next?.label ?? "No Signifier")
                }
            ))
        }

        if entry.type != .event && entry.status != .cancelled {
            items.append(PanelAction(
                label: isEditing ? "Done" : "Edit",
                icon: isEditing ? "checkmark" : "pencil",
                collapseAfter: isEditing,
                action: { if isEditing { saveEdit() } else { startEditing() } }
            ))
        }

        // Type cycle
        if entry.status != .cancelled {
            let nextType = nextEntryType(after: entry.type)
            items.append(PanelAction(
                label: entry.type.label,
                icon: entry.type.icon,
                collapseAfter: false,
                action: { entry.type = nextType }
            ))
        }

        if entry.status == .cancelled {
            items.append(PanelAction(label: "Restore", icon: "arrow.uturn.backward", action: onRestore))
        } else {
            items.append(PanelAction(label: "Cancel", icon: "xmark.circle", color: BlopColor.warning, action: onCancel))
        }

        return items
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        switch entry.type {
        case .task:
            if entry.status == .cancelled {
                Button(action: onRestore) {
                    Label("Restore Entry", systemImage: "arrow.uturn.backward")
                }
            } else {
                Button(action: triggerComplete) {
                    Label(entry.status == .complete ? "Reopen" : "Complete", systemImage: "checkmark.circle")
                }
                if entry.status == .open {
                    Button { showSchedulePicker = true } label: {
                        Label("Schedule to Month", systemImage: "calendar")
                    }
                }
                Button { onSetSignifier(nil) } label: {
                    Label("No Signifier", systemImage: "circle")
                }
                Button { onSetSignifier(.priority) } label: {
                    Label("★ Priority", systemImage: "star.fill")
                }
                Button { onSetSignifier(.inspiration) } label: {
                    Label("⚡ Inspiration", systemImage: "bolt.fill")
                }
                Button { onSetSignifier(.explore) } label: {
                    Label("✦ Explore", systemImage: "diamond.fill")
                }
                Button(role: .destructive, action: onCancel) {
                    Label("Cancel Entry", systemImage: "xmark.circle")
                }
            }
        case .event:
            Button(role: .destructive, action: onCancel) {
                Label("Cancel Entry", systemImage: "xmark.circle")
            }
        case .note:
            if entry.status == .cancelled {
                Button(action: onRestore) {
                    Label("Restore Entry", systemImage: "arrow.uturn.backward")
                }
            } else {
                Button(role: .destructive, action: onCancel) {
                    Label("Cancel Entry", systemImage: "xmark.circle")
                }
            }
        }
    }

    private func nextSignifier(after current: EntrySignifier?) -> EntrySignifier? {
        switch current {
        case nil:          return .priority
        case .priority:    return .inspiration
        case .inspiration: return .explore
        case .explore:     return nil
        }
    }

    private func nextEntryType(after current: EntryType) -> EntryType {
        switch current {
        case .task:  return .note
        case .note:  return .event
        case .event: return .task
        }
    }
}

// MARK: - Month Picker Sheet

private struct MonthPickerSheet: View {
    let onPick: (Date) -> Void
    @Environment(\.dismiss) private var dismiss

    private var months: [(date: Date, label: String)] {
        let cal = Calendar.current
        let now = Date()
        return (0..<12).compactMap { offset in
            guard let date = cal.date(byAdding: .month, value: offset, to: cal.startOfMonth(for: now)) else { return nil }
            let label = date.formatted(.dateTime.month(.wide).year())
            return (date: date, label: label)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BlopColor.background.ignoresSafeArea()
                List(months, id: \.date) { item in
                    Button {
                        onPick(item.date)
                    } label: {
                        Text(item.label)
                            .font(BlopFont.body(16))
                            .foregroundStyle(BlopColor.ink)
                    }
                    .listRowBackground(BlopColor.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Schedule To")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(BlopColor.accent)
                }
            }
        }
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}

// MARK: - Panel Action Model

private struct PanelAction {
    let label: String
    let icon: String
    var color: Color = BlopColor.ink
    var collapseAfter: Bool = true
    let action: () -> Void
}

// MARK: - Left Annotation

private struct LeftAnnotation: View {
    let entry: BulletEntry
    let threshold: Int
    @State private var showSignifier = true

    private var hasMigrationCount: Bool { entry.migrationCount > 0 }
    private var showAlternating: Bool { entry.signifier != nil && hasMigrationCount }

    private var signifierChar: String { entry.signifier?.character ?? "" }
    private var signifierColor: Color {
        switch entry.signifier {
        case .priority:    return BlopColor.warning
        case .inspiration: return BlopColor.accent
        case .explore:     return BlopColor.ink
        case nil:          return BlopColor.faint
        }
    }

    var body: some View {
        Group {
            if showAlternating {
                Group {
                    if showSignifier {
                        Text(signifierChar)
                            .font(BlopFont.mono(14, weight: .medium))
                    } else {
                        Text("\(entry.migrationCount)")
                            .font(BlopFont.mono(14, weight: .medium))
                    }
                }
                .foregroundStyle(signifierColor)
            } else if entry.signifier != nil {
                Text(signifierChar)
                    .font(BlopFont.mono(14, weight: .medium))
                    .foregroundStyle(signifierColor)
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
                withAnimation(.easeInOut(duration: 0.3)) { showSignifier.toggle() }
            }
        }
    }
}
