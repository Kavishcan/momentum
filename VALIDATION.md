# Momentum validation

Date: 1 November 2026. Local platform: Apple Silicon, Xcode 27.0 / Swift 6.4 in Swift 5 language mode. Deployment target: macOS 14.0.

## Automated coverage

The suite contains 35 tests: 27 core tests and 8 interface/controller/workflow tests. The opt-in actual-store migration test runs only when a local store path is supplied; CI skips that test and uses the synthetic SwiftData migration fixture.

Local result: **35 passed, zero failures**, including the opt-in snapshot of the existing store. Version 0.2.0 was built in release mode; the ZIP was extracted into a fresh temporary folder and passed deep/strict signature verification. The executable links the system SQLite library. No live user database was replaced during testing.

- Task add/edit/complete/delete, three-task cap including completed tasks, and parameterized text containing SQL syntax.
- Database trigger protection across separate connections; invalid/missing input and unsupported schema versions.
- Read-only write failures retain published state and do not falsely start/end a timer.
- Task, routine/checks, preferences, and active session persistence through reopening a real SQLite file.
- Day rollover, noon night boundary, timezone, DST, and year boundary.
- Focus start/pause/resume/expiry, serialization, exactly-once completed history, real completion timestamp, and immediate recovered history on relaunch.
- A complete workflow through tasks, focus, shutdown checks, reminder enable/disable, SQLite backup, and reopening the backup.
- Notification authorization denial, startup restoration without prompting, scheduling failures/retry, rapid edits converging to the latest setting, and test requests through a fake OS client.
- Consistent backups containing committed WAL data, standalone read-only reopening, and integrity checks.
- Transactional SwiftData/defaults migration, rollback/idempotence, retained original store, and a locally supplied isolated snapshot of the previous user store.
- AppKit-hosted layouts for all four pages at minimum window size with long titles; idle/running/paused/finished menu dimensions; empty Today in light/dark appearance.

The actual-store check uses an isolated SQLite snapshot and does not replace the user's existing database. It exposed a WAL-header backup portability issue that the synthetic fixture did not; standalone backups now explicitly finalize in DELETE journal mode. The SwiftData working copy is disposable, allowing Core Data to create journal metadata without mutating the original or durable snapshot.

## Visual checks

Native offscreen AppKit renderings of Today, Night Shutdown, History, and Settings were generated and inspected. Minimum-size content remains scrollable and nonzero. Long titles wrap. The empty Today view exposes task entry and both start durations without requiring an existing task. Light and dark renderings retain readable controls. Renderings use test data, not user task content.

## Checks and limits

The release bundle and ZIP are built by `scripts/build-app.sh`; the clean staged bundle is verified with deep/strict codesigning. The deliverable archive is extracted into a fresh temporary directory for verification. Plist, script syntax, and diff whitespace checks are also run.

Live desktop automation is unavailable for reliable interactive verification in this session. Displayed notification banners, actual OS permission dialogs, real sleep/wake, VoiceOver, and global keyboard interaction have not been manually certified. OS notification behavior can be silenced by Focus and system preferences. The development build is ad-hoc signed and not notarized; Intel hardware and a fresh macOS 14 installation have not been exercised locally.

The old 0.1 implementation passed narrower core tests but suffered a collapsed popover layout. Version 0.2 adds a normal main window, keeps the menu compact, unifies app state in SQLite, and expands testing to cover persistence failures, migration, and cross-feature workflows. Passing tests do not imply the remaining OS-level checks were completed.

## Version 0.3 visual update

The interface was restyled toward a Notion-inspired document workspace. All 35 existing checks passed again, including the isolated legacy migration case. Updated native renderings were inspected in light/dark appearance, with long task titles and at minimum window size. No database schema or persistence logic changed.

The original M icon was generated from Core Graphics paths and packaged as a multi-resolution ICNS file, with a 1024 px PNG preview. Icon generation was completed using the standard macOS icon tools. The app bundle is verified after packaging, including its declared icon resource. Live Dock/Finder icon refresh depends on closing the older app instance and reopening the rebuilt bundle.
