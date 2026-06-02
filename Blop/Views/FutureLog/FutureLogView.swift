import SwiftUI
import SwiftData

struct FutureLogView: View {
    @Environment(\.modelContext) private var context
    @State private var months: [FutureMonth] = []
    @State private var newEntryText = ""
    @State private var newEntryType: EntryType = .task
    @State private var newEntrySignifier: EntrySignifier? = nil
    @State private var newEventDate = Date()
    @State private var selectedMonthIndex = 0
    @State private var expandedEntryID: UUID? = nil

    @AppStorage("migrationThreshold") private var threshold: Int = 3

    var body: some View {
        ZStack(alignment: .bottom) {
            BlopColor.background.ignoresSafeArea()
            DotGridBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().background(BlopColor.faint)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(months) { month in
                                monthSection(month, proxy: proxy)
                            }
                            Color.clear.frame(height: 120)
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .goToFutureLog)) { _ in
                        if let first = months.first {
                            proxy.scrollTo(first.id, anchor: .top)
                        }
                    }
                }

                futureRapidEntryBar
            }
        }
        .onAppear { loadMonths() }
        .onDisappear { newEntryType = .task }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer()
            Text("FUTURE LOG")
                .font(BlopFont.mono(13, weight: .medium))
                .foregroundStyle(BlopColor.accent)
            Spacer()
        }
        .padding(.horizontal, BlopSpacing.md)
        .padding(.vertical, BlopSpacing.sm)
    }

    // MARK: - Month Section

    @ViewBuilder
    private func monthSection(_ month: FutureMonth, proxy: ScrollViewProxy) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if let idx = months.firstIndex(where: { $0.id == month.id }) {
                    months[idx].isExpanded.toggle()
                }
            }
        } label: {
            HStack {
                Text(month.title)
                    .font(BlopFont.dateHeader)
                    .foregroundStyle(BlopColor.ink)
                Spacer()
                Image(systemName: month.isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(BlopColor.accent)
            }
            .padding(.horizontal, BlopSpacing.md)
            .padding(.vertical, BlopSpacing.sm)
        }
        .buttonStyle(.plain)
        .id(month.id)

        Divider().background(BlopColor.faint)

        if month.isExpanded, let log = month.log {
            let tasks = log.sortedTasks
            let events = log.sortedEvents

            if tasks.isEmpty && events.isEmpty {
                Text("Nothing planned")
                    .font(BlopFont.body(14))
                    .foregroundStyle(BlopColor.faint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BlopSpacing.md)
            } else {
                if !tasks.isEmpty {
                    sectionLabel("TASKS")
                    ForEach(tasks) { task in
                        EntryRowView(
                            entry: task,
                            threshold: threshold,
                            onToggleComplete: { task.status = task.status == .complete ? .open : .complete },
                            onCancel: { task.status = .cancelled },
                            onSetSignifier: { task.signifier = $0 },
                            onSchedule: { _ in },
                            onDelete: { context.delete(task) },
                            expandedEntryID: $expandedEntryID
                        )
                        .padding(.horizontal, BlopSpacing.md)
                        Divider().background(BlopColor.faint).padding(.leading, BlopSpacing.md + 40)
                    }
                }
                if !events.isEmpty {
                    sectionLabel("EVENTS")
                    ForEach(events) { event in
                        EntryRowView(
                            entry: event,
                            threshold: threshold,
                            onToggleComplete: { event.status = event.status == .complete ? .open : .complete },
                            onCancel: { event.status = .cancelled },
                            onSetSignifier: { event.signifier = $0 },
                            onSchedule: { _ in },
                            onDelete: { context.delete(event) },
                            expandedEntryID: $expandedEntryID
                        )
                        .padding(.horizontal, BlopSpacing.md)
                        Divider().background(BlopColor.faint).padding(.leading, BlopSpacing.md + 40)
                    }
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(BlopFont.sectionHeader)
            .foregroundStyle(BlopColor.accent)
            .padding(.horizontal, BlopSpacing.md)
            .padding(.top, BlopSpacing.sm)
            .padding(.bottom, BlopSpacing.xs)
    }

    // MARK: - Future Rapid Entry Bar

    private var futureRapidEntryBar: some View {
        VStack(spacing: 0) {
            Divider().background(BlopColor.faint)

            // Month picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BlopSpacing.xs) {
                    ForEach(months.indices, id: \.self) { idx in
                        Button {
                            selectedMonthIndex = idx
                        } label: {
                            Text(months[idx].shortTitle)
                                .font(BlopFont.mono(12))
                                .foregroundStyle(selectedMonthIndex == idx ? BlopColor.background : BlopColor.ink)
                                .padding(.horizontal, BlopSpacing.sm)
                                .padding(.vertical, BlopSpacing.xs)
                                .background(selectedMonthIndex == idx ? BlopColor.accent : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, BlopSpacing.md)
                .padding(.vertical, BlopSpacing.xs)
            }
            .background(BlopColor.background)

            RapidEntryBar(
                text: $newEntryText,
                selectedType: $newEntryType,
                signifier: $newEntrySignifier,
                eventDate: $newEventDate,
                onSubmit: addEntry
            )
        }
    }

    // MARK: - Data

    private func loadMonths() {
        let cal = Calendar.current
        let now = Date()
        months = (1...6).compactMap { offset -> FutureMonth? in
            guard let date = cal.date(byAdding: .month, value: offset, to: now) else { return nil }
            let year  = cal.component(.year, from: date)
            let month = cal.component(.month, from: date)
            let vm    = MonthlyLogViewModel()
            let existing = vm.fetchExisting(year: year, month: month, context: context)
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            let shortFmt = DateFormatter()
            shortFmt.dateFormat = "MMM"
            let title = formatter.string(from: date)
            let shortTitle = shortFmt.string(from: date)
            return FutureMonth(year: year, month: month, title: title, shortTitle: shortTitle, log: existing)
        }
    }

    private func addEntry(text: String, type: EntryType, signifier: EntrySignifier?, date: Date?) {
        let target = months.indices.contains(selectedMonthIndex) ? months[selectedMonthIndex] : nil
        guard let target else { return }

        let vm  = MonthlyLogViewModel()
        let log = vm.fetchOrCreate(year: target.year, month: target.month, context: context)

        let scheduledDate: Date? = type == .event ? (date ?? Calendar.current.date(from: DateComponents(year: target.year, month: target.month, day: 1))) : nil
        let entry = BulletEntry(content: text, type: type, sortOrder: log.entries.count, scheduledDate: scheduledDate)
        entry.signifier = signifier
        entry.monthlyLog = log
        context.insert(entry)

        // Refresh the affected month's log reference
        if let idx = months.firstIndex(where: { $0.year == target.year && $0.month == target.month }) {
            months[idx].log = log
        }
        newEventDate = Date()
    }
}

// MARK: - Supporting Types

private struct FutureMonth: Identifiable {
    let id = UUID()
    let year: Int
    let month: Int
    let title: String
    let shortTitle: String
    var log: MonthlyLog?
    var isExpanded = true
}

// MARK: - MonthlyLogViewModel extension

extension MonthlyLogViewModel {
    func fetchExisting(year: Int, month: Int, context: ModelContext) -> MonthlyLog? {
        let descriptor = FetchDescriptor<MonthlyLog>(
            predicate: #Predicate { $0.year == year && $0.month == month }
        )
        return try? context.fetch(descriptor).first
    }
}
