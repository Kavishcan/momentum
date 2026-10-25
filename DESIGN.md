# Momentum design system

Momentum is a quiet place to choose three meaningful tasks, begin one, and wind down at night. Its interface should reduce the effort needed to take the next step. It should never turn rest into a score, or a missed day into a failure.

## Reference and adaptation

Based on the user-supplied `Pasted text(7).txt`, an Asana-inspired reference with restrained grayscale, generous whitespace, soft containers, and short transitions. This is an adaptation for a compact native macOS utility, not a copy of Asana or an assertion of affiliation.

The reference has conflicting surface/text names, type sizes, and 4-versus-8-unit grid descriptions. Momentum resolves those explicitly: dark body text on light surfaces, a 4-point grid with mostly 8-point intervals, native controls, and a compact type hierarchy. Proprietary TWK Lausanne is neither bundled nor required. There are no web breakpoints or marketing-page hero styles.

## Colors

All values are sRGB. Implementation lives in `Sources/Momentum/Theme.swift`.

| Token | Value | Use |
| --- | --- | --- |
| Canvas | `#FFFFFF` | Popover background |
| Surface | `#F3F3F3` | Quiet section cards |
| Ink | `#0D0E10` | Body text, headings, checkbox outlines |
| Muted | `#535C65` | Supporting copy, counts, completed task text |
| Primary | `#646F79` | Primary button fill and native tint |
| On primary | `#FFFFFF` | Primary button labels |
| Border | `#D2D2D2` | Optional decorative separators; never the only control boundary |

Calculated WCAG contrast: ink/canvas 19.31:1; ink/surface 17.40:1; muted/canvas 6.80:1; muted/surface 6.13:1; white/primary 5.13:1. The decorative border is only 1.51:1 on white and is unsuitable for essential control outlines. Native input borders and focus indicators retain platform behavior.

The first version intentionally uses a light appearance, including when the Mac is in dark mode. A separate dark palette is planned; do not approximate it by inverting individual colors. Destructive actions retain native system styling. Completion uses a checkmark and text, not a green status color.

## Typography

Use SwiftUI `.system` / San Francisco via macOS, with the system's own fallback for other scripts. No downloaded fonts. Sizes below are points, not CSS pixels.

| Role | Size / weight | Use |
| --- | --- | --- |
| App title | 24 / medium | Momentum heading |
| Night prompt | 24 / regular | “Land the day.” |
| Section title | 18 / medium | Daily Three, Just Start, routine |
| Body | 14 / regular | Tasks, instructions, fields |
| Button | 14 / medium | Begin, resume, enable reminder |
| Supporting | 12 / regular | Reminder state, reset explanation |
| Footer | 11 / regular | Nonessential closing line |
| Timer | 48 / light, system rounded | Remaining time; monospaced digits |

Use natural multiline layout and default native line heights. Do not tighten tracking. Long task titles wrap; saved titles are limited to 200 characters. The focus title may truncate after three lines. The timer is readable at a glance without decorative progress animation.

## Layout and spacing

- Base unit: 4 pt. Preferred scale: 4, 8, 12, 16, 20, 24, 32, 48, 64.
- Popover: 424 × 600 pt; 24 pt outer padding; 20 pt between major groups. Explicit dimensions prevent a menu host's minimum-size measurement from collapsing the contents.
- Header: title and date on the left; a single monochrome symbol on the right.
- Two native segmented tabs: Today and Night Shutdown.
- Content scrolls within a 400 pt viewport, keeping the header and Quit control reachable on a typical laptop display. The navigation picker hides its redundant external label so both segments fit.
- Cards: 20 pt padding, 16 pt internal spacing, no heavy shadow or nested dashboard panels.
- Rows: 8 pt horizontal gaps. Checkbox hit areas are 32 × 36 pt; edit/select targets are 28 × 32 pt. These are mouse-oriented macOS targets, not a claim of universal 44 pt touch compliance.
- Primary buttons: minimum 40 pt height, 16 pt horizontal padding. Native field and secondary button metrics remain native.

## Radius and elevation

- 4 pt: reserved for dense details if introduced.
- 8 pt: primary buttons and small containers.
- 20 pt: major section cards.
- 64 pt: reference-only; unused in this compact utility.

The OS owns the menu extra's exterior shape and elevation. Cards use a light fill, without stacked shadows. Do not add gradients, glass effects, oversized pills, or floating decorative elements.

## Components

**Daily Three:** three slots maximum, including completed tasks. A labeled input and Add action appear while space remains. Each task has a checkmark toggle, choose-for-focus action, and edit action. Editing supports save, cancel, and confirmed deletion. No empty demo tasks are inserted.

**Just Start:** a native task picker, an independent “One small step” option, and two equally weighted 10/25-minute start actions. A running session shows its task snapshot, clock, Pause, and End session. Paused and finished states have explicit text. Finishing never automatically checks a task off.

**Night reminder:** a native time picker and an explicit enable action. Permission is requested only after that action. Display disabled, denied, scheduled, and failure states in plain language. The reminder is quiet and contains no task titles.

**Night checklist:** three practical defaults, editable titles, additions up to ten steps, explicit deletion, and a count. Checks persist across midnight and reset at noon. Completion receives one quiet sentence, without confetti, streaks, or a score.

**Errors:** local save failures appear in an alert and the attempted change rolls back. Store-open failures retain the existing files and show a recovery message. Never silently replace a failed disk store with disposable memory storage.

## Interaction and motion

- Prefer native button, picker, text-entry, sheet, and dialog behavior.
- Return submits a new task/step; Return saves an edit, Escape cancels an edit, Command-Q quits.
- Hover help names icon actions; VoiceOver receives a label for every icon-only control.
- Preserve keyboard focus rings. Do not hide focus to achieve visual minimalism.
- The reference's 100/200/300 ms ease-in-out timing is a ceiling for future custom transitions, not a requirement to animate every action. V0.1 adds no custom animation, so Reduce Motion introduces no lost information.
- No automatic tab switching, coercive countdowns, punitive messages, global keyboard interception, sleep prevention, or focus stealing.
- Timer deadlines continue during sleep and app closure; paused time does not. An expired session is reconciled on wake/relaunch. Completion is visible in the app and menu icon; it does not play a sound or send a focus notification.

## Accessibility and language

Meet at least 4.5:1 for normal text and 3:1 for essential graphics/control indicators. Use checkmarks, shapes, labels, and counts in addition to tone. Expose timer text as an accessibility value without announcing every second. Keep content in visual/reading order and allow multiline labels. Test the popover with Full Keyboard Access, VoiceOver, increased contrast, and long titles before a distribution release. These are release checks, not claims of completed certification.

Use calm, concrete language: “You only need to begin”, “That counts”, “Rest well”. Avoid “failed”, “lazy”, streak loss, productivity rankings, and claims of medical benefit. Momentum can remind and support a routine. It cannot enforce bedtime or block iPhone apps.
