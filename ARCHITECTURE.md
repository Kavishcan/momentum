# Momentum architecture

## App structure

A macOS 14+ SwiftUI app with a single named `Window("Momentum", id: "dashboard")`, normal Dock presence, and a compact `MenuBarExtra` window panel. The main window owns sustained task/routine editing; the panel provides quick focus controls and routes back to the main window. No backend, network client, account, cloud sync, or third-party package.

```text
AppRuntime: open database → legacy migration → Workspace
Workspace
  ├─ MomentumStore → MomentumDatabase → SQLiteConnection → system sqlite3
  ├─ FocusController → FocusSession → same MomentumDatabase
  └─ ReminderCoordinator → injected LocalReminderClient → UNUserNotificationCenter
       ↑
Today / Night Shutdown / History / Settings / compact menu
```

`MomentumCore` contains value records, database access, calendar rules, the timer state machine, migration, and the notification scheduling coordinator. The app module owns SwiftUI, AppKit window/lifecycle adapters, the timer tick, and the real OS notification client. `CSQLite` is a module map for the macOS SDK's SQLite headers/library.

## SQLite persistence

The database is `~/Library/Application Support/Momentum/momentum.sqlite`. Connections enable foreign keys, WAL mode, `synchronous=FULL`, a 1.5-second busy timeout, and `FULLMUTEX`. Versioning uses `PRAGMA user_version`; newer schemas are refused rather than overwritten. Opening checks database integrity. DDL and first-run seeding are transactional and checked again inside the transaction to avoid overlapping initialization.

| Table | Content |
| --- | --- |
| metadata | Schema-adjacent initialization and import markers |
| tasks | UUID, title, local day key, creation time, completion |
| routine_steps | UUID, title, display position |
| routine_checks | Step/night pairs with a cascading foreign key |
| night_settings | Single enabled/hour/minute row with constraints |
| active_focus | Single validated Codable session, stored as text |
| focus_history | Unique session UUID, title, duration, completion time |

All user strings use bound parameters. Titles are validated; a SQLite trigger enforces three tasks per day even across connections. Completed tasks count toward the limit. Multi-statement operations use `BEGIN IMMEDIATE`/commit/rollback. Views use value snapshots and publish new state only after writes succeed. Failed writes keep inputs/session state and report an error. SQLite remains serialized on the main actor; the small bounded operations suit this local utility. This is not designed for a large concurrent database workload.

Task/day queries are indexed. History's focus view shows the latest 100 rows; the database retains older entries. Deleting a routine step cascades its completion records. There is no destructive automatic database recovery or memory-only fallback.

## Migration from 0.1

The legacy `DailyTask` and `RoutineStep` SwiftData models are retained solely to decode old stores. On first startup, if `Momentum.store` exists:

1. The SQLite backup API makes a consistent durable snapshot in `MigrationBackups`, including committed WAL data.
2. A disposable copy is opened by SwiftData. It is writable so Core Data can create its required journal metadata; the original and durable snapshot are not opened by SwiftData for mutation.
3. UUIDs, tasks, routine/checks, AppStorage reminder preferences, and the previous Codable timer are imported into SQLite in one transaction.
4. An import marker commits with the records. Repeated starts do not import again. A failed import rolls back and preserves the original files/preferences.

The original defaults/store are retained but no longer used for normal writes. New installations mark migration as not needed. A synthetic legacy fixture tests import/rollback/idempotence; an opt-in local test also verifies an isolated snapshot of an actual previous store without printing its contents.

## Focus lifecycle

`FocusSession` has a UUID and idle/running/paused/finished phases. Start accepts 10/25 minutes, captures a task title, and sets an absolute deadline. Pause stores the remainder; resume creates a new deadline. The clock is clamped to the session duration and never becomes negative. Old Codable sessions without the new UUID/timestamp fields remain decodable for migration.

The app-lifetime `FocusController` ticks once a second. It writes only state transitions, not every second. Start/pause/resume/end/finish persist before the UI changes. Completion and a unique history row commit atomically; `INSERT OR IGNORE` prevents duplicates after relaunch/repeated expiry checks. Completion timestamps use the deadline rather than the later wake/launch time. Workspace refreshes history immediately after startup reconciliation and after a completion transition.

Wake, activation, and timezone notifications dispatch on the main run loop and refresh the timer, calendar records, and reminder schedule. Closing the window leaves the timer alive. Quitting/relaunching preserves a deadline or paused remainder. Manual system clock changes affect absolute deadlines, an acknowledged limitation. Unfinished sessions are not recorded as completed.

## Reminder lifecycle

`ReminderCoordinator` depends on `LocalReminderClient`, so authorization, scheduling, cancellation, failures, rapid updates, and test requests can be verified without granting OS permission. UI changes are explicit drafts until saved. Permission is requested only from saving an enabled reminder.

The coordinator serializes asynchronous schedule updates, skipping superseded queued work and reading the latest desired settings before each apply. The stable identifier `momentum.night-shutdown` replaces an existing request without removing a working schedule first. Disabling cancels the night/test request. Revoked permission shows an actionable status and cancels stale requests. Failure reports that scheduling failed and leaves Refresh status available. Startup restores the schedule without prompting.

The real adapter uses a repeating `UNCalendarNotificationTrigger` with local hour/minute and no fixed timezone. Send test requests a five-second local alert. Completion requests a generic notification only when permission is already granted. Foreground delivery allows banner/list presentation. Notification clicks route to Night Shutdown and activate the main window. Actual banner delivery remains controlled by macOS Focus, sleep, shutdown, and notification settings.

## Calendar semantics

Daily tasks use Gregorian `yyyy-MM-dd` in the current Mac timezone. A new day starts empty; older records remain available through History. Copying a historical task creates a new task and obeys today's cap. Nights run noon to noon, preserving after-midnight checks. Calendar day arithmetic handles DST; routine checks retain a record for each checked night. Changing timezone changes the displayed local day/night without rewriting historical keys.

## Backups and packaging

The SQLite backup API includes live committed WAL pages. Export finalizes the destination in DELETE journal mode so the snapshot can be opened read-only without missing sidecars. Export cannot replace the active database or a file in its folder. The save panel stages a snapshot and then moves/replaces the user-selected destination. There is no automatic restore: documentation explains restoring to a fresh data directory while the app is quit.

The build script compiles outside synced folders, assembles/ad-hoc signs a staged `.app`, verifies it, and archives that clean bundle before File Provider metadata can alter it. It swaps the visible bundle as a whole rather than overwriting a mapped executable. A running old instance still needs to be quit and reopened. Builds can target arm64, x86_64, or both in a universal binary. Distribution remains ad-hoc signed, not Developer ID signed or notarized.

`scripts/build-dmg.sh` packages a clean app, an Applications shortcut, and installation instructions into a compressed DMG. It verifies the disk checksum, mounts the image read-only, checks the app signature and requested architectures inside it, validates the shortcut, then detaches it. The tag-triggered release workflow tests, builds a universal DMG/ZIP, creates SHA-256 checksums, and publishes the assets using the repository-scoped GitHub Actions token. The version tag must match Info.plist, and an existing release is never clobbered. The private repository’s access controls also apply to downloads.

The 0.3 presentation uses a document-style canvas, separate sidebar/breadcrumb strip, flat task sections, and focused callout blocks. This changes no SQLite schema or stored records. An original vector-generated M icon is copied into the app before signing and declared in Info.plist; the generator and PNG/ICNS assets are included in the repository.

## Validation boundaries

Automated tests cover the complete model/controller workflow with a real SQLite file and an injected notification client, persistence/backup/reopen, legacy migration, denied permission, scheduling failures, rapid edits, database write failure, calendar boundaries, and native AppKit-hosted layouts. Rendered views are inspected in light/dark appearance and with long titles. These are offscreen native hosting checks, not a claim that every macOS interaction was clicked live. Displayed notification delivery, real sleep/wake, VoiceOver, and notarized installation remain manual release checks.
