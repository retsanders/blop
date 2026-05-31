import SwiftUI

struct MonthlyDayStrip: View {
    let year: Int
    let month: Int
    let activeDates: Set<Date>
    let onSelectDate: (Date) -> Void

    private var days: [Date] {
        let components = DateComponents(year: year, month: month, day: 1)
        guard let start = Calendar.current.date(from: components),
              let range = Calendar.current.range(of: .day, in: .month, for: start) else { return [] }
        return range.compactMap { Calendar.current.date(byAdding: .day, value: $0 - 1, to: start) }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BlopSpacing.sm) {
                ForEach(days, id: \.self) { day in
                    DayChip(date: day, hasEntries: activeDates.contains(day), onTap: { onSelectDate(day) })
                }
            }
            .padding(.horizontal, BlopSpacing.md)
            .padding(.vertical, BlopSpacing.sm)
        }
    }
}

private struct DayChip: View {
    let date: Date
    let hasEntries: Bool
    let onTap: () -> Void

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(date, format: .dateTime.weekday(.narrow))
                    .font(BlopFont.mono(9))
                    .foregroundStyle(BlopColor.accent)
                Text(date, format: .dateTime.day())
                    .font(BlopFont.mono(13, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? BlopColor.background : BlopColor.ink)
                    .frame(width: 28, height: 28)
                    .background(isToday ? BlopColor.ink : Color.clear)
                    .clipShape(Circle())
                Circle()
                    .fill(hasEntries ? BlopColor.accent : Color.clear)
                    .frame(width: 4, height: 4)
            }
        }
        .buttonStyle(.plain)
    }
}
