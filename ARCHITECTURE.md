# Architecture

## Scope and platform

Momentum 0.1 is a macOS 14+ SwiftUI menu-bar utility. It has no server, account, analytics, advertising SDK, network client, web view, or cloud entitlement. Swift Package Manager builds two modules without third-party dependencies. `scripts/build-app.sh` places the executable in a real `.app` bundle with a stable identifier and `LSUIElement`, then ad-hoc signs it for local use.

The native entry point uses Apple's [MenuBarExtra window style](https://developer.apple.com/documentation/swiftui/menubarextra). The app deliberately has no Dock icon or main document window. Open the menu-bar symbol to interact; Quit is in the footer.

## Modules and data flow

```text
MomentumApp
  ├─ ModelContainer (disk, CloudKit disabled)
  │    └─ MomentumStore (@MainActor, ObservableObject)
  │         ├─ DailyTask (@Model)
  │         └─ RoutineStep (@Model)
  ├─ FocusController → FocusSession → UserDefaults
  └─ ReminderService → UNUserNotificationCenter
       ↑
MomentumRoot / TodayView / NightView → explicit actions
       └─ @AppStorage → reminder enabled + local time
```

`MomentumCore` contains models, calendar rules, persistence actions, and the pure timer state machine. The executable module contains views, app lifetime, the timer's ticking adapter, and OS notification integration. Tests target the core independently of UI and notification permission.

## Persistence

| State | Storage | Reason |
| --- | --- | --- |
| Daily task UUID, title, day key, created time, completion | SwiftData | Structured durable records |
| Routine step UUID, title, position, last completed night key | SwiftData | Editable checklist with durable completion |
| Routine default-seeding marker | UserDefaults | Seed once; an intentionally empty checklist remains empty |
| Timer phase, task title snapshot, duration, deadline, paused remainder | Codable data in UserDefaults | Small single active session |
| Reminder enabled, hour, minute | AppStorage / UserDefaults | Small preferences shared with UI |

The SwiftData store is explicitly located at `~/Library/Application Support/Momentum/Momentum.store` (with SQLite sidecars). Defaults belong to the bundle domain `com.kavishcan.momentum`. The [model container](https://developer.apple.com/documentation/swiftdata/modelcontainer) is configured with `cloudKitDatabase: .none`. This is local storage, protected by normal macOS account and disk protections; there is no additional application-level encryption or export UI.

`MomentumStore` uses a dedicated main-actor context with autosaving disabled. Actions save explicitly. Save errors roll back and surface a message; fetch failures surface a message. Store-open errors keep the existing files and show a failure view. No destructive automatic recovery or silent in-memory fallback.

The schema is initial/unversioned. Future structural changes require an explicit schema and migration plan before distribution. Historic tasks remain on disk; v0.1 only displays today's records. Routine completion stores the latest checked night only, not a history of all nights.

## Calendar semantics

Task keys are Gregorian `yyyy-MM-dd` in the Mac's current timezone, independent of UI language. The view refreshes while open and on app activation/timezone change. Midnight starts an empty Daily Three; old tasks are not deleted or automatically carried forward.

A night is noon through the following noon. This keeps a 00:30 wind-down in the preceding evening and avoids resetting a half-finished routine at midnight. Calendar date arithmetic handles DST; it does not subtract a fixed 86,400 seconds. Changing timezone can change which day/night is displayed; records keep their original keys. Night reminder time may be set to any local hour; the checklist boundary remains noon.

## Focus lifecycle

`FocusSession` is a deterministic, Codable value type with idle/running/paused/finished phases. Start accepts 10 or 25 minutes, snapshots the task title, and stores an absolute deadline. Remaining time is derived from the deadline, rather than decrementing a counter.

`FocusController` owns one app-lifetime ticking task. Closing the popover does not stop it. Ticks update UI and persist only a finished transition. Start/pause/resume/reset also persist. On relaunch an elapsed deadline becomes finished. Pause stores a remainder; resume creates a new deadline. System wall-clock changes affect the deadline, an accepted v0.1 limitation. There are no session statistics, automatic breaks, focus completion notifications, or enforcement mechanisms.

## Reminder lifecycle

`ReminderService` requests notification authorization only from the Enable action. One repeating local calendar trigger uses the stable identifier `momentum.night-shutdown`. Its date components omit a fixed timezone. Reconfiguring removes/replaces that identifier; disabling removes it. Changes are serialized so asynchronous OS calls cannot leave an older schedule after a newer one. Permission status is checked before adding requests.

macOS owns delivery. User Focus modes, notification preferences, sleep, and shutdown can suppress or delay alerts. A successful scheduling call is not proof of a displayed banner. The OS retains scheduled reminders when the app exits. The foreground delegate permits a quiet banner/list entry, with no sound. Tapping a reminder launches/activates the app; automatic opening of a particular tab is not implemented.

## Validation and remaining work

Core tests cover the three-task cap, completion/edit/delete, daily rollover, disk reopen, checklist reset/default seeding, timezone/DST boundaries, reminder time validation, and timer pause/resume/serialization/expiry. CI builds and tests on a macOS runner.

Manual release checks: OS notification delivery and denial/re-enable flows; actual sleep/wake; keyboard-only use and VoiceOver; long content and small displays; repeated rapid reminder changes; clean macOS 14 installation. The initial delivery records actual local checks separately in `VALIDATION.md`.

Deferred: history UI, custom dark mode, launch at login, signed/notarized distribution, backup/export/import, reordering checklist steps, notification deep links, global shortcuts, app/site blocking. iPhone app blocking is outside this Mac-only application's capabilities.
