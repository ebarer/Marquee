# Marquee — working agreements

## Comments

A comment survives only if it is one of:

1. A gotcha or workaround without which the adjacent code looks buggy, arbitrary, or baffling — framework bugs, non-obvious ordering or API constraints, external-system quirks (TMDB's erratic incremental search, CloudKit `partialFailure`/dedup, JustWatch data), non-obvious math, geometry, or time zone handling, a load-bearing magic number.
2. At most **one** single-line orientation comment per file or per type.

Remove everything else: property, parameter, and enum-case docs, "why this exists" rationale, branch narration, symbol restatements, multi-line file headers. Test: *would the code look wrong or arbitrary without this note?* If no, cut it. Bias to remove.

Write survivors clinically. No colloquialisms, no idiom, no personification of views, no filler words, no em-dash-stacked clauses. State the mechanism and its consequence in the plainest available words. Lead with the fact or the imperative.

```swift
// Good: Matches system behavior: glass only becomes visible once content scrolls under the header.
// Bad:  Glass only earns its keep once rows are passing under the field.
```

No comment may span three or more lines. Run `python3 Scripts/find_long_comments.py .` before finalizing; expect zero findings.

## Architecture

- Engine and pure logic live under `Source/`. View models stay beside their views under `Views/`.
- All persistence goes through `PersistenceCoordinator`. Views never touch `ModelContext` directly.
- Never block a frame: no SwiftData access in `body`, no writes inside a tap handler, nothing heavy on the main actor.
- Prefer native components — `Menu`, `Picker`, `alert`, `NavigationLink` rows — over hand-rolled equivalents.
- Derive behavior from the data source rather than hardcoding cases; validate the mechanism against live data first.
- Complex views get their own file plus previews for each state. Small enums and primitives may share a file.
- Move files with the Xcode MCP tools (`XcodeMV`, `XcodeMakeDir`, `XcodeRM`) so the pbxproj stays correct.

## SwiftUI

- Every UI change ships with an in-canvas preview, and visual changes are rendered and inspected before being called done.
- `@Previewable` with `@Query` crashes ("No eligible connection available"). Use a `.constant` binding in the preview.
- Async detail screens preview through a seeded model: `model.preview` plus `init(preview:model:)`.
- `RemoteImage` resolves bundled sample art in previews via sentinel names in `Assets.xcassets/Preview/`.
- Section headers use `SectionHeaderMetrics`, which mirrors `UIListContentConfiguration.plainHeader()`: 17pt semibold, 10pt above and below, text inset 16pt. Grid layouts pass their wider gutter. Do not re-invent per-context metrics.
- A store tick or tint change landing mid-push kills a list row's press highlight. Keep row views `Equatable` and out of the store's revision path.

## Data model

- Changing a `@Model` requires updating `SchemaPrimer` in the same edit, then deploying the CloudKit production schema. Production schema drift is silent and breaks sync.
- TV list membership tracks the next incomplete season. Watched holds completed seasons only; marking an episode watched auto-adds the show to the Watch List.

## Copy and presentation

- Say "title" / "titles" for counts and "Movies & TV" for scope. Not "movie".
- Canonical list order: Watch List, Watched, custom lists, Viewed. Watched is turquoise everywhere.

## Verification

- `BuildProject` after changes; `RenderPreview` for anything visual; `RunCodeSnippet` to interrogate framework values rather than guessing them.
- A dyld failure naming `libSystem.B.dylib` with "no dyld cache" is a wedged simulator, not a link error. Shut the device down and let Xcode reboot it.
- Tests use Swift Testing (`MarqueeTests`) and XCUIAutomation (`MarqueeUITests`), configured by `Scripts/configure_test_targets.rb`.

## Commits

- Lead the message with user-facing changes; internal work last.
- Include the build number and tag the commit with it, e.g. `... (Build 2026.8.18.1)` + tag `2026.8.18.1`. The number is `CURRENT_PROJECT_VERSION` in the pbxproj.
- Stage `TODO.md` edits alongside the work.
