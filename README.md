# Momentum

A calm, local-first macOS menu-bar app for choosing your Daily Three, starting a small focus session, and putting the day down at night.

**Native SwiftUI · macOS 14+ · no account · no third-party dependencies**

## Run locally

Requires a Mac with Xcode 15+ (Swift 5.9+) and the macOS SDK. Open `Package.swift` in Xcode to browse/debug the package. For normal use, build the bundled app so notifications have a stable application identity:

```sh
git clone https://github.com/Kavishcan/momentum.git
cd momentum
bash scripts/build-app.sh
open build/Momentum.app
```

Momentum appears in the menu bar, with no Dock icon. Click the half-filled circle. To stop it, choose **Quit** in the popover. Keep the app in the same location while testing notifications. Do not run multiple copies simultaneously.

For an optimized local build: `bash scripts/build-app.sh release`. The script ad-hoc signs the bundle and creates `build/Momentum-macos-arm64.zip` on Apple Silicon (or `x86_64` on Intel). It does not install certificates, request a developer account, notarize, or publish a release. Running the bare executable with `swift run` is not the supported notification workflow.

If a synced folder adds Finder metadata that interferes with app signing, extract the ZIP into a local folder outside that sync service and run the extracted app. The archive is made from a clean, verified staging bundle. To keep compiler output outside a synced checkout, use `MOMENTUM_BUILD_PATH="$TMPDIR/MomentumBuild" bash scripts/build-app.sh release`. Similarly, `swift test --scratch-path "$TMPDIR/MomentumChecks"` keeps test bundles outside the checkout.

## Functional in this initial version

- **Daily Three:** add up to three tasks for the current day; complete/uncomplete, rename, and delete. Completed tasks count toward the limit. New days start empty; prior records stay on disk.
- **Just Start:** choose a daily task or an independent small step, then start 10 or 25 minutes. Pause, resume, or end a session. Remaining time appears in the menu bar while running. Deadline-based state persists through app relaunch and catches up after sleep. Completion stays visible until acknowledged; it does not automatically complete a task.
- **Night Shutdown:** choose a local reminder time (default 22:00), explicitly enable a quiet daily local notification, and use an editable checklist of up to ten steps. Checks survive midnight and reset at noon. Start with three practical steps or replace them with your own.
- **Local persistence:** SwiftData for tasks/checklist, AppStorage/UserDefaults for preferences and the active timer. No server, analytics, account, or cloud sync.
- **Restrained UI:** grayscale surfaces, native controls, system fonts, accessible icon labels, editable sheets, and visible error messages.

Notifications require macOS permission. Enable them from **Night Shutdown → Enable daily reminder**. If denied, allow Momentum in System Settings → Notifications, then reopen the popover. macOS Focus, sleep, and notification settings can silence/delay alerts. Scheduling is implemented; actual delivery depends on the OS. The focus timer has an in-app completion state, not a completion notification.

Momentum supports intentional wind-down. It does **not** block Mac websites/apps or iPhone apps, control Screen Time, or enforce bedtime.

## Tests and documentation

```sh
swift test
```

See [DESIGN.md](DESIGN.md) for the adaptation of the supplied `Pasted text(7).txt` reference, [ARCHITECTURE.md](ARCHITECTURE.md) for storage/lifecycle decisions, and [VALIDATION.md](VALIDATION.md) for verified checks and limits. A macOS GitHub Actions workflow runs tests and builds the bundle.

## Planned, not implemented

History and focus statistics, launch at login, dark appearance, checklist reordering, backup/export/import, keyboard shortcuts beyond native editing/Quit, notification tab deep links, and Developer ID signing/notarization. There is no installer or App Store release.

## Your data

The database is at `~/Library/Application Support/Momentum/Momentum.store` plus its sidecars. Preferences/timer use the `com.kavishcan.momentum` defaults domain. Data stays on your Mac under normal macOS account protections; no extra application-level encryption is provided. Back up the whole store folder while the app is quit. This initial version has no in-app reset/export tool and makes no medical or guaranteed behavior-change claims.
