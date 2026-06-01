import SwiftUI

struct RapidEntryBar: View {
    @Binding var text: String
    @Binding var selectedType: EntryType
    @Binding var signifier: EntrySignifier?
    @Binding var eventDate: Date
    let onSubmit: (String, EntryType, EntrySignifier?, Date?) -> Void

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

            // Type strip + signifier cycle button
            HStack(spacing: 0) {
                ForEach([EntryType.task, .note, .event], id: \.self) { type in
                    if type == .event && selectedType == .event {
                        // Event chip: bullet + inline compact DatePicker
                        HStack(spacing: BlopSpacing.xs) {
                            Text("○")
                                .font(BlopFont.signifier)
                                .foregroundStyle(BlopColor.background)
                            DatePicker("", selection: $eventDate, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(BlopColor.background)
                        }
                        .padding(.horizontal, BlopSpacing.sm)
                        .padding(.vertical, BlopSpacing.xs)
                        .background(BlopColor.accent)
                        .clipShape(Capsule())
                        .padding(.leading, BlopSpacing.xs)
                    } else {
                        TypeChip(type: type, isSelected: selectedType == type) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedType = type
                            }
                        }
                    }
                }
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        signifier = nextSignifier(after: signifier)
                    }
                } label: {
                    Text(signifier?.character ?? "○")
                        .font(BlopFont.mono(16, weight: .medium))
                        .foregroundStyle(signifier != nil ? signifierColor : BlopColor.ink.opacity(0.3))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, BlopSpacing.sm)
            }
            .padding(.bottom, BlopSpacing.sm)
            .background(BlopColor.background)
        }
        .background(BlopColor.background)
        .animation(.easeInOut(duration: 0.2), value: selectedType)
    }

    private var signifierColor: Color {
        switch signifier {
        case .priority:    return BlopColor.warning
        case .inspiration: return BlopColor.accent
        case .explore:     return BlopColor.ink
        case nil:          return BlopColor.faint
        }
    }

    private func nextSignifier(after current: EntrySignifier?) -> EntrySignifier? {
        switch current {
        case nil:          return .priority
        case .priority:    return .inspiration
        case .inspiration: return .explore
        case .explore:     return nil
        }
    }

    private func submitIfNeeded() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let date = selectedType == .event ? eventDate : nil
        onSubmit(trimmed, selectedType, signifier, date)
        text = ""
        signifier = nil
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
