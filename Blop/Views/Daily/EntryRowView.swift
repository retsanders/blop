import SwiftUI
import SwiftData

// MARK: - Schedule Destination

enum ScheduleDestination {
    case month(Date)
    case collection(Collection)
}

// MARK: - Entry Row

struct EntryRowView: View {
    let entry: BulletEntry
    let threshold: Int
    let onToggleComplete: () -> Void
    let onCancel: () -> Void
    let onRestore: () -> Void
    let onSetSignifier: (EntrySignifier?) -> Void
    let onSchedule: (ScheduleDestination) -> Void
    let onDelete: () -> Void

    @Binding var expandedEntryID: UUID?

    @State private var isEditing = false
    @State private var editText = ""
    @State private var celebrating = false
    @State private var showSchedulePicker = false
    @FocusState private var isEditFocused: Bool

    private var isExpanded: Bool { expandedEntryID == entry.id }

    init(
        entry: BulletEntry,
        threshold: Int,
        onToggleComplete: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onRestore: @escaping () -> Void = {},
        onSetSignifier: @escaping (EntrySignifier?) -> Void,
        onSchedule: @escaping (ScheduleDestination) -> Void = { _ in },
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
        if entry.status == .cancelled { return BlopColor.ink.opacity(0.40) }
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
            DestinationPickerSheet { destination in
                onSchedule(destination)
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
                    .strikethrough(entry.status == .cancelled, color: BlopColor.ink.opacity(0.4))
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
                    .foregroundStyle(isExpanded ? BlopColor.accent : BlopColor.ink.opacity(0.4))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, BlopSpacing.xs)
        .scaleEffect(celebrating ? 1.04 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: celebrating)
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

    private func postSignifierToast(_ label: String) {
        NotificationCenter.default.post(name: .signifierToast, object: label)
    }

    // MARK: - Action Panel

    private var actionPanel: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(Array(panelActions.enumerated()), id: \.offset) { index, item in
                Button {
                    item.action()
                    if item.collapseAfter { collapse() }
                } label: {
                    VStack(spacing: 2) {
                        Text(item.symbol)
                            .font(BlopFont.signifier)
                            .strikethrough(item.strikethrough, color: item.color)
                        Text(item.label)
                            .font(BlopFont.mono(9))
                    }
                    .foregroundStyle(item.color)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < panelActions.count - 1 {
                    Divider()
                        .frame(height: 24)
                        .background(BlopColor.faint)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(BlopColor.surface)
    }

    private var panelActions: [PanelAction] {
        var items: [PanelAction] = []

        if entry.type == .task && entry.status != .cancelled {
            let isComplete = entry.status == .complete
            items.append(PanelAction(
                symbol: isComplete ? "↩" : "✕",
                label: isComplete ? "Reopen" : "Complete",
                action: triggerComplete
            ))
        }

        if entry.type == .task && entry.status == .open {
            items.append(PanelAction(
                symbol: "<",
                label: "Schedule",
                collapseAfter: false,
                action: { showSchedulePicker = true }
            ))
        }

        if entry.type != .event && entry.status != .cancelled {
            let next = nextSignifier(after: entry.signifier)
            let sigSymbol = entry.signifier?.character ?? "◌"
            let sigLabel = entry.signifier?.label ?? "Signifier"
            items.append(PanelAction(
                symbol: sigSymbol,
                label: sigLabel,
                collapseAfter: false,
                action: {
                    onSetSignifier(next)
                    postSignifierToast(next?.label ?? "No Signifier")
                }
            ))
        }

        if entry.type != .event && entry.status != .cancelled {
            items.append(PanelAction(
                symbol: isEditing ? "✓" : "✎",
                label: isEditing ? "Done" : "Edit",
                collapseAfter: isEditing,
                action: { if isEditing { saveEdit() } else { startEditing() } }
            ))
        }

        if entry.status != .cancelled {
            let nextType = nextEntryType(after: entry.type)
            items.append(PanelAction(
                symbol: entry.type.signifier,
                label: entry.type.label,
                collapseAfter: false,
                action: { entry.type = nextType }
            ))
        }

        if entry.status == .cancelled {
            items.append(PanelAction(symbol: "↩", label: "Restore", action: onRestore))
        } else {
            items.append(PanelAction(
                symbol: "A",
                label: "Cancel",
                color: BlopColor.warning,
                strikethrough: true,
                action: onCancel
            ))
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
                        Label("Schedule", systemImage: "calendar")
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

// MARK: - Destination Picker Sheet

private struct DestinationPickerSheet: View {
    let onPick: (ScheduleDestination) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Collection.sortOrder) private var collections: [Collection]

    private var months: [(date: Date, label: String)] {
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        return (0..<12).compactMap { offset in
            guard let date = cal.date(byAdding: .month, value: offset, to: start) else { return nil }
            return (date: date, label: date.formatted(.dateTime.month(.wide).year()))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BlopColor.background.ignoresSafeArea()
                List {
                    if !collections.isEmpty {
                        Section {
                            ForEach(collections) { coll in
                                Button {
                                    onPick(.collection(coll))
                                } label: {
                                    HStack(spacing: BlopSpacing.md) {
                                        Image(systemName: coll.symbol)
                                            .foregroundStyle(BlopColor.accent)
                                            .frame(width: 20)
                                        Text(coll.title)
                                            .font(BlopFont.body(16))
                                            .foregroundStyle(BlopColor.ink)
                                    }
                                }
                                .listRowBackground(BlopColor.surface)
                            }
                        } header: {
                            Text("COLLECTIONS").font(BlopFont.sectionHeader)
                        }
                    }

                    Section {
                        ForEach(months, id: \.date) { item in
                            Button {
                                onPick(.month(item.date))
                            } label: {
                                Text(item.label)
                                    .font(BlopFont.body(16))
                                    .foregroundStyle(BlopColor.ink)
                            }
                            .listRowBackground(BlopColor.surface)
                        }
                    } header: {
                        Text("MONTHS").font(BlopFont.sectionHeader)
                    }
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

// MARK: - Panel Action Model

private struct PanelAction {
    let symbol: String
    let label: String
    var color: Color = BlopColor.ink
    var strikethrough: Bool = false
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
                        signifierImage
                    } else {
                        migrationText
                    }
                }
            } else if entry.signifier != nil {
                signifierImage
            } else if hasMigrationCount {
                migrationText
            } else {
                Color.clear
            }
        }
        .frame(width: 24, alignment: .center)
        .task(id: showAlternating) {
            guard showAlternating else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeInOut(duration: 0.3)) { showSignifier.toggle() }
            }
        }
    }

    @ViewBuilder
    private var signifierImage: some View {
        if let sig = entry.signifier {
            Image(systemName: sig.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(signifierColor)
        }
    }

    private var migrationText: some View {
        Text("\(entry.migrationCount)")
            .font(BlopFont.mono(10))
            .foregroundStyle(entry.migrationCount >= threshold ? BlopColor.warning : BlopColor.faint)
    }
}
