# Momentum 0.3.0

A local-first macOS app for Daily Three tasks, 10/25-minute focus sessions, and a calmer Night Shutdown.

## Downloads

- **Momentum-macos-universal.dmg** — recommended installer for Apple Silicon and Intel Macs.
- **Momentum-macos-universal.zip** — the same app without a disk image.
- **SHA256SUMS** — checksums for both downloads.

Requires **macOS 14 or later**. Download release assets from the links on this page or the repository README.

## Install or update

Quit the old Momentum first. Open the DMG, drag Momentum.app into Applications, and open it from there. Existing local tasks and settings are retained; the database lives separately in Application Support. Eject the disk image after copying the app.

This is an **ad-hoc signed development build, not notarized by Apple**. macOS may require explicit user approval in System Settings. No Developer ID distribution signing or App Store release is claimed.

## Included

- A Notion-inspired document workspace, light/dark appearance, and original M app icon.
- Daily Three task editing/completion, focus pause/resume/recovery, and completed-session history.
- Configurable Night Shutdown reminders and an editable evening checklist.
- A local SQLite database, migration of previous app data, integrity checking, and consistent backups.

Automated tests cover database workflows, migration, timer recovery, reminder scheduling logic, and native layouts. The installer contains both architectures; Intel hardware and OS-controlled notification delivery have not been manually verified locally.
