# Privacy and local data

Momentum is a local-first Mac app. Using its tasks, timer, and shutdown checklist does not require an app account or a cloud service.

## What is saved

The database at `~/Library/Application Support/Momentum/momentum.sqlite` contains:

- Task titles, local day keys, completion state, and creation times.
- Routine step titles and the nights when they were checked.
- Reminder settings.
- The active focus session and completed-session history, including task-title snapshots.

SQLite may create `-wal` and `-shm` sidecars while the app is running. Earlier versions used `Momentum.store` and UserDefaults; the upgrade keeps the original store/preferences and a migration snapshot. These retained copies can contain previous information even after later records are changed in the current app.

SQLite adds no application-level encryption here. Normal macOS account permissions and disk protections apply. Treat the data folder and exported backups as personal information.

## Network use

The app has no analytics, tracking, automatic cloud sync, app login, or automatic updater. Normal task/timer/checklist use is local. Downloads and links you open to GitHub, project documentation, sponsorship information, or email use the services you choose to visit; their own policies apply.

## Notifications and permissions

Notification permission is requested when an enabled reminder is saved. It is optional: tasks, focus sessions, and the checklist remain usable without granting it.

Reminder and focus-completion notifications use generic text, not your task titles. They are local requests delivered under macOS notification and Focus settings. A successful scheduling call does not guarantee that a visible banner will appear.

Momentum does not request Accessibility, Screen Recording, Contacts, or microphone permissions for its current features. It does not block iPhone apps, control Screen Time, or monitor other applications' content.

## Backups and sharing

Use **Settings → Create database backup** to export a consistent SQLite snapshot. A backup includes private records and preferences; keep it somewhere you trust. Automatic legacy snapshots remain in `MigrationBackups` under the data folder.

For support, prefer reproduction steps, fake task titles, and redacted screenshots/logs. Do not attach a personal database to a public issue. If a private diagnostic file is needed, agree on its contents and transfer method with the maintainer first.

Deleting the application does not automatically remove its Application Support folder or your exported backups. For restore instructions, see [troubleshooting](TROUBLESHOOTING.md#local-data-and-recovery). For vulnerabilities, see [SECURITY.md](../SECURITY.md).
