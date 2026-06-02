import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("migrationThreshold") private var threshold: Int = 3
    @State private var settings = AppSettings.shared
    @State private var showDirectoryPicker = false
    @State private var showExportFolderPicker = false
    @State private var exportError: String?
    @State private var exportSuccess = false
    @State private var isCommitting = false
    @State private var gitNotAvailable = false
    @State private var showDeleteConfirmation1 = false
    @State private var showDeleteConfirmation2 = false

    private let exportService = ExportService()
    private let gitService = GitService()

    var body: some View {
        ZStack {
            BlopColor.background.ignoresSafeArea()

            Form {
                themeSection
                habitsSection
                collectionsSection
                migrationSection
                exportSection
                gitSection
                dangerSection
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Export Complete", isPresented: $exportSuccess) {
            Button("OK", role: .cancel) {}
        }
        .alert("Error", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .fileImporter(
            isPresented: $showDirectoryPicker,
            allowedContentTypes: [.folder]
        ) { result in
            switch result {
            case .success(let url): settings.gitRepoURL = url
            case .failure(let err): exportError = err.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $showExportFolderPicker,
            allowedContentTypes: [.folder]
        ) { result in
            if case .success(let url) = result {
                do {
                    try exportService.writeToDirectory(url, context: context)
                    exportSuccess = true
                } catch {
                    exportError = error.localizedDescription
                }
            }
        }
        .alert("Clear All Data?", isPresented: $showDeleteConfirmation1) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) { showDeleteConfirmation2 = true }
        } message: {
            Text("This will permanently delete all your journal entries, habits, and collections.")
        }
        .alert("Are you absolutely sure?", isPresented: $showDeleteConfirmation2) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) { clearAllData() }
        } message: {
            Text("This cannot be undone. Every entry, habit, and collection will be permanently erased.")
        }
    }

    private var themeSection: some View {
        Section {
            Picker("Appearance", selection: $settings.themePreference) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
        } header: {
            Text("APPEARANCE")
                .font(BlopFont.sectionHeader)
        }
    }

    private var habitsSection: some View {
        Section {
            NavigationLink(destination: HabitManagementView()) {
                Label("Manage Habits", systemImage: "list.bullet.circle")
                    .foregroundStyle(BlopColor.ink)
            }
        } header: {
            Text("HABITS")
                .font(BlopFont.sectionHeader)
        }
    }

    private var collectionsSection: some View {
        Section {
            NavigationLink(destination: CollectionsManagementView()) {
                Label("Manage Collections", systemImage: "folder.fill")
                    .foregroundStyle(BlopColor.ink)
            }
        } header: {
            Text("COLLECTIONS")
                .font(BlopFont.sectionHeader)
        }
    }

    private var migrationSection: some View {
        Section {
            Stepper(
                "Recommend after \(threshold) migration\(threshold == 1 ? "" : "s")",
                value: $threshold,
                in: 1...10
            )
            Text("When a task has been carried forward this many times, Blop will suggest scheduling or dropping it.")
                .font(BlopFont.body(13))
                .foregroundStyle(BlopColor.faint)
        } header: {
            Text("MIGRATION")
                .font(BlopFont.sectionHeader)
        }
    }

    private var exportSection: some View {
        Section {
            Button { showExportFolderPicker = true } label: {
                HStack {
                    Text("Export All to Markdown")
                        .foregroundStyle(BlopColor.ink)
                    Spacer()
                    Image(systemName: "arrow.up.doc")
                        .foregroundStyle(BlopColor.accent)
                }
            }
        } header: {
            Text("EXPORT")
                .font(BlopFont.sectionHeader)
        }
    }

    private var dangerSection: some View {
        Section {
            Button("Clear All Data", role: .destructive) {
                showDeleteConfirmation1 = true
            }
            .font(BlopFont.mono(14))
        } header: {
            Text("DANGER ZONE")
                .font(BlopFont.sectionHeader)
                .foregroundStyle(BlopColor.warning)
        }
    }

    private var gitSection: some View {
        Section {
            if let url = settings.gitRepoURL {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BlopColor.accent)
                    Text(url.lastPathComponent)
                        .font(BlopFont.body(14))
                        .foregroundStyle(BlopColor.ink)
                    Spacer()
                    Button("Change") { showDirectoryPicker = true }
                        .font(BlopFont.mono(13))
                        .foregroundStyle(BlopColor.accent)
                }

                Button(action: exportAndCommit) {
                    HStack {
                        Text("Export & Commit")
                            .foregroundStyle(BlopColor.ink)
                        Spacer()
                        if isCommitting {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundStyle(BlopColor.accent)
                        }
                    }
                }
                .disabled(isCommitting)
            } else {
                Button(action: { showDirectoryPicker = true }) {
                    Label("Choose Git Repository Folder", systemImage: "folder.badge.plus")
                        .foregroundStyle(BlopColor.accent)
                }
            }

            if gitNotAvailable {
                Text("Git not found. Install Xcode Command Line Tools to enable git backup.")
                    .font(BlopFont.body(12))
                    .foregroundStyle(BlopColor.warning)
            }
        } header: {
            Text("GIT BACKUP")
                .font(BlopFont.sectionHeader)
        } footer: {
            Text("Exports all logs as markdown files and commits them to the selected local git repository. Push to a remote (GitHub, etc.) manually.")
                .font(BlopFont.body(12))
        }
    }

    private func clearAllData() {
        try? context.delete(model: BulletEntry.self)
        try? context.delete(model: DailyLog.self)
        try? context.delete(model: MonthlyLog.self)
        try? context.delete(model: HabitDefinition.self)
        try? context.delete(model: HabitCompletion.self)
        try? context.delete(model: Collection.self)
    }

    private func exportAndCommit() {
        guard GitService.isGitAvailable() else {
            gitNotAvailable = true
            return
        }
        guard let repoURL = settings.gitRepoURL else { return }

        isCommitting = true
        Task {
            do {
                try exportService.writeToDirectory(repoURL, context: context)
                try gitService.initIfNeeded(at: repoURL)
                let message = "Journal export \(Date().formatted(.iso8601))"
                try gitService.stageAndCommit(at: repoURL, message: message)
                await MainActor.run { exportSuccess = true }
            } catch {
                await MainActor.run { exportError = error.localizedDescription }
            }
            await MainActor.run { isCommitting = false }
        }
    }
}
