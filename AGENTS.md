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
xcodebuild test -scheme Blop -destination 'platform=iOS Simulator,name=iPhone 17'

# Install and launch on booted simulator
xcrun simctl install booted Blop.app && xcrun simctl launch booted com.robsanders.blop
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
  BlopApp.swift                      # App entry, ModelContainer, one-time signifier migration
  ContentView.swift                  # Root TabView — Today | Month | Future | Search | Settings

  Models/
    BulletEntry.swift                # Core entry model (task/event/note) + EntrySignifier enum
    DailyLog.swift                   # One log per calendar day
    MonthlyLog.swift                 # One log per calendar month
    Collection.swift                 # User-defined list (free-form collection)
    HabitDefinition.swift            # Habit template (name, symbol, colorHex, sortOrder)
    HabitCompletion.swift            # Daily habit check-in record

  ViewModels/
    DailyLogViewModel.swift          # Date navigation, entry CRUD, carry-forward logic
    MonthlyLogViewModel.swift        # Month navigation, fetch-or-create monthly log
    ReviewViewModel.swift            # Completion rate, streaks, migration stats

  Views/
    Daily/
      DailyLogView.swift             # Main daily log screen (tab 0)
      EntryRowView.swift             # Single entry row: swipe / context menu / expand panel
      RapidEntryBar.swift            # Bottom entry bar: text + type chips + signifier cycle
      HabitTrackerView.swift         # Horizontal habit chip row
      CarryForwardSection.swift      # Yesterday's open tasks banner
    Monthly/
      MonthlyLogView.swift           # Monthly log — tasks + events sections, jump buttons
      MonthlyCarryForward.swift      # Unresolved tasks from prior months
      MonthlyDayStrip.swift          # Mini calendar strip showing active days
    FutureLog/
      FutureLogView.swift            # Next 6 months as collapsible sections (tab 2)
    Search/
      SearchView.swift               # Full-text search across all entries (tab 3)
    Review/
      MonthlyReviewView.swift        # Stats sheet (opened from MonthlyLogView chart button)
    Collections/
      CollectionsView.swift          # CollectionsManagementView + CollectionDetailView
    Settings/
      SettingsView.swift             # Appearance, habits, collections, migration, export, git
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
  ├── entries: [BulletEntry]           (tasks and notes only — never events)
  └── habitCompletions: [HabitCompletion]

MonthlyLog  (year: Int, month: Int)
  └── entries: [BulletEntry]           (ALL events + monthly/migrated tasks)

Collection  (title, symbol, sortOrder)
  └── entries: [BulletEntry]           (tasks and notes only — no events)

BulletEntry
  ├── dailyLog: DailyLog?              (set for daily tasks/notes)
  ├── monthlyLog: MonthlyLog?          (set for ALL events, and monthly tasks)
  └── collection: Collection?          (set for collection entries)

HabitDefinition  (name, symbol, colorHex, sortOrder, isActive)
HabitCompletion  (completed: Bool, date: Date)
  ├── habit: HabitDefinition?
  └── dailyLog: DailyLog?
```

### Critical: events always go to MonthlyLog
All events are stored in `MonthlyLog.entries` keyed by `scheduledDate`, never in `DailyLog`. The daily view fetches events from the monthly log whose `scheduledDate` falls on the selected day and merges them.

- `MonthlyLog.sortedEvents` — filters by `type == .event` and `scheduledDate` in the month
- `MonthlyLog.sortedTasks` — filters by `type == .task || .note`
- `DailyLog.sortedEntries` — never contains events
- `DailyLogView.allDisplayEntries` — daily entries + monthly events for that day

### Critical: collections never contain events
`CollectionDetailView` blocks the `.event` type in its `addEntry` — collections are task/note lists only.

### EntryType / EntryStatus / EntrySignifier

```swift
enum EntryType: String, Codable { case task, event, note }

enum EntryStatus: String, Codable {
    case open, complete, migrated, scheduled, cancelled
}

enum EntrySignifier: String, Codable {
    case priority    // ★  warning color
    case inspiration // !  accent color
    case explore     // ✦  ink color
}
```

Bullet characters: `task→•`, `event→○`, `note→–`, `complete→✕`, `migrated→>`, `scheduled→<`

**Signifier vs isPriority:** `BulletEntry` keeps `var isPriority: Bool` in the schema for backward compatibility, but all UI reads and writes `var signifier: EntrySignifier?` instead. A one-time migration in `BlopApp.swift` (guarded by `@AppStorage("signifierMigrated")`) converts old `isPriority=true` rows to `signifier=.priority` on first launch. Do not use `isPriority` in new UI code.

**Renamed method:** `BulletEntry.bulletCharacter(atThreshold:)` returns the status character string (renamed from the old `signifier(atThreshold:)` to avoid collision with the `signifier` property).

Events are **not completable** — complete/reopen is removed from events everywhere.

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

All `BlopColor` properties are adaptive (`UIColor(dynamicProvider:)`) — they respond to system light/dark automatically. Do not use `Color(hex:)` directly in views. Exception: habit cells use `Color(hex: habit.colorHex)` for per-habit coloring.

### Signifier content colors
- `.priority` → `BlopColor.warning`
- `.inspiration` → `BlopColor.accent`
- `.explore` → `BlopColor.ink`
- `nil` → `BlopColor.ink`

### Typography
```swift
BlopFont.body(size)        // serif
BlopFont.mono(size)        // monospaced (section headers, dates, signifiers)
BlopFont.signifier         // mono 16 medium (bullet characters)
BlopFont.dateHeader        // serif 22 semibold
BlopFont.sectionHeader     // mono 11 medium
```

### Spacing
`BlopSpacing.xs=4, sm=8, md=16, lg=24, xl=32`

---

## Key Patterns

### Tab bar (5 tabs)
```
Index 0 — Today    → DailyLogView        (calendar.day.timeline.left)
Index 1 — Month    → MonthlyLogView      (calendar)
Index 2 — Future   → FutureLogView       (calendar.badge.clock)
Index 3 — Search   → SearchView          (magnifyingglass)
Index 4 — Settings → SettingsView        (gear)
```
Review is no longer a tab — it opens as a sheet from the chart icon button in `MonthlyLogView`'s header.

### Tab re-selection
`TabReselectionCoordinator` (invisible `UIViewRepresentable` in `DailyLogView`'s `.background`) walks the responder chain to find `UITabBarController` and installs a delegate. On re-tap it posts:
- Index 0 → `Notification.Name.goToToday`
- Index 1 → `Notification.Name.goToCurrentMonth`
- Index 2 → `Notification.Name.goToFutureLog`

Views subscribe with `.onReceive(NotificationCenter.default.publisher(for: .goToToday))`.

### Tab selection persistence
`ContentView` uses `@SceneStorage("selectedTab")` (not `@State`) so the selected tab survives view identity changes caused by `@AppStorage` theme changes.

### Signifier toast
`Notification.Name.signifierToast` (defined in `TabReselection.swift`) is posted by `RapidEntryBar` when the signifier cycle button is tapped. `ContentView` listens and shows a bottom-of-screen toast overlay. Do **not** post this from `EntryRowView` — the panel changes signifier silently.

### Schedule destination
`ScheduleDestination` enum (in `EntryRowView.swift`) has two cases:
- `.month(Date)` — schedule to a monthly log
- `.collection(Collection)` — move entry to a collection

`EntryRowView.onSchedule: (ScheduleDestination) -> Void`. Call sites that don't support scheduling use `{ _ in }`.

### Entry action surfaces
`EntryRowView` exposes actions via:
1. Leading swipe — complete/reopen (tasks only, not events)
2. Trailing swipe — cancel entry
3. Long-press context menu — signifier picker + complete + schedule + cancel
4. Tap chevron → expandable inline action panel (`expandedEntryID: Binding<UUID?>`)

`EntryRowView` signature uses `onSetSignifier: (EntrySignifier?) -> Void` (not `onTogglePriority`).

### RapidEntryBar signifier
The entry bar has a cycle button (SF Symbol in a circular background) that rotates: `nil → priority → inspiration → explore → nil`. Its binding is `signifier: Binding<EntrySignifier?>`. Tapping posts `.signifierToast` via `NotificationCenter`. The `onSubmit` closure signature is `(String, EntryType, EntrySignifier?, Date?)`.

### SearchView idle state
When the search query is fewer than 2 characters, `SearchView` shows a Collections list (all user-defined collections with entry counts). Tapping a collection opens `CollectionDetailView` in a sheet. Full-text search activates at 2+ characters.

### SwiftData queries
`#Predicate` macros can't use enum member access inline — fetch all entries and filter in Swift instead.

### Type selector reset
`DailyLogView`, `MonthlyLogView`, `FutureLogView`, and `CollectionDetailView` all reset `newEntryType = .task` in `.onDisappear`.

---

## Testing

All test containers must include `Collection.self`:
```swift
let container = try ModelContainer(
    for: BulletEntry.self, DailyLog.self, MonthlyLog.self,
        HabitDefinition.self, HabitCompletion.self, Collection.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
)
```

---

## What to Avoid

- Do not store events in `DailyLog.entries` — they must go to `MonthlyLog.entries` with a `scheduledDate`.
- Do not store events in `Collection.entries` — collections are task/note lists only.
- Do not add complete/reopen actions to events anywhere.
- Do not use `entry.isPriority` in UI — use `entry.signifier == .priority` instead.
- Do not call `entry.signifier(atThreshold:)` — that method was renamed to `bulletCharacter(atThreshold:)`.
- Do not hardcode color hex values in views — use `BlopColor.*`.
- Do not use `Process` on iOS — `GitService` is wrapped in `#if os(macOS)`.
- Do not commit the generated `Blop.xcodeproj/` — it is in `.gitignore` and regenerated by xcodegen.
- Do not add a 6th tab — the tab bar is at the 5-tab iOS limit.
