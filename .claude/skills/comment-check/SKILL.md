---
name: comment-check
description: Check the comments in a change against the project's commenting standard before calling the work done. Runs Scripts/audit_comments.py over the changed files, then applies the judgment test the script can't. Use at the end of any change that adds, edits, or deletes comments, and after any comment cleanup sweep.
---

# Comment check

Run this before reporting a change complete. It has two halves: a script that catches the
mechanical failures, and a read-through that catches the ones only a reader can.

Passing the script is not passing the check. The script cannot tell whether a comment
earns its place — that is the read-through's job, and it is the half that matters.

## 1. The bar

From `CLAUDE.md`. A comment survives only if it is one of:

1. **A gotcha or workaround** without which the adjacent code looks buggy, arbitrary, or
   baffling: framework bugs, non-obvious ordering or API constraints, external-system
   quirks (TMDB's erratic incremental search, CloudKit `partialFailure`/dedup, JustWatch
   data), non-obvious math, geometry, or time zone handling, a load-bearing magic number.
2. **At most one single-line orientation comment** per file or per type.

Everything else goes: property, parameter, and enum-case docs, "why this exists"
rationale, branch narration, symbol restatements, multi-line file headers.

Survivors are written clinically. No colloquialisms, no idiom, no personification of
views, no filler, no em-dash-stacked clauses. State the mechanism and its consequence in
the plainest available words. Lead with the fact or the imperative.

```swift
// Good: Matches system behavior: glass only becomes visible once content scrolls under the header.
// Bad:  Glass only earns its keep once rows are passing under the field.
```

## 2. Run the script

Scope it to the change, not the whole tree:

```bash
python3 Scripts/audit_comments.py --since HEAD --warnings
```

| Flag | When |
|---|---|
| `--since HEAD` | changed and untracked files (the usual case) |
| `--since <tag-or-sha>` | a change spanning several commits |
| `--files A.swift B.swift` | a couple of known files |
| *(none)* | the configured roots; expect pre-existing debt |
| `--comment-only <ref>` | after a cleanup sweep: assert no code moved |
| `--format xcode` | emit `file:line: error:` diagnostics for a build phase |
| `--list-rules` | what is on, and at what severity |
| `--quiet` | counts only |

Exit status is 1 while any error-level finding stands. **Errors must reach zero.**
Warnings are judgment calls: fix or consciously accept each one, and say which.

### Configuration

Behaviour comes from `.comment-audit.json` at the repo root, so the script is not tied to
this project. Two presets:

- `defects` (the default when no config is present) turns on only the rules that catch
  objective mistakes, so dropping the script into an unconfigured repo stays quiet.
- `strict` turns on everything, for a project whose standard bans member docs and
  narration outright. **This repo uses `strict`.**

Per-rule severity overrides go in `"rules": {"filler": "off"}`. Language settings
(`extensions`, `line_comment_prefixes`, `doc_marker`), the header convention
(`"header": "xcode" | "license" | "none"`), `max_comment_lines`, `density_limit`, and the
`acronyms` allow-list are all config. Adding a project acronym there is the fix for a
bogus `shouty` hit.

### Errors

| Rule | Fix |
|---|---|
| `long-block` | Over `max_comment_lines` (2 here). Cut it down, or delete it. |
| `member-doc` | A doc comment on a property, case, or function. Delete it. If it is a genuine gotcha, keep the fact as a plain `//` note. |
| `header-prose` | The file header carries more prose than allowed. Collapse to one line, or move it onto the type as a single `///` line. Never touch the Xcode header lines themselves. |
| `header-filename` | The header names another file, usually after a rename. Correct the name. |
| `duplicated-fragment` | A rewrite replaced one line and left the old continuation behind. Read the block and finish the edit. |
| `ragged-indent` | A block's lines disagree on indentation. Align them all to the first line. |
| `em-dash` | Re-punctuate into plain clauses: a colon, a semicolon, or two sentences. |

### Warnings

| Rule | What to look for |
|---|---|
| `orphan-start` | Starts mid-sentence. Usually a truncated edit; sometimes a deliberate pair. Make it stand alone. |
| `multi-orientation` | More doc blocks than types. Keep one orientation line each. |
| `shouty` | ALL-CAPS emphasis. Rewrite so the word order carries the weight, or add a real acronym to config. |
| `md-emphasis` | `*word*`. Rewrite. |
| `first-person` | "we", "our", "us". Describe the code, not its authors. |
| `filler` | "just", "simply", "obviously", "clearly". Cut the word; check the sentence still says something. |
| `personify` | Views that "stand down" or "give way". State the mechanism. |
| `glyph` | Arrows and math glyphs. Write the words. |
| `preview-label` | A comment inside `#Preview`. Almost always narration of what the preview shows. Delete unless it records a real constraint (a shared-container collision, a `@Previewable` crash). |
| `dense-file` | Comments exceed the configured share of the code. Sometimes correct — header geometry, CloudKit ordering, the search field's flight. Re-read and confirm each one is load-bearing. |

## 3. Read the surviving comments

The script has no opinion on content. Read every comment the diff adds or keeps:

```bash
git diff -U3 -- '*.swift' | grep -E '^[+-].*//'
```

For each one, apply the test: **would the code look wrong or arbitrary without this
note?** If no, cut it. Bias to remove when unsure.

Watch for the ones that pass every mechanical rule and still fail the bar:

- Restates the symbol. `// The user's star rating` above `var rating: Double?`.
- Narrates the next line. `// Fetch the show, then reconcile.`
- Explains a language feature rather than this code's reason for using it.
- Describes the visible mechanic instead of the constraint behind it. "Cancel belongs to
  the bar" says what you can see; "a control drawn beneath chrome never sees the tap" says
  why.
- Documents a parameter or a return value. That is what the signature is for.
- Correct but unreadable: two subordinate clauses and a dash. Rewrite as two sentences.

Also confirm nothing load-bearing was **lost**. When a sweep removes a note that carried
real context — an external-system quirk, a measured constant, a rule that took tuning —
that context belongs somewhere durable, not in the bin. `Source/Search/SearchPolicies.md`
is the precedent: the search ranking rules live there because the code cannot state them.

## 4. Verify

```bash
python3 Scripts/audit_comments.py --since HEAD    # 0 errors
python3 Scripts/find_long_comments.py .           # 0 blocks of 3+ lines
```

Then build, because a mangled comment block can swallow code:

- `BuildProject` — must succeed.
- For a comment-only sweep, `--comment-only <ref>` must report the code byte-identical.
  If it names a file you did not intend to touch, another agent's work is in it: leave
  that file out of your commit rather than carrying their change.

## 5. Report

State the counts and the judgment calls, not a narrative:

```
Comments: 0 errors, 3 warnings (2 preview labels deleted, 1 dense file confirmed
load-bearing: CollapsingBackdropHeader geometry).
Read 14 added/kept comments; cut 4 restatements. Build green.
```

If you accepted a warning, say which and why. If you moved context into a doc rather
than deleting it, name the doc.
