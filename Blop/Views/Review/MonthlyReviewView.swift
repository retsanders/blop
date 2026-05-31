import SwiftUI
import SwiftData

struct MonthlyReviewView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = ReviewViewModel()
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())

    @AppStorage("migrationThreshold") private var threshold: Int = 3

    private var monthTitle: String {
        let components = DateComponents(year: selectedYear, month: selectedMonth, day: 1)
        guard let date = Calendar.current.date(from: components) else { return "" }
        return date.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        ZStack {
            BlopColor.background.ignoresSafeArea()
            DotGridBackground().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: BlopSpacing.lg) {
                    header

                    if let review = viewModel.review {
                        taskStatsCard(review: review)
                        habitStatsCard(review: review)
                        migrationCard(review: review)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, BlopSpacing.xl)
                    }
                }
                .padding(BlopSpacing.md)
            }
        }
        .onAppear { generateReview() }
    }

    private var header: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left").foregroundStyle(BlopColor.accent)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("REVIEW")
                    .font(BlopFont.sectionHeader)
                    .foregroundStyle(BlopColor.accent)
                Text(monthTitle)
                    .font(BlopFont.dateHeader)
                    .foregroundStyle(BlopColor.ink)
            }
            Spacer()
            Button(action: nextMonth) {
                Image(systemName: "chevron.right").foregroundStyle(BlopColor.accent)
            }
        }
    }

    private func taskStatsCard(review: MonthlyReview) -> some View {
        ReviewCard(title: "TASKS") {
            StatRow(label: "Completed", value: "\(review.completedTasks) / \(review.totalTasks)")
            ProgressView(value: review.completionRate)
                .tint(BlopColor.accent)
                .padding(.vertical, BlopSpacing.xs)
            StatRow(label: "Migrated", value: "\(review.migratedTasks)")
            StatRow(label: "Dropped", value: "\(review.cancelledTasks)")
            if let day = review.mostProductiveDay {
                StatRow(label: "Most active day", value: day)
            }
        }
    }

    private func habitStatsCard(review: MonthlyReview) -> some View {
        ReviewCard(title: "HABITS") {
            if review.habitStats.isEmpty {
                Text("No habits tracked")
                    .font(BlopFont.body(14))
                    .foregroundStyle(BlopColor.faint)
            } else {
                ForEach(review.habitStats, id: \.habit.id) { stat in
                    HStack {
                        Image(systemName: stat.habit.symbol)
                            .font(.caption)
                            .foregroundStyle(BlopColor.accent)
                        Text(stat.habit.name)
                            .font(BlopFont.body(14))
                            .foregroundStyle(BlopColor.ink)
                        Spacer()
                        Text("\(Int(stat.completionRate * 100))%")
                            .font(BlopFont.mono(13))
                            .foregroundStyle(BlopColor.accent)
                        if stat.streak > 0 {
                            Text("\(stat.streak)d")
                                .font(BlopFont.mono(11))
                                .foregroundStyle(BlopColor.faint)
                        }
                    }
                    .padding(.vertical, BlopSpacing.xs)
                }
            }
        }
    }

    private func migrationCard(review: MonthlyReview) -> some View {
        ReviewCard(title: "MIGRATION") {
            StatRow(
                label: "Avg. migration count",
                value: String(format: "%.1f", review.averageMigrationCount)
            )
            StatRow(
                label: "Hit threshold (\(threshold)×)",
                value: "\(review.thresholdHits) tasks"
            )
            if review.thresholdHits > 0 {
                Text("Consider whether these recurring tasks belong in your system.")
                    .font(BlopFont.body(13))
                    .foregroundStyle(BlopColor.faint)
                    .padding(.top, BlopSpacing.xs)
            }
        }
    }

    private func generateReview() {
        viewModel.generate(year: selectedYear, month: selectedMonth, threshold: threshold, context: context)
    }

    private func previousMonth() {
        if selectedMonth == 1 { selectedMonth = 12; selectedYear -= 1 }
        else { selectedMonth -= 1 }
        generateReview()
    }

    private func nextMonth() {
        if selectedMonth == 12 { selectedMonth = 1; selectedYear += 1 }
        else { selectedMonth += 1 }
        generateReview()
    }
}

private struct ReviewCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: BlopSpacing.sm) {
            Text(title)
                .font(BlopFont.sectionHeader)
                .foregroundStyle(BlopColor.accent)
            content
        }
        .padding(BlopSpacing.md)
        .background(BlopColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(BlopColor.faint, lineWidth: 1)
        )
    }
}

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(BlopFont.body(14))
                .foregroundStyle(BlopColor.ink)
            Spacer()
            Text(value)
                .font(BlopFont.mono(14, weight: .medium))
                .foregroundStyle(BlopColor.accent)
        }
        .padding(.vertical, BlopSpacing.xs)
    }
}
