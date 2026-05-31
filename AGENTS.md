# Blop — AI Agent Context

**Blop** is an iOS bullet-journal app built in Swift / SwiftUI / SwiftData. This file gives AI agents the context needed to work on the project without re-deriving the architecture from scratch.

---

## Quick Start

```bash
# Regenerate Xcode project after editing project.yml
xcodegen generate

# Build
xcodebuild build -scheme Blop -destination 'platform=iOS Simulator,name=iPhone 17'

# Test
xcodebuild test  -scheme Blop -destination 'platform=iOS Simulator,name=iPhone 17'
```

The `.claude/settings.json` hook runs `xcodebuild test` automatically after every Edit/Write tool call.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9 |
| UI | SwiftUI |
| Persistence | SwiftData (`@Model`, `@Query`, `ModelContext`, `FetchDescriptor`) |
| Project generation | xcodegen (`project.yml`) |
| ViewModels | `@Observable` classes |
| Settings | `@AppStorage` |
| iOS target | 17.0 |

---

## File Map

```
Blop/
  BlopApp.swift                      # App entry point, ModelContainer setup
  ContentView.swift                  # Root TabView (Daily / Monthly / Review / Settings)

  Models/
    BulletEntry.swift                # Core entry model (task/event/note)
    DailyLog.swift                   # One log per calendar day
    MonthlyLog.swift                 # One log per calendar month
    HabitDefinition.swift            # Habit template (name, symbol, colorHex, sortOrder)
    HabitCompletion.swift            # Daily habit check-in record

  ViewModels/
    DailyLogViewModel.swift          # Date navigation, entry CRUD, carry-forward logic
    MonthlyLogViewModel.swift        # Month navigation, fetch-or-create monthly log
    ReviewViewModel.swift            # Completion rate, streaks, migration stats

  Views/
    Daily/
      DailyLogView.swift             # Main daily log screen
      EntryRowView.swift             # Single entry row with swipe/context actions
      RapidEntryBar.swift            # Bottom entry bar (text field + type chips + priority)
      HabitTrackerView.swift         # Horizontal habit chip row
      CarryForwardSection.swift      # Yesterday's open tasks banner
    Monthly/
      MonthlyLogView.swift           # Monthly log with task/event sections + jump buttons
      MonthlyCarryForward.swift      # Unresolved tasks from prior months
      MonthlyDayStrip.swift          # Mini calendar strip showing active days
    Review/
      MonthlyReviewView.swift        # Stats: completion rate, streaks, migration counts
    Settings/
      SettingsView.swift             # Theme, migration threshold, habits, export, git
      HabitManagementView.swift      # Habit CRUD (add/edit/reorder/delete)
    Shared/
      DesignSystem.swift             # BlopColor, BlopFont, BlopSpacing, DotGridBackground
      SignifierView.swift            # Renders bullet sigils (• ○ – ✕ > <)

  Services/
    ExportService.swift              # Markdown export of daily/monthly logs
    GitService.swift                 # Optional git auto-commit (macOS only via #if os(macOS))

  Utilities/
    AppSettings.swift                # @Observable app-wide settings (theme preference)
    TabReselection.swift             # UIKit bridge to intercept tab re-taps

BlopTests/
  BulletEntryTests.swift
  DailyLogViewModelTests.swift
  ReviewViewModelTests.swift
  ExportServiceTests.swift
```

---

## Data Model

### Relationships
```
DailyLog  (date: Date)
  └── entries: [BulletEntry]          (tasks and notes only)
  └── habitCompletions: [HabitCompletion]

MonthlyLog  (year: Int, month: Int)
  └── entries: [BulletEntry]          (ALL events + migrated tasks)

BulletEntry
  ├── dailyLog: DailyLog?             (set for tasks/notes)
  └── monthlyLog: MonthlyLog?         (set for ALL events)

HabitDefinition  (name, symbol, colorHex, sortOrder, isActive)
HabitCompletion  (completed: Bool, date: Date)
  ├── habit: HabitDefinition?
  └── dailyLog: DailyLog?
```

### Critical architecture decision — events always go to MonthlyLog
All events (regardless of their scheduled date) are stored in `MonthlyLog.entries`, not `DailyLog.entries`. They are keyed by `scheduledDate`. The daily view fetches events from the monthly log whose `scheduledDate` falls on the selected day and merges them with the daily log entries for display.

This means:
- `MonthlyLog.sortedEvents` filters `entries` by `type == .event` and `scheduledDate` in the month
- `MonthlyLog.sortedTasks` filters `entries` by `type == .task || .note`
- `DailyLog.sortedEntries` never contains events
- `DailyLogView.allDisplayEntries` = daily entries + monthly events for that day

### EntryType / EntryStatus enums

```swift
enum EntryType: String, Codable { case task, event, note }

enum EntryStatus: String, Codable {
    case open, complete, migrated, scheduled, cancelled
}
```

Signifiers: `task→•`, `event→○`, `note→–`, `complete→✕`, `migrated→>`, `scheduled→<`, `cancelled→` (original signifier, faded)

Events are **not completable** — the complete/reopen actions are removed from events everywhere (action panel, context menu, leading swipe).

---

## Design System

All colors, fonts, and spacing live in `DesignSystem.swift`. Never hardcode hex values in views.

### Colors
```swift
BlopColor.background   // warm off-white / near-black
BlopColor.ink          // near-black / near-white
BlopColor.accent       // warm brown / warm tan
BlopColor.faint        // subtle tint for dividers and empty states
BlopColor.surface      // slightly elevated surface (habit tracker bg, list rows)
BlopColor.warning      // #C87941 (same in light and dark)
```

All `BlopColor` properties are adaptive (`UIColor(dynamicProvider:)`) — they switch automatically between light and dark mode. Do not use `Color(hex:)` directly in views.

Habit cells use `Color(hex: habit.colorHex)` for per-habit coloring (vibrant palette, not the global accent).

### Typography
```swift
BlopFont.body(size)        // serif
BlopFont.mono(size)        // monospaced (section headers, dates, signifiers)
BlopFont.serif(size)       // explicit serif
BlopFont.signifier         // mono 16 medium (bullet characters)
BlopFont.dateHeader        // serif 22 semibold
BlopFont.sectionHeader     // mono 11 medium
```

### Spacing
`BlopSpacing.xs=4, sm=8, md=16, lg=24, xl=32`

---

## Key Patterns

### Tab Re-selection (navigate to today / current month)
`TabReselectionCoordinator` (an invisible `UIViewRepresentable`) is placed in `DailyLogView`'s background. It walks the responder chain to find the `UITabBarController` and installs a delegate that fires when an already-selected tab is tapped again. It posts `Notification.Name.goToToday` or `.goToCurrentMonth`.

Views listen with `.onReceive(NotificationCenter.default.publisher(for: .goToToday))`.

### SwiftData queries
`#Predicate` macros can't use enum member access inline — fetch all entries and filter in Swift instead.

### Entry action surfaces
`EntryRowView` exposes actions via:
1. Leading swipe — complete/reopen (tasks only)
2. Trailing swipe — delete
3. Long-press context menu
4. Tap → expandable inline action panel (`expandedEntryID: Binding<UUID?>`)

### Type selector reset
Both `DailyLogView` and `MonthlyLogView` reset `newEntryType = .task` in `.onDisappear`.

---

## Testing

Tests use an in-memory `ModelContainer`:
```swift
let container = try ModelContainer(
    for: BulletEntry.self, DailyLog.self, MonthlyLog.self,
    HabitDefinition.self, HabitCompletion.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
)
```

---

## What to Avoid

- Do not store events in `DailyLog.entries` — they must go to `MonthlyLog.entries` with a `scheduledDate`.
- Do not add complete/reopen actions to events anywhere.
- Do not hardcode color hex values in views — use `BlopColor.*`.
- Do not use `Process` on iOS — `GitService` is wrapped in `#if os(macOS)`.
- Do not commit the generated `Blop.xcodeproj/` — it is in `.gitignore` and regenerated by xcodegen.
