# Comment cleanup plan

Handoff doc. The project carries far more comments than its own standard allows. This is the
plan to bring the whole tree to that standard.

## The bar

A comment survives ONLY if it is one of:

- **(a) a gotcha/workaround** without which the adjacent code would look buggy, arbitrary or
  baffling to a competent reader — framework bugs, non-obvious ordering/API constraints,
  external-system quirks, non-obvious math/geometry/timezone, or a load-bearing magic number.
- **(b) at most ONE short single-line orientation comment per file OR per type** — a terse
  "what this is" line. Never a multi-line purpose paragraph.

Everything else goes: property/var/param/enum-case docs, "what X represents / why X exists"
rationale, branch and body narration, symbol restatements, multi-line file-header prose.

Test to apply per comment: **would the code look wrong or arbitrary without this note?** If no,
cut it. Bias to remove when unsure.

Survivors must also be **rewritten in plain declarative prose**: lead with the fact or the
imperative, then the consequence. No clever compression, no em-dash-stacked clauses, ≤2 lines.

## Measured starting state (2026-08-17)

| | |
|---|---|
| Overall density | 11.1% — 1759 comment lines / 15806 code lines, 229 files |
| `///` docs on properties, enum cases, funcs | 403 lines in 141 files — cut outright |
| File-header prose past the 4-line Xcode header | 103 lines — collapse to ≤1 line |
| Inline `//` comments | 602 lines — mixed; the real gotchas live here, needs judgment |

Highest-density files to start with (density, comment lines, code lines):

```
100%   4    4  Source/Search/Tools/SearchTool.swift        (done, use as reference)
 86%   6    7  Persistence/Store/ShowProgress.swift        (done, use as reference)
 67%  10   15  Persistence/Store/ListResult.swift          (done, use as reference)
 56%   5    9  Source/Search/SearchResults.swift
 50%  16   32  Source/Search/SearchContext.swift
 44%   4    9  Source/Search/Tools/RankMoviesTool.swift
 36%   4   11  App/UITestHooks.swift
 31%  33  107  Views/Details/Common/CollapsingBackdropHeader.swift   (mostly protected — geometry)
 30%  20   66  Source/Representations/Show.swift
 28%  13   46  Source/Search/Tools/FranchiseCollectionTool.swift
 27%  22   81  Source/Representations/EpisodeCredit.swift
 26%  90  345  Persistence/Store/PersistenceCoordinator+TV.swift    (partly protected — CloudKit)
```

## Method

Two passes. Do the mechanical one first across the tree, then the judgment one.

**Pass 1 — mechanical, near-zero risk.** The 403 property/case/func docs and the 103 lines of
header prose. A `///` line whose content merely names its symbol is a delete. Collapse each file
header to the bare 4 Xcode lines, optionally followed by one `///` orientation line on the main
type.

**Pass 2 — judgment.** The 602 inline comments, file by file. These carry the notes worth
keeping. Protected categories, do not delete without reading the code carefully:

- CloudKit: `partialFailure`, dedup/convergence, schema-drift notes
- TMDB: erratic search behaviour, per-endpoint payload gaps, credit ordering
- JustWatch / streaming availability quirks
- SwiftData: `@Query` and `ModelContext` constraints, main-actor rules, preview-container crashes
- Geometry and time: pan clamps, safe-area/nav-bar interplay, UTC-midnight / `floatingDay`
- SwiftUI framework constraints: `matchedGeometryEffect` single-source, glass/`glassEffect`
  behaviour, toolbar item layout, identity breaks that reset state
- Numbers that were **measured** rather than chosen (e.g. `DetailSearchBar`'s metrics) — the note
  that stops someone rounding them is load-bearing

## Order of work

One commit per area so each stays reviewable:

1. `Source/` — representations, search tools, responses
2. `Persistence/` — coordinator, cache, transfer
3. `Views/Structure/` + `Views/Extensions/`
4. `Views/Lists/`
5. `Views/Details/`
6. `Views/Search/` + `Views/Featured/`
7. `Views/Shared/` + `Views/Settings/`
8. `MarqueeTests/` + `UITests/`

## Guardrails

- **Check `git status` first.** Other agents work in this tree. Skip any file with uncommitted
  changes that aren't yours; revisit after they land.
- **Comment-only diffs.** No code changes in these commits, so review is trivial and a regression
  is impossible by construction.
- **Never delete** `// MARK:` markers or the 4-line Xcode file header.
- **Classify every comment in a file**, don't just collect deletions — a sweep that only reports
  what it cut silently leaves survivors. Report kept-vs-cut per file.
- Build after each area; the tree must stay green.

## Verification

Re-measure density at any time:

```python
import os
tot_c = tot_k = 0
for root, _, files in os.walk("MovieTracker"):
    for f in files:
        if not f.endswith(".swift"): continue
        lines = open(os.path.join(root, f)).read().splitlines()
        body = lines[4:] if lines and lines[0].startswith("//") else lines
        tot_c += sum(1 for l in body if l.strip().startswith("//"))
        tot_k += sum(1 for l in body if l.strip() and not l.strip().startswith("//"))
print(f"{tot_c}/{tot_k} = {tot_c/tot_k:.1%}")
```

Also run `python3 ~/Desktop/find_long_comments.py` — it must report 0 blocks of 3+ lines.

Target: single-digit density overall, and no file where comments outnumber a third of its code.

## Worked examples

Header prose collapsed — `Source/Search/Tools/SearchTool.swift`:

```diff
-//  One composable step of a SearchPolicy. A tool augments the working set —
-//  fetching more candidates, filtering noise, reordering, or extracting people —
-//  and returns the updated context. Order in the policy's tool list is meaningful.
+/// One step of a `SearchPolicy`, applied in list order.
```

Property docs cut, load-bearing half of the type doc kept — `Persistence/Store/ShowProgress.swift`:

```diff
 /// A show's tracking state, answerable from persisted facts alone. Deriving it from
 /// `Show.regularSeasons` instead needs the payload, so controls read wrong until it lands.
 struct ShowProgress: Equatable {
-    /// Every aired season complete.
     var isWatched = false
-    /// On the Watch List.
     var isTracked = false
```

Comment explained the visible mechanic instead of the reason — `DetailSearchHost.swift`:

```diff
-// Cancel belongs to the bar, where the system puts its own: a control of ours drawn
-// beneath chrome never sees the tap.
+// Ours rather than a system item because the field's position is measured
+// from it, which needs a glyph size we set.
 ToolbarItem(placement: .topBarTrailing) { … }
```

Correct but unreadable — same file:

```diff
-// Left standing, only emptied. Hiding the bar shrinks the safe area, and these pages
-// measure their collapsing headers against it — the page reflows 44pt the moment it goes.
+// Don't hide the bar. That shrinks the safe area, and the movie and show headers lay
+// themselves out from it, so they jump 44pt.
```

## Do not

- Add comments. This is a subtractive task.
- Touch code, formatting or names.
- Expand a surviving doc comment into something longer or more explanatory.
- Assume a `///` is safe because it is grammatical — most of the 403 are restatements.
