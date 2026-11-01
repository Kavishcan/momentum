# Troubleshooting Momentum

Start with the [latest release](https://github.com/Kavishcan/momentum/releases/latest). Momentum requires macOS 14+, and the published universal installer contains Apple Silicon and Intel builds.

## Install and launch

Open the DMG, quit an older Momentum copy, and drag Momentum.app to Applications. Launch the copied app from Applications, then eject the disk image. This avoids running multiple copies or leaving the application on a mounted installer.

The current version opens a normal window and appears in the Dock. The M-square menu-bar item also has **Open Momentum** and **Quit Momentum**. After updating, quit and reopen so the running process loads the new version and icon.

### macOS won't open the app

Current releases are ad-hoc signed development builds and have not been notarized by Apple. Review the source/release information and use macOS's normal approval flow if you choose to open the download. See [Apple's guide to safely opening apps](https://support.apple.com/en-us/102445).

Do not disable Gatekeeper or other system-wide protections to install Momentum. If the app still will not launch, include the exact macOS message and app version in a [bug report](https://github.com/Kavishcan/momentum/issues/new/choose).

## Windows and focus

Closing the window keeps the app running and the timer available in the menu bar. Use Open Momentum or the Dock to return to the window. Quitting preserves the active deadline or paused remainder; relaunching catches up if the deadline elapsed.

Pause preserves the remaining time. End session stops an unfinished session after confirmation; it does not count as a completed session. Finishing a focus session does not automatically check off a task.

## Reminders

1. Open **Night Shutdown**.
2. Turn on **Remind me to wind down**, choose a time, and press **Save reminder**.
3. Allow the macOS notification request. If previously denied, enable Momentum under System Settings → Notifications.
4. Use **Refresh status**, then **Send test**. The test is requested for five seconds later.
5. Check Focus mode, notification display settings, and whether the Mac is asleep.

The status distinguishes saved preferences from actual scheduling. If scheduling failed, correct the problem and refresh. Notifications are controlled by macOS and can be suppressed or delayed. The checklist works without notification permission.

Night checks reset at noon rather than midnight. A checked item after midnight still belongs to the previous evening.

## Local data and recovery

The active database is `~/Library/Application Support/Momentum/momentum.sqlite`. Use **Settings → Show data folder** to reveal it and **Check database** to request an integrity check. An error should be reported instead of silently replacing the database with empty storage.

Before experimenting with recovery, quit Momentum and preserve the entire existing data folder, including its sidecars and migration snapshots. Avoid copying only a running database's main file; use the app's backup action where possible.

To restore a known-good app backup:

1. Quit Momentum.
2. Move the entire existing `Momentum` Application Support folder aside and keep it.
3. Create a fresh `Momentum` folder in the same location.
4. Copy the selected backup into the new folder as `momentum.sqlite`.
5. Reopen Momentum and check your tasks, routine, and history before discarding anything.

A failed legacy import keeps the originals. Keep both old/new data files and report the error message privately if it reveals personal information. Do not attach those files to a public issue.

## Still stuck?

See [SUPPORT.md](../SUPPORT.md) for a useful bug report. Security concerns go through [SECURITY.md](../SECURITY.md).
