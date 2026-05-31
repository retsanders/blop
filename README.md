# Blop

A bullet journal app for iPhone, built with Swift and SwiftUI. Blop translates the analog discipline of the physical bullet journal system into a digital format — fast capture, intentional review, and a warm, paper-like feel.

## What is a bullet journal?

The bullet journal system, created by Ryder Carroll, organizes life through rapid logging: short entries marked with symbols (bullets) that indicate whether something is a task, event, or note. Unfinished tasks are regularly "migrated" forward — a deliberate act that filters out what doesn't matter.

## Features

### Daily Log
The core of Blop. Each day opens with today's date, a carry-forward section showing yesterday's open tasks, and a rapid-entry bar at the bottom for fast capture.

**Rapid entry:** Type an entry, choose its type (task `•`, event `○`, note `–`), mark it as priority with a star, and hit return. Events can have a scheduled date; if set to a future date, they route directly to the Monthly Log.

**Entry actions:** Tap the chevron on any row to reveal inline action buttons — complete, schedule to month, star/unstar, or cancel. Long-press for a context menu.

**Habit tracker:** A horizontal strip of your active habits appears each day. Tap a habit's circle to mark it done.

### Monthly Log
An overview of the current month. Switch between the Tasks and Events tabs.

- **Tasks** — goals and carry-forwards for the month
- **Events** — all events scheduled to dates within this month, sorted chronologically with their date shown
- **Carry forward** — last month's unresolved tasks, each with migrate (`>`), drop (`✕`) options

### Habit Tracking
Define habits in **Settings → Habits**. Each habit has a name, an SF Symbol icon, and a color. Active habits appear in the daily habit tracker. The monthly review shows per-habit streaks and completion rates.

### Monthly Review
An analytics screen showing:
- Task completion rate
- Migration load (average carry-forwards, threshold hits)
- Per-habit streak and completion percentage
- Most productive day of the month

### Migration Flow
The bullet journal migration discipline is built into the daily and monthly carry-forward sections. When a task has been migrated more than the configured threshold (default: 3), Blop highlights it as a nudge to either schedule it to a specific date or drop it entirely.

- `>` — migrate (carry forward to today's log)
- `<` — schedule (move to the monthly log)
- `✕` — drop (cancel)

## Design

Blop uses a warm, paper-inspired palette with a dot-grid background — light mode uses cream (`#F5F0E8`) and brown ink (`#1C1B1A`); dark mode shifts to a near-black (`#1A1918`) with warm off-white text. Typography mixes a serif body font for entry content with a monospaced font for signifiers and metadata, echoing the feel of writing in a physical journal.

Priority entries are marked with a filled `★` to the left of the bullet. Entries that have been migrated multiple times show their count there; entries that are both priority and heavily migrated alternate between the two indicators every two seconds.

## Technical Details

| | |
|---|---|
| Platform | iOS 17+ (iPhone-first) |
| Storage | SwiftData (on-device) |
| Architecture | MVVM with `@Observable` ViewModels |
| Export | Markdown files |
| Backup | Git commit (macOS only) |

## Building

Requires Xcode 16+ and xcodegen.

```bash
cd blop
xcodegen generate
open Blop.xcodeproj
```

Run on the **iPhone 17 Simulator** or any physical device running iOS 17+.

### Running tests

```bash
xcodebuild test -scheme Blop -destination 'platform=iOS Simulator,name=iPhone 17'
```
