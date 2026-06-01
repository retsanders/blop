import SwiftUI
import SwiftData

// MARK: - Management List

struct CollectionsManagementView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Collection.sortOrder) private var collections: [Collection]
    @State private var showAddSheet = false
    @State private var editingCollection: Collection?

    var body: some View {
        ZStack {
            BlopColor.background.ignoresSafeArea()

            List {
                ForEach(collections) { collection in
                    NavigationLink(destination: CollectionDetailView(collection: collection)) {
                        CollectionRow(collection: collection)
                    }
                    .listRowBackground(BlopColor.surface)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { context.delete(collection) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button { editingCollection = collection } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(BlopColor.accent)
                    }
                }
                .onMove(perform: reorder)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Collections")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus").foregroundStyle(BlopColor.accent)
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton().foregroundStyle(BlopColor.accent)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            CollectionEditSheet(collection: nil) { title, symbol in
                let c = Collection(title: title, symbol: symbol, sortOrder: collections.count)
                context.insert(c)
            }
        }
        .sheet(item: $editingCollection) { c in
            CollectionEditSheet(collection: c) { title, symbol in
                c.title = title
                c.symbol = symbol
            }
        }
    }

    private func reorder(from: IndexSet, to: Int) {
        var ordered = collections
        ordered.move(fromOffsets: from, toOffset: to)
        for (i, c) in ordered.enumerated() { c.sortOrder = i }
    }
}

private struct CollectionRow: View {
    let collection: Collection

    var body: some View {
        HStack(spacing: BlopSpacing.md) {
            ZStack {
                Circle()
                    .fill(BlopColor.accent.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: collection.symbol)
                    .font(.system(size: 16))
                    .foregroundStyle(BlopColor.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(collection.title)
                    .font(BlopFont.body(16))
                    .foregroundStyle(BlopColor.ink)
                Text("\(collection.entries.count) items")
                    .font(BlopFont.mono(10))
                    .foregroundStyle(BlopColor.faint)
            }
            Spacer()
        }
        .padding(.vertical, BlopSpacing.xs)
    }
}

// MARK: - Edit Sheet

private struct CollectionEditSheet: View {
    let collection: Collection?
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var symbol: String

    private let presetSymbols = [
        "book.fill", "list.bullet", "heart.fill", "star.fill", "bookmark.fill",
        "folder.fill", "tag.fill", "pencil", "lightbulb.fill", "music.note",
        "figure.run", "cart.fill", "film.fill", "map.fill", "camera.fill"
    ]

    init(collection: Collection?, onSave: @escaping (String, String) -> Void) {
        self.collection = collection
        self.onSave = onSave
        _title  = State(initialValue: collection?.title  ?? "")
        _symbol = State(initialValue: collection?.symbol ?? "list.bullet")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BlopColor.background.ignoresSafeArea()
                Form {
                    Section {
                        TextField("Collection name", text: $title)
                            .font(BlopFont.body(16))
                    } header: {
                        Text("NAME").font(BlopFont.sectionHeader)
                    }

                    Section {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: BlopSpacing.md) {
                            ForEach(presetSymbols, id: \.self) { sym in
                                Button { symbol = sym } label: {
                                    Image(systemName: sym)
                                        .font(.system(size: 20))
                                        .foregroundStyle(symbol == sym ? BlopColor.accent : BlopColor.faint)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(symbol == sym ? BlopColor.accent.opacity(0.15) : Color.clear)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, BlopSpacing.xs)
                    } header: {
                        Text("ICON").font(BlopFont.sectionHeader)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(collection == nil ? "New Collection" : "Edit Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(BlopColor.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = title.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed, symbol)
                        dismiss()
                    }
                    .foregroundStyle(title.trimmingCharacters(in: .whitespaces).isEmpty ? BlopColor.faint : BlopColor.accent)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Detail View

struct CollectionDetailView: View {
    @Environment(\.modelContext) private var context
    let collection: Collection

    @State private var newEntryText = ""
    @State private var newEntryType: EntryType = .task
    @State private var newEntrySignifier: EntrySignifier? = nil
    @State private var newEventDate = Date()
    @State private var expandedEntryID: UUID? = nil

    @AppStorage("migrationThreshold") private var threshold: Int = 3

    var body: some View {
        ZStack(alignment: .bottom) {
            BlopColor.background.ignoresSafeArea()
            DotGridBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        let entries = collection.sortedEntries
                        if entries.isEmpty {
                            Text("Add your first item")
                                .font(BlopFont.body(14))
                                .foregroundStyle(BlopColor.faint)
                                .frame(maxWidth: .infinity)
                                .padding(.top, BlopSpacing.xl)
                        } else {
                            ForEach(entries) { entry in
                                EntryRowView(
                                    entry: entry,
                                    threshold: threshold,
                                    onToggleComplete: { entry.status = entry.status == .complete ? .open : .complete },
                                    onCancel: { entry.status = .cancelled },
                                    onSetSignifier: { entry.signifier = $0 },
                                    onSchedule: { _ in },
                                    onDelete: { context.delete(entry) },
                                    expandedEntryID: $expandedEntryID
                                )
                                .padding(.horizontal, BlopSpacing.md)
                                Divider().background(BlopColor.faint).padding(.leading, BlopSpacing.md + 40)
                            }
                        }
                        Color.clear.frame(height: 120)
                    }
                }

                RapidEntryBar(
                    text: $newEntryText,
                    selectedType: $newEntryType,
                    signifier: $newEntrySignifier,
                    eventDate: $newEventDate,
                    onSubmit: addEntry
                )
            }
        }
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { newEntryType = .task }
    }

    private func addEntry(text: String, type: EntryType, signifier: EntrySignifier?, date: Date?) {
        guard type != .event else { return }
        let entry = BulletEntry(content: text, type: type, sortOrder: collection.entries.count)
        entry.signifier = signifier
        entry.collection = collection
        context.insert(entry)
    }
}
