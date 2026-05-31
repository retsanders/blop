import SwiftUI
import SwiftData

struct HabitManagementView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \HabitDefinition.sortOrder) private var habits: [HabitDefinition]
    @State private var showAddSheet = false
    @State private var editingHabit: HabitDefinition?

    var body: some View {
        ZStack {
            BlopColor.background.ignoresSafeArea()

            List {
                ForEach(habits) { habit in
                    HabitManagementRow(habit: habit)
                        .contentShape(Rectangle())
                        .onTapGesture { editingHabit = habit }
                        .listRowBackground(BlopColor.surface)
                }
                .onMove(perform: reorder)
                .onDelete(perform: delete)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Habits")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(BlopColor.accent)
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
                    .foregroundStyle(BlopColor.accent)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            HabitEditSheet(habit: nil) { name, symbol, colorHex in
                let habit = HabitDefinition(
                    name: name,
                    symbol: symbol,
                    colorHex: colorHex,
                    sortOrder: habits.count
                )
                context.insert(habit)
            }
        }
        .sheet(item: $editingHabit) { habit in
            HabitEditSheet(habit: habit) { name, symbol, colorHex in
                habit.name = name
                habit.symbol = symbol
                habit.colorHex = colorHex
            }
        }
    }

    private func reorder(from: IndexSet, to: Int) {
        var reordered = habits
        reordered.move(fromOffsets: from, toOffset: to)
        for (i, habit) in reordered.enumerated() {
            habit.sortOrder = i
        }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { context.delete(habits[i]) }
    }
}

// MARK: - Row

private struct HabitManagementRow: View {
    let habit: HabitDefinition

    var body: some View {
        HStack(spacing: BlopSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color(hex: habit.colorHex).opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: habit.symbol)
                    .font(.system(size: 17))
                    .foregroundStyle(Color(hex: habit.colorHex))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(BlopFont.body(16))
                    .foregroundStyle(BlopColor.ink)
                if !habit.isActive {
                    Text("Archived")
                        .font(BlopFont.mono(10))
                        .foregroundStyle(BlopColor.faint)
                }
            }

            Spacer()

            Image(systemName: "pencil")
                .font(.system(size: 12))
                .foregroundStyle(BlopColor.faint)
        }
        .padding(.vertical, BlopSpacing.xs)
    }
}

// MARK: - Edit Sheet

struct HabitEditSheet: View {
    let habit: HabitDefinition?
    let onSave: (String, String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var symbol: String
    @State private var colorHex: String

    private let presetSymbols = [
        "figure.run", "drop.fill", "book.fill", "moon.fill", "heart.fill",
        "leaf.fill", "flame.fill", "pencil", "fork.knife", "music.note",
        "dumbbell.fill", "pills.fill", "figure.mind.and.body", "star.fill", "checkmark.circle.fill"
    ]

    private let presetColors = [
        "#E63946", "#F4A261", "#E9C46A", "#2A9D8F", "#48CAE4",
        "#3A86FF", "#8338EC", "#F72585", "#C87941", "#06D6A0"
    ]

    init(habit: HabitDefinition?, onSave: @escaping (String, String, String) -> Void) {
        self.habit = habit
        self.onSave = onSave
        _name = State(initialValue: habit?.name ?? "")
        _symbol = State(initialValue: habit?.symbol ?? "circle")
        _colorHex = State(initialValue: habit?.colorHex ?? "#5C4A3A")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BlopColor.background.ignoresSafeArea()

                Form {
                    Section {
                        TextField("Habit name", text: $name)
                            .font(BlopFont.body(16))
                    } header: {
                        Text("NAME").font(BlopFont.sectionHeader)
                    }

                    Section {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible()), count: 5),
                            spacing: BlopSpacing.md
                        ) {
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

                    Section {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible()), count: 5),
                            spacing: BlopSpacing.md
                        ) {
                            ForEach(presetColors, id: \.self) { hex in
                                Button { colorHex = hex } label: {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Circle().stroke(BlopColor.ink, lineWidth: colorHex == hex ? 2 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, BlopSpacing.xs)
                    } header: {
                        Text("COLOR").font(BlopFont.sectionHeader)
                    }

                    Section {
                        HStack(spacing: BlopSpacing.md) {
                            ZStack {
                                Circle()
                                    .stroke(Color(hex: colorHex), lineWidth: 2)
                                    .frame(width: 44, height: 44)
                                Image(systemName: symbol)
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color(hex: colorHex))
                            }
                            Text(name.isEmpty ? "Habit name" : name)
                                .font(BlopFont.body(16))
                                .foregroundStyle(name.isEmpty ? BlopColor.faint : BlopColor.ink)
                        }
                        .padding(.vertical, BlopSpacing.xs)
                    } header: {
                        Text("PREVIEW").font(BlopFont.sectionHeader)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(habit == nil ? "New Habit" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(BlopColor.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed, symbol, colorHex)
                        dismiss()
                    }
                    .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty ? BlopColor.faint : BlopColor.accent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
