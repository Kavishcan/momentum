# Momentum design system · 0.2

Momentum helps someone choose three tasks, start one, and wind down at night. It should feel calm and obvious, with no productivity rankings, streak loss, or shame.

## Direction

The supplied `Pasted text(7).txt` remains the reference for restrained Asana-inspired grayscale, whitespace, and measured typography. Momentum adapts those principles to native macOS instead of reproducing a marketing website. System fonts replace proprietary TWK Lausanne. No downloaded fonts, gradients, decorative illustrations, or web views.

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

Use semantic system colors so the app follows macOS light/dark appearance and system contrast preferences. The light reference values below express the visual intent; the system resolves actual values at runtime.

| Token | Light intent | Implementation |
| --- | --- | --- |
| Canvas | Near-white / `#FFFFFF` | `NSColor.windowBackgroundColor` |
| Surface | Quiet neutral surface | `NSColor.controlBackgroundColor` |
| Ink | Charcoal / near `#0D0E10` | `Color.primary` |
| Secondary | Readable neutral gray | `Color.secondary` |
| Border | Low-emphasis separator | Primary at 12% opacity; decorative only |
| Primary action | Ink fill, contrasting canvas text | Semantic foreground/background inversion |

Do not use muted text for essential state by itself: combine icons, labels, or text such as Paused and Complete. Destructive controls use native styling and a confirmation dialog. Native fields, toggles, buttons, pickers, and focus rings retain platform rendering. There is no custom saturation-based status system.

## Typography

Use SwiftUI system fonts with the platform's script fallback. Sizes are points.

- Page heading: 30 pt semibold.
- App name in sidebar: 18 pt semibold.
- Card heading: native title3, semibold.
- Body and controls: native body/callout; native control metrics.
- Supporting text: native caption, limited to nonessential detail.
- Timer: 46 pt light system rounded, monospaced digits; 32 pt in the menu panel.

Long task titles wrap naturally. Titles accept up to 200 characters. The task picker may abbreviate long choices; the active timer displays the selected title in multiple lines. Do not announce timer updates every second through accessibility live regions.

## Layout

- Four-point base spacing; preferred steps: 4, 8, 12, 16, 20, 24, 28, 32, 48.
- Main window defaults to 980 × 720 pt; minimum 840 × 620 pt.
- Sidebar: 188 pt including padding. Main content scrolls independently.
- Main page padding: 28 pt. Section gap: 26 pt. Adjacent cards: 20 pt.
- Cards: 24 pt internal padding, 18 pt internal gaps, 16 pt radius, light decorative outline.
- Today places Daily Three beside a 272 pt focus card. The minimum window reserves enough width for both.
- Menu panel: 320 pt wide, content-derived finite height, 20 pt padding. It contains no long forms or large scrolling workflow.
- Primary buttons: at least 40 pt high, 18 pt horizontal padding, 8 pt radius.

At the minimum window size long content may scroll; it must never collapse to zero height or hide the route back to another page. Test full and empty lists and every timer phase.

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
