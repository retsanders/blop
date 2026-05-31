import SwiftUI

struct RapidEntryBar: View {
    @Binding var text: String
    @Binding var selectedType: EntryType
    @Binding var isPriority: Bool
    @Binding var eventDate: Date
    let onSubmit: (String, EntryType, Bool, Date?) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Divider().background(BlopColor.faint)

            // Text field row
            HStack(spacing: BlopSpacing.sm) {
                TextField("Add entry…", text: $text)
                    .font(BlopFont.body())
                    .foregroundStyle(BlopColor.ink)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit(submitIfNeeded)

                if !text.isEmpty {
                    Button(action: submitIfNeeded) {
                        Image(systemName: "return")
                            .font(.body)
                            .foregroundStyle(BlopColor.accent)
                    }
                }
            }
            .padding(.horizontal, BlopSpacing.md)
            .padding(.top, BlopSpacing.sm)
            .padding(.bottom, BlopSpacing.xs)

            // Date picker row (events only)
            if selectedType == .event {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(BlopColor.accent)
                    DatePicker("", selection: $eventDate, displayedComponents: .date)
                        .labelsHidden()
                        .font(BlopFont.mono(13))
                        .tint(BlopColor.accent)
                    Spacer()
                }
                .padding(.horizontal, BlopSpacing.md)
                .padding(.bottom, BlopSpacing.xs)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Type strip + priority toggle
            HStack(spacing: 0) {
                ForEach([EntryType.task, .note, .event], id: \.self) { type in
                    TypeChip(type: type, isSelected: selectedType == type) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedType = type
                        }
                    }
                }
                Spacer()
                Toggle(isOn: $isPriority) {
                    Image(systemName: isPriority ? "star.fill" : "star")
                        .font(.body)
                        .foregroundStyle(isPriority ? BlopColor.warning : BlopColor.faint)
                }
                .toggleStyle(.button)
                .tint(BlopColor.warning)
                .padding(.trailing, BlopSpacing.md)
            }
            .padding(.bottom, BlopSpacing.sm)
            .background(BlopColor.background)
        }
        .background(BlopColor.background)
        .animation(.easeInOut(duration: 0.2), value: selectedType)
    }

    private func submitIfNeeded() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let date = selectedType == .event ? eventDate : nil
        onSubmit(trimmed, selectedType, isPriority, date)
        text = ""
        isPriority = false
    }
}

private struct TypeChip: View {
    let type: EntryType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: BlopSpacing.xs) {
                Text(type.signifier)
                    .font(BlopFont.signifier)
                Text(type.label)
                    .font(BlopFont.mono(12))
            }
            .foregroundStyle(isSelected ? BlopColor.background : BlopColor.ink)
            .padding(.horizontal, BlopSpacing.sm)
            .padding(.vertical, BlopSpacing.xs)
            .background(isSelected ? BlopColor.accent : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.leading, BlopSpacing.xs)
    }
}

extension EntryType {
    var signifier: String {
        switch self {
        case .task:  return "•"
        case .event: return "○"
        case .note:  return "–"
        }
    }

    var label: String {
        switch self {
        case .task:  return "Task"
        case .event: return "Event"
        case .note:  return "Note"
        }
    }

    var icon: String {
        switch self {
        case .task:  return "circle.dotted"
        case .event: return "circle"
        case .note:  return "minus"
        }
    }
}
