# Momentum design system · 0.3

Momentum helps someone choose three tasks, start one, and wind down at night. It should feel calm and obvious, with no productivity rankings, streak loss, or shame.

## Direction

The current direction is Notion-inspired: a quiet workspace sidebar, breadcrumb navigation, large document titles, page symbols, flat task blocks, square checkboxes, and subtle callouts. Momentum keeps its own name and original M mark. The earlier `Pasted text(7).txt` reference informs the restraint and spacing, but the new document-like hierarchy takes precedence. System fonts replace proprietary fonts. No downloaded fonts, decorative illustrations, or web views.

The application has a normal main window and Dock presence. All sustained editing happens in that window. The menu-bar panel has quick focus controls, Open Momentum, Night Shutdown, and Quit. A small popover should never be the only way to reach the app.

## Information architecture

| Place | Purpose | Primary actions |
| --- | --- | --- |
| Today | Choose meaningful tasks and begin | Add task, complete, edit, start 10/25 minutes |
| Night Shutdown | Set a reminder and wind down | Toggle reminder, choose time, Save reminder, checklist |
| History | See prior tasks and completed sessions | Choose date, copy a past task into today |
| Settings | Keep local data healthy | Back up, show data folder, check database |

Use explicit text for primary actions. Small row icons are supplementary and receive hover help or accessibility labels. Keep the sidebar in a fixed visual position and mark the selected page using a filled background and accessibility selected state.

## Colors and appearance

A warm near-black palette, using adaptive sRGB tokens in `Theme.swift`. The interface follows macOS light/dark appearance. Native secondary text and control focus rendering remain system-provided.

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| Canvas | `#FFFFFF` | `#191919` | Document area |
| Sidebar | `#F7F7F5` | `#202020` | Workspace navigation |
| Ink | `#37352F` | `#E4E3DF` | Titles, body text, primary buttons |
| Callout surface | `#F7F7F5` | `#222222` | Focus and reminder blocks |
| Selected row | `#EAEAE7` | `#303030` | Active page |
| Hover row | `#EFEFED` | `#292929` | Sidebar pointer feedback |
| Border | `#E8E8E5` | `#343434` | Decorative dividers and callouts |

Borders are low-emphasis decoration, not essential control outlines. Checkbox outlines use readable foreground color. Primary actions invert ink/canvas; secondary focus actions use a thin outline. Selection also uses weight, a breadcrumb, and an accessibility selected state. Native error and destructive-action controls retain their normal behavior.

## Typography

Use SwiftUI system fonts with the platform's script fallback. Sizes are points.

- Page title: 36 pt bold, tracking −0.7 pt; short names such as Today and History.
- Page symbol: 34 pt light, in a 44 pt-high space above the title.
- Workspace name: 14 pt semibold; subtitle: 11 pt.
- Sidebar page links: 13 pt regular, medium when selected.
- Section heading: 15–16 pt semibold; remaining native card headings may use title3.
- Body: 14 pt/native body. Breadcrumb: 12 pt. Nonessential supporting text: 11 pt/native caption.
- Timer: 46 pt light system rounded, monospaced digits; 32 pt in the menu panel.

Long task titles wrap. Titles accept up to 200 characters. A long picker choice may abbreviate, but the active focus block shows its title across multiple lines. Timer updates are not accessibility live announcements.

## Layout and components

- Four-point spacing base; preferred intervals: 4, 8, 12, 16, 18, 24, 28, 32, 48.
- Default main window: 1060 × 760 pt; minimum remains 840 × 620 pt.
- Sidebar: 212 pt wide, compact 34 pt rows, 5 pt selected/hover radius, a Workspace label and local-storage footer.
- Breadcrumb strip: 44 pt high with a functional Refresh action; it stays outside the scrolling document.
- Document padding: 32 pt horizontal, 28 pt top, 48 pt bottom; maximum document width 960 pt.
- Document section gap: 32 pt. Today places a flexible task list beside a 244 pt focus callout with a 28 pt gap.
- Default section blocks are flat, without rounded cards, borders, or colored surfaces. Dividers organize task rows.
- Focus and reminder callouts have 18 pt padding, a 6 pt radius, and a restrained outline.
- Task creation is a plain text-entry row with a plus symbol and explicit Add action; Enter also adds. A full list displays a quiet explanatory line.
- Primary and secondary focus buttons are 40 pt high with 5 pt corners, 14 pt horizontal padding, and 13 pt medium labels.
- Menu panel remains 320 pt wide with finite content-derived height and quick controls only.

At minimum window size, long content can scroll, while navigation remains visible. Content must never collapse to zero height. Validate empty/full task lists, long titles, every timer phase, and both appearances.

## App icon and identity

`Resources/AppIcon.icns` is the packaged Finder/Dock icon, declared by `CFBundleIconFile` and copied before app signing. It contains standard and Retina representations from 16 through 1024 pixels. `Resources/AppIcon.png` is the 1024 px preview.

The icon uses an original geometric M on a black-outlined white sheet with an offset edge and a warm white rounded-square canvas. It uses vector paths, not another product's logo or a proprietary font. The sidebar and compact menu share a matching M mark; the status item uses the native `m.square` symbol. Reproduce the assets with `swift scripts/generate-icon.swift Resources` on macOS.

## Interaction contracts

**Daily Three:** completed tasks count toward the three-task limit. Add clears its field only after a successful database write. The play icon starts a 10-minute session for that task. Editing offers Save, Cancel, and confirmed Delete. Invalid or failed edits remain open with a readable error.

**Focus:** an independent One small step option allows starting without a task. Start, Pause, Resume, End session, and Done reflect actual saved state. Ending an unfinished session asks for confirmation and does not count it as completed. Finishing focus never automatically completes a daily task. Closing the window does not stop the timer.

**Reminders:** the checkbox and time are drafts until Save reminder is pressed. Show an unsaved-changes note. Request OS permission only when saving an enabled reminder. Display scheduling status and errors independently of the saved desired time. Provide Send test and Refresh status. Reminder and completion notifications contain no private task titles.

**Night routine:** checks survive midnight and reset at noon. Editing or deleting a step is explicit. An intentionally empty routine stays empty. Ten steps maximum.

**History:** prior tasks remain on their original day. Add to today makes a new task and respects the current three-task limit. The focus list displays the most recent 100 completed sessions; older records remain in the database.

**Errors and recovery:** never display an unsaved change as successful. Keep input on failure. Startup errors keep existing files and offer Retry, Show data folder, and Quit. Backup completion reports the chosen filename. Do not silently replace a failed database with empty memory storage.

## Accessibility and tone

Use native controls and focus behavior, labeled icon actions, logical reading order, multiline labels, and semantic colors. Return submits task/step entry or saves an edit; Escape cancels an editor. Quit remains accessible in the normal application menu and menu-bar panel. There are no custom animations, so Reduce Motion loses no information.

Automated AppKit hosting checks cover all four pages at minimum size, long titles, empty state in light/dark appearance, and the menu in every timer phase. VoiceOver and full interactive keyboard certification remain manual release checks.

Use “You only need to begin,” “That counts,” and “Rest well.” Avoid punitive messages and guaranteed behavior-change claims. Momentum reminds and supports a routine; it does not block iPhone apps or enforce bedtime.
