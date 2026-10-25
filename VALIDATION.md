# Initial validation

Date: 25 October 2026. Platform: Apple Silicon Mac, Xcode 27.0, Swift 6.4 in Swift 5 language mode; deployment target macOS 14.0. A clean macOS 14 machine and Intel hardware have not been tested.

## Automated results

- **14 XCTest tests passed, zero failures**, using both the native and current Swift Build engines. Tests cover daily task limits and rollover, editing/deletion, persistent disk-store reopen, checklist seeding/reset, timezone/DST/year boundaries, reminder time validation, and focus deadlines/pause/resume/serialization/expiry.
- Release executable and `.app` bundle built successfully.
- Clean staging app passed ad-hoc signing and strict signature verification.
- The packaged ZIP was extracted into a fresh temporary folder; the extracted app passed deep, strict signature verification. Its executable is arm64 with macOS 14.0 minimum deployment version.
- `Info.plist` validation, build-script syntax, and whitespace checks passed.

The macOS runner emitted Core Data interprocess notification-registration diagnostics under the restricted tool environment; all assertions, including disk writes and reopening, passed. Compilation/test output was directed to temporary storage because the synced Documents folder adds Finder metadata to generated bundles, which can make codesigning reject them. The build script creates an archive from clean staging before copying the visible app bundle into the checkout.

## Manual checks

Native UI automation timed out when attempting to launch/attach to the app. Live UI inspection and screenshots were not completed. A successful build is not proof of a visually inspected interface. Interactive smoke testing remains a release check.

Notification scheduling is implemented through `UNUserNotificationCenter`; actual permission prompts, displayed banners, denial/re-enable, rapid time changes, and OS Focus behavior have not yet been manually verified. No reminder was intentionally enabled for the user during validation. Sleep/relaunch expiry is covered by clock-based tests; actual Mac sleep/wake remains a manual release check.

## Distribution status

This is a local development build, ad-hoc signed, not notarized. The included archive is for the architecture on which it was built, not a universal binary. Gatekeeper may require the normal user-initiated approval flow when the app is transferred to another Mac. Developer ID signing, notarization, installer packaging, and App Store distribution remain planned.

## Popover sizing correction

A user-supplied screenshot showed the app launched with its header and footer visible but the task/timer region collapsed. The scroll view had a maximum height without a minimum or fixed height, allowing the menu host's compressed sizing pass to hide it. The popover now declares a 424 × 600 pt size and a 400 pt scroll viewport. The redundant external picker label is hidden to leave room for both navigation segments.

An AppKit hosting regression test exercises the real Today view at the containing window's minimum content size. It checks that the task/timer viewport remains usable and the window stays within a laptop-friendly height. This is an automated layout check, not a claim of live interactive verification in the menu bar.

The regression test fails against the previous sizing (205 pt minimum window height and 0 pt viewport) and passes with the correction. The full suite now passes **15 tests, zero failures**. The rebuilt development app is version 0.1.1, build 2.
