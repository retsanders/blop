import SwiftUI

struct HabitTrackerView: View {
    let completions: [HabitCompletion]
    let onToggle: (HabitCompletion) -> Void

    var body: some View {
        if completions.isEmpty { EmptyView() } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BlopSpacing.md) {
                    ForEach(completions.sorted { ($0.habit?.sortOrder ?? 0) < ($1.habit?.sortOrder ?? 0) }) { completion in
                        HabitCell(completion: completion, onToggle: { onToggle(completion) })
                    }
                }
                .padding(.horizontal, BlopSpacing.md)
                .padding(.vertical, BlopSpacing.sm)
            }
            .background(BlopColor.surface)
        }
    }
}

private struct HabitCell: View {
    let completion: HabitCompletion
    let onToggle: () -> Void

    var body: some View {
        let color = Color(hex: completion.habit?.colorHex ?? "#C87941")
        Button(action: onToggle) {
            VStack(spacing: BlopSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(completion.completed ? color.opacity(0.2) : Color.clear)
                        .frame(width: 36, height: 36)
                    Circle()
                        .strokeBorder(color, lineWidth: completion.completed ? 2 : 1.5)
                        .frame(width: 36, height: 36)
                    if completion.completed {
                        Image(systemName: completion.habit?.symbol ?? "checkmark")
                            .font(.system(size: 15))
                            .foregroundStyle(color)
                    }
                }
                if let name = completion.habit?.name {
                    Text(name)
                        .font(BlopFont.mono(9))
                        .foregroundStyle(color)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
