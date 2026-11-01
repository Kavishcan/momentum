# Momentum

A native, local-first macOS app for your Daily Three, 10/25-minute focus sessions, and a calmer Night Shutdown.

**macOS 14+ · SwiftUI · SQLite · no account · no network backend**

## Open the app

Quit any older Momentum instance first, then open `build/Momentum.app`. Version 0.2 opens a normal window and appears in the Dock. The half-filled circle in the menu bar provides quick controls and **Open Momentum**. Closing the window keeps the timer running; quitting preserves the active deadline or paused remainder for next launch.

For a prebuilt ZIP, extract it outside a cloud-synced folder and open the extracted `Momentum.app`. Local builds are ad-hoc signed, not notarized. The archive is built for the machine's architecture, not universally for both Intel and Apple Silicon.

## Build and test

Requires Xcode 15+ / Swift 5.9+, the macOS SDK, and the system SQLite library. No third-party packages or database installation are needed.

```sh
git clone https://github.com/Kavishcan/momentum.git
cd momentum
swift test --scratch-path "$TMPDIR/MomentumTests"
bash scripts/build-app.sh release
open build/Momentum.app
```

`Package.swift` opens in Xcode for development. The build script uses a temporary compiler directory to avoid File Provider signing metadata and packages `build/Momentum-macos-arm64.zip` on Apple Silicon (or `x86_64` on Intel). `MOMENTUM_BUILD_PATH` overrides the compiler directory. Use the app bundle rather than `swift run` for notification identity.

## What works

- **Today:** add up to three tasks, complete/uncomplete, edit, delete, or start a 10-minute session from a task. Completed tasks still count toward three.
- **Just Start:** choose a task or One small step; start 10 or 25 minutes, pause, resume, end, or acknowledge completion. State is committed before the interface changes. Expired sessions reconcile on wake/relaunch and appear once in history.
- **Night Shutdown:** choose a daily local time, enable/disable and explicitly save the reminder, check scheduling status, and send a five-second test notification. Edit, add, check, and delete routine steps. Checks reset at noon so after midnight still belongs to the same evening.
- **History:** choose a past date, review tasks, copy a task into today, and see the latest 100 completed focus sessions.
- **Settings:** create a consistent SQLite backup, reveal the data folder, and run a database integrity check. Appearance follows macOS light/dark mode.

All tasks, routine checks, preferences, timer state, and completed sessions live in one versioned SQLite database. Writes use bound parameters, constraints, transactions, a database-enforced three-task cap, WAL mode, and full synchronous commits. A failed write preserves the previous UI state and reports an error.

## Upgrade from 0.1

The first 0.2 launch snapshots the old `Momentum.store` using SQLite's backup API, reads a disposable working copy through SwiftData, and imports tasks, routine, reminder preferences, and the active timer in one transaction. The original store and defaults remain intact. A migration marker prevents repeated imports; failed imports roll back. Once using 0.2, keep using the new app so changes made in an old copy do not diverge from the new database.

## Reminders

In Night Shutdown, turn on **Remind me to wind down**, choose a time, and press **Save reminder**. Allow Momentum's macOS notification prompt. If permission was previously denied, enable Momentum in System Settings → Notifications and use **Refresh status**. **Send test** requests a notification five seconds later.

The OS controls displayed delivery: Focus modes, notification settings, sleep, and shutdown can suppress/delay alerts. Automated tests verify scheduling logic with an injected client; displayed banners and actual OS permission interactions still require manual verification. Completing focus requests a generic notification only if permission is already allowed; it never prompts by itself.

## Local data and backups

The database is `~/Library/Application Support/Momentum/momentum.sqlite`, with live WAL/SHM sidecars. Migration snapshots are in `MigrationBackups` within that folder. SQLite is local storage under normal macOS account/disk protections, not additional application-level encryption.

Use **Settings → Create database backup** instead of copying a live database's main file. The backup API includes committed WAL pages and produces a standalone snapshot.

To restore manually: quit Momentum, move the entire current `Momentum` data folder aside, create a fresh `Momentum` folder, copy the selected backup into it as `momentum.sqlite`, and reopen. Keep the previous folder until you confirm the restore. There is no destructive in-app reset or automated restore in this version.

## Documentation and limits

See [DESIGN.md](DESIGN.md), [ARCHITECTURE.md](ARCHITECTURE.md), and [VALIDATION.md](VALIDATION.md).

No Mac/iPhone app blocking, cloud sync, launch at login, checklist reordering, global shortcuts, automatic breaks, or signed/notarized distribution. The app does not enforce bedtime or promise medical or behavior-change outcomes.
