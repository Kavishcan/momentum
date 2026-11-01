# Contributing to Momentum

Thanks for helping make Momentum calmer, clearer, and more dependable. Useful contributions include reproducible bug reports, focused fixes, accessibility feedback, documentation, and release testing.

## Start with the user need

Check [existing issues](https://github.com/Kavishcan/momentum/issues) before opening a new one. For a larger feature, explain the problem and proposed interaction first so the direction can be discussed before implementation. Keep pull requests small enough to review as one coherent change.

For vulnerabilities, follow [SECURITY.md](SECURITY.md) rather than opening a public report. For usage questions, see [SUPPORT.md](SUPPORT.md).

## Development setup

Use a Mac running macOS 14+, with Xcode 15+ / Swift 5.9+ and the macOS SDK. SQLite comes from the system SDK; no database server or third-party package installation is required. `Package.swift` can be opened in Xcode.

```sh
git clone https://github.com/Kavishcan/momentum.git
cd momentum
swift test --scratch-path "$TMPDIR/MomentumTests"
bash scripts/build-app.sh debug
open build/Momentum.app
```

The bundled app provides the application identity needed for notification testing. Running the bare executable is not the supported notification workflow.

### Keep personal data safe

Local app builds share the installed app's bundle identifier and `~/Library/Application Support/Momentum/` folder. They are not a separate developer installation. Quit other Momentum copies and create a backup before running experimental app changes against personal data. Automated tests use temporary databases and fake notification clients; they should not need access to a contributor's real tasks.

Do not commit databases, migration snapshots, personal task text, private logs, credentials, or signing material. Use synthetic data in screenshots and reproduction cases.

## Where code lives

| Path | Responsibility |
| --- | --- |
| `Sources/Momentum/` | SwiftUI pages, app/window lifecycle, menu panel, timer adapter, and OS notification client |
| `Sources/MomentumCore/` | SQLite repository, value records, timer/calendar rules, legacy import, and reminder coordination |
| `Sources/CSQLite/` | Module map for the system SQLite library |
| `Tests/MomentumCoreTests/` | Database, migration, calendar, timer, and reminder scheduling tests |
| `Tests/MomentumInterfaceTests/` | Native hosting/layout checks and complete controller workflows |
| `Resources/` | Bundle metadata and original app icon |
| `scripts/` | App/icon generation and DMG packaging |

Read [ARCHITECTURE.md](ARCHITECTURE.md) for persistence/lifecycle decisions and [DESIGN.md](DESIGN.md) for UI conventions.

## Implementation expectations

- Keep the app native and local-first. Explain any proposed permission, network dependency, or background service before adding it.
- Preserve the Daily Three cap, including completed tasks. Database constraints and other entry points must agree with the UI.
- Use bound SQLite parameters, explicit transaction boundaries, and errors that leave the previous saved state intact. A failed disk store must not silently become an empty memory store.
- Protect upgrades: test migration changes against fixtures, preserve originals, and keep an import idempotent. Do not reset someone's data as a shortcut to resolving an error.
- Keep timer deadlines/remainders durable, and completed history unique. Closing a window, sleeping, and relaunching have different lifecycle implications.
- Keep notification permission opt-in. Saved desired settings and actual scheduling status must remain distinguishable; OS delivery is not guaranteed by a successful API call.
- Follow the existing document-style UI. Keep labels and keyboard behavior clear, use system fonts, support light/dark appearance, and label icon-only controls.
- Regenerate the original icon with `swift scripts/generate-icon.swift Resources` if its vector source changes. Do not substitute another app's branding.

## Validation

For documentation-only changes, check the diff, Markdown links, image paths, and YAML where applicable. Do not rebuild the app solely for wording changes.

For code changes, run the tests relevant to the behavior; run the full suite and build the app before a merge that affects shared behavior or UI. Useful commands:

```sh
swift test --scratch-path "$TMPDIR/MomentumTests"
swift test --scratch-path "$TMPDIR/MomentumTests" --filter WorkflowTests
bash scripts/build-app.sh release
bash scripts/build-dmg.sh universal
```

Tests should demonstrate the behavior, including legitimate failure/recovery paths. For a regression, show that the test catches the original problem where feasible. Do not replace useful behavior checks with assertions against private source text.

For UI, notifications, accessibility, or sleep/wake changes, state what you actually verified, your macOS version/architecture, and what remains untested. Offscreen hosting and compilation do not certify a live interaction. Update [VALIDATION.md](VALIDATION.md) when the validation scope changes.

The opt-in actual-store migration check is for local diagnosis using an isolated snapshot. CI uses a synthetic migration fixture; normal contributors should not need to supply personal data.

## Pull requests

Use a clear title describing the resulting change. Explain:

- The user-visible problem and behavior after the change.
- Any storage, migration, permission, or lifecycle effects.
- The checks you ran and their results; add synthetic screenshots for visual changes.
- Related issues and any remaining limitations.

A [pull-request template](.github/PULL_REQUEST_TEMPLATE.md) is included. Open unfinished work as a draft. Do not promise a release date or mark an unverified OS behavior as tested.

## Releases for maintainers

Pushing source or merging a PR does not publish a download. Publishing requires an intentional version-tag push.

1. Validate the intended commit and confirm CI passes.
2. Match `Resources/Info.plist`, release notes, and the intended `vX.Y.Z` tag.
3. Create a new tag without moving an existing published tag.
4. Push it to start [.github/workflows/release.yml](.github/workflows/release.yml).
5. Confirm the release actually published with its DMG, ZIP, and checksums.

The release job builds/tests the project, checks the app/tag version, creates and verifies a universal installer, and uploads assets with GitHub's workflow token. Current builds are ad-hoc signed and not notarized. Do not claim Developer ID signing or notarization without implementing and verifying that separate process. Do not replace existing release assets or publish a tag as part of an unrelated documentation change.
