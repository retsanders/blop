import SwiftUI
import SwiftData

struct MonthlyLogView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = MonthlyLogViewModel()
    @State private var monthlyLog: MonthlyLog?
    @State private var carryForwardEntries: [BulletEntry] = []
    @State private var showReview = false
    @State private var newEntryText = ""
    @State private var newEntryType: EntryType = .task
    @State private var newEntrySignifier: EntrySignifier? = nil
    @State private var newEventDate = Date()
    @State private var activeDates: Set<Date> = []
    @State private var expandedEntryID: UUID? = nil

    @AppStorage("migrationThreshold") private var threshold: Int = 3

    var body: some View {
        ZStack(alignment: .bottom) {
            BlopColor.background.ignoresSafeArea()
            DotGridBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                monthHeader
                Divider().background(BlopColor.faint)

                // Pinned: day strip
                MonthlyDayStrip(
                    year: viewModel.selectedYear,
                    month: viewModel.selectedMonth,
                    activeDates: activeDates,
                    onSelectDate: { _ in }
                )
                Divider().background(BlopColor.faint)

                ScrollViewReader { proxy in
                    // Pinned: jump buttons + review
                    HStack(alignment: .center, spacing: BlopSpacing.sm) {
                        JumpButton(signifier: "•", label: "Tasks") {
                            withAnimation { proxy.scrollTo("tasks", anchor: .top) }
                        }
                        JumpButton(signifier: "○", label: "Events") {
                            withAnimation { proxy.scrollTo("events", anchor: .top) }
                        }
                        Spacer()
                        JumpButton(icon: "chart.bar", label: "Review") { showReview = true }
                    }
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .bottomLeading)
                    .padding(.horizontal, BlopSpacing.md)
                    .padding(.leading, BlopSpacing.sm)
                    .padding(.trailing, BlopSpacing.sm)
                    Divider().background(BlopColor.faint)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if let log = monthlyLog {
                                MonthlyCarryForward(
                                    entries: carryForwardEntries,
                                    threshold: threshold,
                                    currentMonthlyLog: log,
                                    onMigrate: { migrateToThisMonth($0, log: log) },
                                    onDrop: { $0.status = .cancelled }
                                )

                                // Tasks section
                                sectionHeader("TASKS")
                                    .id("tasks")
                                taskContent(log: log)

                                // Events section
                                sectionHeader("EVENTS")
                                    .id("events")
                                eventContent(log: log)
                            }
                            Color.clear.frame(height: 120)
                        }
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
        .sheet(isPresented: $showReview) {
            MonthlyReviewView()
        }
        .onAppear { load() }
        .onDisappear { newEntryType = .task }
        .onReceive(NotificationCenter.default.publisher(for: .goToCurrentMonth)) { _ in
            let now = Date()
            viewModel.selectedYear = Calendar.current.component(.year, from: now)
            viewModel.selectedMonth = Calendar.current.component(.month, from: now)
            load()
        }
    }

    private var monthHeader: some View {
        HStack {
            Button(action: goToPreviousMonth) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(BlopColor.accent)
            }
            Spacer()
            Text(monthlyLog?.displayTitle ?? "")
                .font(BlopFont.dateHeader)
                .foregroundStyle(BlopColor.ink)
            Spacer()
            Button(action: goToNextMonth) {
                Image(systemName: "chevron.right")
                    .foregroundStyle(BlopColor.accent)
            }
        }
        .padding(.horizontal, BlopSpacing.md)
        .padding(.vertical, BlopSpacing.sm)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(BlopFont.sectionHeader)
            .foregroundStyle(BlopColor.accent)
            .padding(.horizontal, BlopSpacing.md)
            .padding(.top, BlopSpacing.md)
            .padding(.bottom, BlopSpacing.xs)
    }

    @ViewBuilder
    private func taskContent(log: MonthlyLog) -> some View {
        let tasks = log.sortedTasks
        if tasks.isEmpty {
            emptyState(label: "No tasks this month")
        } else {
            ForEach(tasks) { task in
                EntryRowView(
                    entry: task,
                    threshold: threshold,
                    onToggleComplete: { task.status = task.status == .complete ? .open : .complete },
                    onCancel: { task.status = .cancelled },
                    onRestore: { task.status = .open },
                    onSetSignifier: { task.signifier = $0 },
                    onSchedule: { _ in },
                    onDelete: { context.delete(task) },
                    expandedEntryID: $expandedEntryID
                )
                .padding(.horizontal, BlopSpacing.md)
                Divider()
                    .background(BlopColor.faint)
                    .padding(.leading, BlopSpacing.md + 40)
            }
        }
    }

    @ViewBuilder
    private func eventContent(log: MonthlyLog) -> some View {
        let grouped = groupedEvents(log.sortedEvents)
        if grouped.isEmpty {
            emptyState(label: "No events this month")
        } else {
            ForEach(grouped, id: \.date) { group in
                Text(group.date, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(BlopFont.mono(11, weight: .medium))
                    .foregroundStyle(BlopColor.accent)
                    .padding(.horizontal, BlopSpacing.md)
                    .padding(.top, BlopSpacing.md)
                    .padding(.bottom, BlopSpacing.xs)

                ForEach(group.events) { event in
                    EntryRowView(
                        entry: event,
                        threshold: threshold,
                        onToggleComplete: { event.status = event.status == .complete ? .open : .complete },
                        onCancel: { event.status = .cancelled },
                        onRestore: { event.status = .open },
                        onSetSignifier: { event.signifier = $0 },
                        onSchedule: { _ in },
                        onDelete: { context.delete(event) },
                        expandedEntryID: $expandedEntryID
                    )
                    .padding(.horizontal, BlopSpacing.md)
                    Divider()
                        .background(BlopColor.faint)
                        .padding(.leading, BlopSpacing.md + 40)
                }
            }
        }
    }

    private struct EventGroup {
        let date: Date
        let events: [BulletEntry]
    }

    private func groupedEvents(_ events: [BulletEntry]) -> [EventGroup] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: events) { event in
            cal.startOfDay(for: event.scheduledDate ?? event.createdAt)
        }
        return dict.keys.sorted().compactMap { date in
            guard let entries = dict[date] else { return nil }
            return EventGroup(date: date, events: entries)
        }
    }

    private func emptyState(label: String) -> some View {
        Text(label)
            .font(BlopFont.body(14))
            .foregroundStyle(BlopColor.faint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, BlopSpacing.md)
    }

    private func load() {
        monthlyLog = viewModel.fetchOrCreateLog(context: context)
        carryForwardEntries = viewModel.carryForwardTasks(from: context)
        loadActiveDates()
    }

    private func loadActiveDates() {
        let start = Calendar.current.date(from: DateComponents(year: viewModel.selectedYear, month: viewModel.selectedMonth, day: 1))!
        let end = Calendar.current.date(byAdding: .month, value: 1, to: start)!
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        activeDates = Set(logs.filter { !$0.entries.isEmpty }.map { $0.date })
    }

    private func goToPreviousMonth() {
        if viewModel.selectedMonth == 1 { viewModel.selectedMonth = 12; viewModel.selectedYear -= 1 }
        else { viewModel.selectedMonth -= 1 }
        load()
    }

    private func goToNextMonth() {
        if viewModel.selectedMonth == 12 { viewModel.selectedMonth = 1; viewModel.selectedYear += 1 }
        else { viewModel.selectedMonth += 1 }
        load()
    }

    private func addEntry(text: String, type: EntryType, signifier: EntrySignifier?, date: Date?) {
        guard let log = monthlyLog else { return }
        let entry = BulletEntry(
            content: text,
            type: type,
            sortOrder: log.entries.count,
            scheduledDate: date
        )
        entry.signifier = signifier
        entry.monthlyLog = log
        context.insert(entry)
        newEventDate = Date()
    }

    private func migrateToThisMonth(_ entry: BulletEntry, log: MonthlyLog) {
        let copy = BulletEntry(
            content: entry.content,
            type: entry.type,
            sortOrder: log.entries.count,
            migratedFrom: entry.migratedFrom ?? entry.createdAt,
            migrationCount: entry.migrationCount + 1
        )
        copy.isPriority = entry.isPriority
        copy.monthlyLog = log
        context.insert(copy)
        entry.status = .migrated
        carryForwardEntries = viewModel.carryForwardTasks(from: context)
    }
}

// MARK: - Jump Button

private struct JumpButton: View {
    var signifier: String? = nil
    var icon: String? = nil
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: BlopSpacing.xs) {
                Group {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                    } else if let signifier {
                        Text(signifier)
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .frame(width: 14, height: 14, alignment: .center)
                Text(label)
                    .font(BlopFont.mono(12))
            }
            .foregroundStyle(BlopColor.ink)
            .padding(.horizontal, BlopSpacing.sm)
            .padding(.vertical, BlopSpacing.xs)
            .background(BlopColor.faint)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
