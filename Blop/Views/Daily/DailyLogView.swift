import SwiftUI
import SwiftData

struct DailyLogView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \HabitDefinition.sortOrder) private var habits: [HabitDefinition]

    @State private var viewModel = DailyLogViewModel()
    @State private var currentLog: DailyLog?
    @State private var previousLog: DailyLog?
    @State private var newEntryText = ""
    @State private var newEntryType: EntryType = .task
    @State private var newEntrySignifier: EntrySignifier? = nil
    @State private var newEventDate = Date()
    @State private var todayMonthlyEvents: [BulletEntry] = []
    @State private var expandedEntryID: UUID? = nil

    @AppStorage("migrationThreshold") private var threshold: Int = 3

    // Merges daily log entries with any events from the monthly log scheduled today.
    private var allDisplayEntries: [BulletEntry] {
        let daily = currentLog?.sortedEntries ?? []
        return (daily + todayMonthlyEvents).sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            BlopColor.background.ignoresSafeArea()
            DotGridBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                dateHeader
                Divider().background(BlopColor.faint)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                        if let prev = previousLog {
                            let open = prev.openTasks
                            if !open.isEmpty {
                                CarryForwardSection(
                                    entries: open,
                                    threshold: threshold,
                                    onMigrate: { migrate($0) },
                                    onSchedule: { entry in
                                        let cal = Calendar.current
                                        let now = Date()
                                        let comps = cal.dateComponents([.year, .month], from: now)
                                        let firstOfMonth = cal.date(from: comps) ?? now
                                        scheduleEntry(entry, to: .month(firstOfMonth))
                                    },
                                    onDrop: { viewModel.drop($0) }
                                )
                            }
                        }

                        if let log = currentLog {
                            HabitTrackerView(
                                completions: log.habitCompletions,
                                onToggle: { $0.completed.toggle() }
                            )
                        }

                        let entries = allDisplayEntries
                        if entries.isEmpty {
                            emptyState
                        } else {
                            ForEach(entries) { entry in
                                EntryRowView(
                                    entry: entry,
                                    threshold: threshold,
                                    onToggleComplete: { viewModel.toggleComplete(entry) },
                                    onCancel: { viewModel.cancel(entry) },
                                    onRestore: { entry.status = .open },
                                    onSetSignifier: { entry.signifier = $0 },
                                    onSchedule: { dest in scheduleEntry(entry, to: dest) },
                                    onDelete: { context.delete(entry) },
                                    expandedEntryID: $expandedEntryID
                                )
                                .padding(.horizontal, BlopSpacing.md)
                                Divider()
                                    .background(BlopColor.faint)
                                    .padding(.leading, BlopSpacing.md + 40)
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
        // Tab re-selection probe — intercepts tab bar taps via responder chain
        .background(TabReselectionCoordinator())
        .onReceive(NotificationCenter.default.publisher(for: .goToToday)) { _ in
            viewModel.goToToday()
            loadLogs()
        }
        .onAppear { loadLogs() }
        .onChange(of: viewModel.selectedDate) { loadLogs() }
        .onDisappear { newEntryType = .task }
    }

    private var dateHeader: some View {
        HStack {
            Button(action: viewModel.goToPreviousDay) {
                Image(systemName: "chevron.left")
                    .font(.body)
                    .foregroundStyle(BlopColor.accent)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(viewModel.selectedDate, format: .dateTime.weekday(.wide))
                    .font(BlopFont.mono(11))
                    .foregroundStyle(BlopColor.accent)
                    .textCase(.uppercase)
                Text(viewModel.selectedDate, format: .dateTime.day().month(.wide).year())
                    .font(BlopFont.dateHeader)
                    .foregroundStyle(BlopColor.ink)
            }
            .onTapGesture { viewModel.goToToday(); loadLogs() }

            Spacer()

            Button(action: viewModel.goToNextDay) {
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundStyle(viewModel.isToday ? BlopColor.faint : BlopColor.accent)
            }
            .disabled(viewModel.isToday)
        }
        .padding(.horizontal, BlopSpacing.md)
        .padding(.vertical, BlopSpacing.sm)
    }

    private var emptyState: some View {
        VStack(spacing: BlopSpacing.sm) {
            Text("·")
                .font(BlopFont.serif(48))
                .foregroundStyle(BlopColor.faint)
            Text("Begin your log")
                .font(BlopFont.body(14))
                .foregroundStyle(BlopColor.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, BlopSpacing.xl)
    }

    private func loadLogs() {
        currentLog = viewModel.fetchOrCreateLog(for: viewModel.selectedDate, context: context)
        previousLog = viewModel.fetchLog(for: viewModel.previousDate, context: context)
        if let log = currentLog {
            viewModel.ensureHabitCompletions(for: log, habits: habits, context: context)
        }
        loadTodayMonthlyEvents()
    }

    // Fetches events from the monthly log whose scheduledDate falls on the selected day.
    private func loadTodayMonthlyEvents() {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: viewModel.selectedDate)
        guard let todayEnd = cal.date(byAdding: .day, value: 1, to: todayStart) else { return }
        let descriptor = FetchDescriptor<BulletEntry>()
        let all = (try? context.fetch(descriptor)) ?? []
        todayMonthlyEvents = all.filter { entry in
            guard entry.type == .event, entry.monthlyLog != nil,
                  let scheduled = entry.scheduledDate else { return false }
            return scheduled >= todayStart && scheduled < todayEnd
        }
    }

    private func addEntry(text: String, type: EntryType, signifier: EntrySignifier?, date: Date?) {
        guard let log = currentLog else { return }

        if type == .event {
            let scheduledDate = date ?? viewModel.selectedDate
            let cal = Calendar.current
            let year = cal.component(.year, from: scheduledDate)
            let month = cal.component(.month, from: scheduledDate)
            let monthVM = MonthlyLogViewModel()
            let monthLog = monthVM.fetchOrCreate(year: year, month: month, context: context)
            let entry = BulletEntry(
                content: text,
                type: .event,
                sortOrder: monthLog.entries.count,
                scheduledDate: scheduledDate
            )
            entry.signifier = signifier
            entry.monthlyLog = monthLog
            context.insert(entry)
            newEventDate = Date()
            loadTodayMonthlyEvents()
            return
        }

        viewModel.addEntry(content: text, type: type, signifier: signifier, scheduledDate: nil, to: log, context: context)
        newEventDate = Date()
    }

    private func migrate(_ entry: BulletEntry) {
        guard let log = currentLog else { return }
        viewModel.migrate(entry, to: log, context: context)
    }

    private func scheduleEntry(_ entry: BulletEntry, to destination: ScheduleDestination) {
        switch destination {
        case .month(let date):
            let cal = Calendar.current
            let year = cal.component(.year, from: date)
            let month = cal.component(.month, from: date)
            let vm = MonthlyLogViewModel()
            let log = vm.fetchOrCreate(year: year, month: month, context: context)
            viewModel.schedule(entry, monthlyLog: log, context: context)
        case .collection(let coll):
            entry.dailyLog = nil
            entry.collection = coll
            entry.status = .scheduled
        }
    }
}
