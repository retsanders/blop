import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var context
    @State private var query = ""
    @State private var results: [SearchResult] = []

    var body: some View {
        ZStack {
            BlopColor.background.ignoresSafeArea()
            DotGridBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                searchBar
                Divider().background(BlopColor.faint)

                if query.count < 2 {
                    emptyPrompt("Search across all entries")
                } else if results.isEmpty {
                    emptyPrompt("No results for \"\(query)\"")
                } else {
                    resultList
                }
            }
        }
        .onChange(of: query) { runSearch() }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: BlopSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(BlopColor.faint)
            TextField("Search entries…", text: $query)
                .font(BlopFont.body())
                .foregroundStyle(BlopColor.ink)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(BlopColor.faint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, BlopSpacing.md)
        .padding(.vertical, BlopSpacing.sm)
    }

    // MARK: - Results

    private var resultList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                let daily   = results.filter { $0.source == .daily }
                let monthly = results.filter { $0.source == .monthly }
                let colls   = results.filter { $0.source == .collection }

                if !daily.isEmpty {
                    sectionHeader("DAILY LOG")
                    ForEach(daily) { result in resultRow(result) }
                }
                if !monthly.isEmpty {
                    sectionHeader("MONTHLY LOG")
                    ForEach(monthly) { result in resultRow(result) }
                }
                if !colls.isEmpty {
                    sectionHeader("COLLECTIONS")
                    ForEach(colls) { result in resultRow(result) }
                }
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(BlopFont.sectionHeader)
            .foregroundStyle(BlopColor.accent)
            .padding(.horizontal, BlopSpacing.md)
            .padding(.top, BlopSpacing.md)
            .padding(.bottom, BlopSpacing.xs)
    }

    private func resultRow(_ result: SearchResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: BlopSpacing.sm) {
                Text(result.entry.type == .task ? "•" : result.entry.type == .event ? "○" : "–")
                    .font(BlopFont.signifier)
                    .foregroundStyle(BlopColor.ink)
                    .frame(width: 20, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.entry.content)
                        .font(BlopFont.body())
                        .foregroundStyle(BlopColor.ink)
                        .lineLimit(2)
                    Text(result.subtitle)
                        .font(BlopFont.mono(10))
                        .foregroundStyle(BlopColor.faint)
                }
                Spacer()
            }
            .padding(.horizontal, BlopSpacing.md)
            .padding(.vertical, BlopSpacing.sm)

            Divider().background(BlopColor.faint).padding(.leading, BlopSpacing.md + 28)
        }
    }

    private func emptyPrompt(_ text: String) -> some View {
        Text(text)
            .font(BlopFont.body(14))
            .foregroundStyle(BlopColor.faint)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.top, BlopSpacing.xl)
    }

    // MARK: - Search Logic

    private func runSearch() {
        guard query.count >= 2 else { results = []; return }
        let all = (try? context.fetch(FetchDescriptor<BulletEntry>())) ?? []
        let matched = all.filter { $0.content.localizedCaseInsensitiveContains(query) }

        let cal = Calendar.current
        results = matched.compactMap { entry -> SearchResult? in
            if let log = entry.dailyLog {
                let label = log.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
                return SearchResult(entry: entry, source: .daily, subtitle: label)
            } else if entry.monthlyLog != nil {
                let components = DateComponents(year: entry.monthlyLog?.year, month: entry.monthlyLog?.month, day: 1)
                let date = cal.date(from: components) ?? entry.createdAt
                let label = date.formatted(.dateTime.month(.wide).year())
                return SearchResult(entry: entry, source: .monthly, subtitle: label)
            } else if let coll = entry.collection {
                return SearchResult(entry: entry, source: .collection, subtitle: coll.title)
            }
            return nil
        }
    }
}

// MARK: - Supporting Types

private enum ResultSource { case daily, monthly, collection }

private struct SearchResult: Identifiable {
    let id = UUID()
    let entry: BulletEntry
    let source: ResultSource
    let subtitle: String
}
