#!/usr/bin/env python3
"""Audit source comments against a project's commenting standard.

Mechanical checks only. A comment can pass every check here and still deserve to be
cut: whether it is a real gotcha is a judgment call the reader has to make.

    python3 Scripts/audit_comments.py                     # configured roots
    python3 Scripts/audit_comments.py --since HEAD         # only what you changed
    python3 Scripts/audit_comments.py --files A.swift       # specific files
    python3 Scripts/audit_comments.py --comment-only HEAD   # assert no code moved
    python3 Scripts/audit_comments.py --format xcode        # Xcode-parsable diagnostics
    python3 Scripts/audit_comments.py --list-rules          # rules and current severity

Configuration lives in `.comment-audit.json`, searched for upward from the working
directory. Without one, the `defects` preset runs: only the rules that catch objective
mistakes, so dropping this into an unconfigured project stays quiet. Run --list-rules
to see what is on. Exit status is 1 when any error-level finding is reported.
"""

import argparse
import json
import os
import re
import subprocess
import sys
from collections import Counter, defaultdict

CONFIG_NAME = ".comment-audit.json"

# Objective defects: a rule here fires only on something that is wrong in any codebase.
PRESET_DEFECTS = {
    "duplicated-fragment": "error",
    "orphan-start": "warn",
    "ragged-indent": "warn",
}

# Everything, for a project whose standard bans member docs and narration outright.
PRESET_STRICT = {
    "long-block": "error",
    "member-doc": "error",
    "header-prose": "error",
    "header-filename": "error",
    "duplicated-fragment": "error",
    "ragged-indent": "error",
    "em-dash": "error",
    "orphan-start": "warn",
    "multi-orientation": "warn",
    "shouty": "warn",
    "md-emphasis": "warn",
    "first-person": "warn",
    "filler": "warn",
    "personify": "warn",
    "glyph": "warn",
    "preview-label": "warn",
    "dense-file": "warn",
}

PRESETS = {"defects": PRESET_DEFECTS, "strict": PRESET_STRICT}

RULE_HELP = {
    "long-block": "comment spans too many lines",
    "member-doc": "doc comment on a property, case, or function",
    "header-prose": "more than the allowed prose lines in the file header",
    "header-filename": "file header names a different file",
    "duplicated-fragment": "repeated wording: a truncated edit was left behind",
    "ragged-indent": "comment block's lines disagree on indentation",
    "em-dash": "em dash: state the mechanism in plain clauses",
    "orphan-start": "starts mid-sentence: possibly a truncated continuation",
    "multi-orientation": "more doc blocks than types",
    "shouty": "ALL-CAPS emphasis",
    "md-emphasis": "*markdown* emphasis",
    "first-person": "first person: describe the code, not the author",
    "filler": "filler word",
    "personify": "personification",
    "glyph": "arrow or math glyph in prose",
    "preview-label": "comment inside a preview block: usually narration",
    "dense-file": "comments exceed the configured share of the file's code",
}

DEFAULTS = {
    "preset": "defects",
    "rules": {},
    "roots": ["."],
    "extensions": [".swift"],
    "skip_dirs": [".git", ".build", "DerivedData", "Pods", "build", ".swiftpm",
                  "node_modules", "vendor", "Carthage"],
    "modules": [],
    "acronyms": [],
    "header": "none",                  # none | xcode | license
    "license_pattern": r"(?i)copyright|licen[sc]e|SPDX-",
    "max_header_prose": 1,
    "max_comment_lines": 2,
    "density_limit": 0.34,
    "min_code_lines_for_density": 15,
    "preview_markers": ["#Preview", "PreviewProvider"],
    "doc_marker": "///",
    "line_comment_prefixes": ["//"],
}

BUILTIN_ACRONYMS = {
    "API", "APIS", "CI", "CD", "CLI", "CPU", "CSS", "CSV", "DB", "DNS", "DTO", "DTOS",
    "DST", "GMT", "GPU", "GUI", "HTML", "HTTP", "HTTPS", "ID", "IDS", "IO", "IP", "JSON",
    "JPEG", "JWT", "LF", "CRLF", "MARK", "TODO", "FIXME", "NOTE", "OS", "PDF", "PNG",
    "RAM", "REST", "RFC", "RGB", "SDK", "SQL", "SSL", "TCP", "TLS", "TTL", "TV", "UI",
    "URI", "URL", "URLS", "UTC", "UUID", "XML", "YAML", "HZ", "PT", "PX", "US", "SF",
}

MEMBER_DECL = re.compile(
    r'^\s*(?:@[\w:.()"\s]+\s*)*'
    r'(?:public |private(?:\(set\))? |fileprivate |internal |open |static |class |final |lazy '
    r'|weak |unowned |nonisolated |mutating |override |required |convenience |dynamic |indirect '
    r'|export |declare |const |readonly |@\w+\s+)*'
    r'(?P<kw>var|let|case|func|init|subscript|typealias|associatedtype|def|function|fn)\b')

TYPE_DECL = re.compile(r'^\s*(?:@\w+\s+)*(?:public |private |fileprivate |internal |open |final '
                       r'|indirect |export |abstract )*'
                       r'(?:struct|class|enum|protocol|actor|extension|interface|trait|impl)\b')

FILLER = re.compile(r'\b(just|simply|basically|obviously|actually|really|clearly|of course|'
                    r'sort of|kind of|a bit|nice|clever|neat|magical)\b', re.I)
FIRST_PERSON = re.compile(r"(?<![\w`])(?:[Ww]e(?:'re|'d|'ve)?|[Oo]urs?|us|I)\b")
PERSONIFY = re.compile(r'\b(earns? its keep|stands? down|gives? way|wants? to|knows? about|'
                       r'is happy|likes? to|refuses? to|tries? to|decides? for itself|'
                       r'on purpose|politely|happily)\b', re.I)
GLYPHS = {"→": "->", "↔": "to", "⇒": "=>", "×": "x", "≥": ">=", "≤": "<="}
def marker_re(prefixes):
    alts = "|".join(re.escape(p) + "+" for p in sorted(prefixes, key=len, reverse=True))
    return re.compile(rf'^\s*(?:{alts})\s*')


def load_config(explicit, start="."):
    path = explicit
    if not path:
        here = os.path.abspath(start)
        while True:
            candidate = os.path.join(here, CONFIG_NAME)
            if os.path.exists(candidate):
                path = candidate
                break
            parent = os.path.dirname(here)
            if parent == here:
                break
            here = parent
    cfg = dict(DEFAULTS)
    if path and os.path.exists(path):
        with open(path, encoding="utf-8") as handle:
            cfg.update(json.load(handle))
        cfg["_path"] = path
    severities = dict(PRESETS.get(cfg.get("preset", "defects"), PRESET_DEFECTS))
    severities.update(cfg.get("rules", {}))
    cfg["_severity"] = {k: v for k, v in severities.items() if v != "off"}
    cfg["_acronyms"] = BUILTIN_ACRONYMS | {a.upper() for a in cfg.get("acronyms", [])}
    cfg["_prefixes"] = tuple(cfg["line_comment_prefixes"])
    cfg["_marker"] = marker_re(cfg["_prefixes"])
    return cfg


class Finding:
    __slots__ = ("path", "line", "end", "rule", "text", "severity")

    def __init__(self, path, line, end, rule, text, severity):
        self.path, self.line, self.end = path, line, end
        self.rule, self.text, self.severity = rule, text, severity

    def where(self):
        return f"{self.path}:{self.line}" + (f"-{self.end}" if self.end != self.line else "")


class Auditor:
    def __init__(self, cfg):
        self.cfg = cfg
        self.severity = cfg["_severity"]
        self.findings = []
        self.stats = Counter()

    def on(self, rule):
        return rule in self.severity

    def add(self, path, line, end, rule, text):
        if self.on(rule):
            self.findings.append(Finding(path, line, end, rule, text, self.severity[rule]))

    # -- helpers ---------------------------------------------------------
    def is_comment(self, line):
        return line.strip().startswith(self.cfg["_prefixes"])

    @staticmethod
    def indent_of(line):
        return len(line) - len(line.lstrip())

    def uncomment(self, line):
        """Strip the comment marker only. Stripping every leading slash would eat the
        first character of a path such as /search/movie."""
        return self.cfg["_marker"].sub("", line).strip()

    def block_text(self, lines, a, b):
        return " ".join(self.uncomment(l) for l in lines[a:b]).strip()

    def header_span(self, lines):
        i = 0
        while i < len(lines) and self.is_comment(lines[i]):
            i += 1
        return i

    def next_code_line(self, lines, start):
        for j in range(start, len(lines)):
            s = lines[j].strip()
            if s and not s.startswith(self.cfg["_prefixes"]):
                return s
        return ""

    def comment_blocks(self, lines, from_line):
        i = from_line
        while i < len(lines):
            if self.is_comment(lines[i]):
                a = i
                while i < len(lines) and self.is_comment(lines[i]):
                    i += 1
                yield a, i
            else:
                i += 1

    def preview_ranges(self, lines):
        markers = self.cfg["preview_markers"]
        spans, i = [], 0
        while i < len(lines):
            if any(m in lines[i] for m in markers):
                depth, started, j = 0, False, i
                while j < len(lines):
                    depth += lines[j].count("{") - lines[j].count("}")
                    if "{" in lines[j]:
                        started = True
                    if started and depth <= 0:
                        break
                    j += 1
                spans.append((i, j))
                i = j + 1
            else:
                i += 1
        return spans

    @staticmethod
    def words_of(text):
        return re.findall(r"[\w']+", text.lower())

    def repeated_phrase(self, lines, a, b):
        """The truncation artifact: a rewrite replaced line one and left line two behind,
        so a continuation line re-states wording that already appeared above it."""
        prior = ""
        for idx in range(a, b):
            head = " ".join(self.words_of(self.uncomment(lines[idx]))[:3])
            if idx > a and head and head in prior:
                return head
            prior += " " + " ".join(self.words_of(self.uncomment(lines[idx])))
        tokens = self.words_of(self.block_text(lines, a, b))
        seen = set()
        for i in range(len(tokens) - 4):
            gram = " ".join(tokens[i:i + 5])
            if gram in seen:
                return gram
            seen.add(gram)
        return None

    # -- the audit -------------------------------------------------------
    def audit_file(self, path):
        try:
            lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
        except OSError:
            return
        if not lines:
            return
        basename = os.path.basename(path)
        mode = self.cfg["header"]
        head_end = self.header_span(lines) if mode in ("xcode", "license") else 0

        if head_end and mode == "license" and re.search(self.cfg["license_pattern"],
                                                        "\n".join(lines[:head_end])):
            pass  # a license block is not the project's prose to police
        elif head_end and mode == "xcode":
            names_file, prose = False, []
            for idx in range(head_end):
                body = self.uncomment(lines[idx])
                if not body:
                    continue
                if body == basename:
                    names_file = True
                elif body in self.cfg["modules"]:
                    continue
                elif body.startswith("Created by") or body.startswith("Copyright"):
                    continue
                else:
                    prose.append((idx + 1, body))
            if not names_file:
                self.add(path, 1, head_end, "header-filename",
                         f"header does not name {basename}")
            if len(prose) > self.cfg["max_header_prose"]:
                self.add(path, prose[0][0], prose[-1][0], "header-prose",
                         f"{len(prose)} prose lines, limit {self.cfg['max_header_prose']}")

        previews = self.preview_ranges(lines)
        doc_marker = self.cfg["doc_marker"]
        max_lines = self.cfg["max_comment_lines"]
        doc_blocks = comment_lines = 0

        for a, b in self.comment_blocks(lines, head_end):
            text = self.block_text(lines, a, b)
            comment_lines += b - a
            stripped = lines[a].strip()
            is_doc = stripped.startswith(doc_marker)
            if is_doc:
                doc_blocks += 1
            if re.match(r'\s*MARK\b', self.cfg["_marker"].sub(" ", stripped)):
                continue
            line, end = a + 1, b

            if max_lines and b - a > max_lines:
                self.add(path, line, end, "long-block", f"{b - a} lines, limit {max_lines}")
            indents = {self.indent_of(l) for l in lines[a:b]}
            if len(indents) > 1:
                self.add(path, line, end, "ragged-indent", f"indents {sorted(indents)}")
            if is_doc and MEMBER_DECL.match(self.next_code_line(lines, b)):
                self.add(path, line, end, "member-doc", text[:100])
            dup = self.repeated_phrase(lines, a, b)
            if dup:
                self.add(path, line, end, "duplicated-fragment", f'repeats "{dup}"')

            first_word = re.match(r"[\w'.]+", text)
            looks_like_code = bool(first_word) and (
                re.search(r'[A-Z]', first_word.group(0)[1:])
                or re.match(r'^[\w.]+[`(\[:.]', text)
                or first_word.group(0) in {"nil", "true", "false", "self", "nonisolated",
                                           "async", "await", "throws", "guard", "where",
                                           "let", "var", "func", "if", "else", "def", "return"})
            if text and (text[0] in "—–…),;" or (text[0].islower() and not looks_like_code)):
                self.add(path, line, end, "orphan-start", text[:90])
            if "—" in text:
                self.add(path, line, end, "em-dash", text[:100])
            for glyph, plain in GLYPHS.items():
                if glyph in text:
                    self.add(path, line, end, "glyph", f'"{glyph}" -> write "{plain}"')
                    break
            for word in re.findall(r'\b[A-Z][A-Z]{2,}\b', text):
                if word not in self.cfg["_acronyms"]:
                    self.add(path, line, end, "shouty", word)
                    break
            if re.search(r'(?<!\w)\*\w[\w ]*\*(?!\w)', text):
                self.add(path, line, end, "md-emphasis", text[:80])
            for rule, pattern in (("first-person", FIRST_PERSON), ("filler", FILLER),
                                  ("personify", PERSONIFY)):
                hit = pattern.search(text)
                if hit:
                    self.add(path, line, end, rule, f'"{hit.group(0)}"')
            if any(lo <= a <= hi for lo, hi in previews):
                self.add(path, line, end, "preview-label", text[:80])

        code_lines = sum(1 for l in lines[head_end:]
                         if l.strip() and not l.strip().startswith(self.cfg["_prefixes"]))
        types = sum(1 for l in lines if TYPE_DECL.match(l))
        if doc_blocks > max(types, 1):
            self.add(path, 1, 1, "multi-orientation",
                     f"{doc_blocks} doc blocks for {types} type(s)")
        limit = self.cfg["density_limit"]
        if limit and code_lines >= self.cfg["min_code_lines_for_density"] \
                and comment_lines > code_lines * limit:
            self.add(path, 1, 1, "dense-file",
                     f"{comment_lines}/{code_lines} = {comment_lines / code_lines:.0%}")
        self.stats["comments"] += comment_lines
        self.stats["code"] += code_lines


def source_files(roots, cfg):
    exts, skip = tuple(cfg["extensions"]), set(cfg["skip_dirs"])
    for root in roots:
        if os.path.isfile(root):
            if root.endswith(exts):
                yield root
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in skip]
            for name in sorted(filenames):
                if name.endswith(exts):
                    yield os.path.join(dirpath, name)


def changed_files(ref, cfg):
    def run(*args):
        return subprocess.run(args, capture_output=True, text=True).stdout.split()
    out = set(run("git", "diff", "--name-only", ref))
    out |= set(run("git", "diff", "--name-only", "--cached", ref))
    out |= set(run("git", "ls-files", "--others", "--exclude-standard"))
    exts = tuple(cfg["extensions"])
    return sorted(f for f in out if f.endswith(exts) and os.path.exists(f))


def comment_only(ref, paths, prefixes):
    def bare(text):
        return [l.rstrip() for l in text.splitlines()
                if l.strip() and not l.strip().startswith(prefixes)]
    offenders = []
    for path in paths:
        old = subprocess.run(["git", "show", f"{ref}:{path}"], capture_output=True, text=True)
        if old.returncode:
            offenders.append((path, "new file"))
        elif bare(old.stdout) != bare(open(path, encoding="utf-8", errors="replace").read()):
            offenders.append((path, "code changed"))
    return offenders


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("roots", nargs="*", help="paths to scan (default: configured roots)")
    ap.add_argument("--config", metavar="PATH", help=f"config file (default: nearest {CONFIG_NAME})")
    ap.add_argument("--since", metavar="REF", help="only files changed against REF, plus untracked")
    ap.add_argument("--files", nargs="+", help="scan exactly these files")
    ap.add_argument("--comment-only", metavar="REF", help="assert the change touches no code")
    ap.add_argument("--format", choices=("text", "xcode"), default="text")
    ap.add_argument("--warnings", action="store_true", help="list warn-level findings too")
    ap.add_argument("--quiet", action="store_true", help="summary lines only")
    ap.add_argument("--list-rules", action="store_true", help="print rules and severities")
    args = ap.parse_args()

    cfg = load_config(args.config)

    if args.list_rules:
        print(f"config: {cfg.get('_path', '(built-in defaults)')}")
        print(f"preset: {cfg.get('preset')}\n")
        for rule in sorted(RULE_HELP):
            print(f"  {cfg['_severity'].get(rule, 'off'):>5}  {rule:<20} {RULE_HELP[rule]}")
        return 0

    if args.files:
        targets = args.files
    elif args.since:
        targets = changed_files(args.since, cfg)
    else:
        targets = args.roots or cfg["roots"]
    targets = [t for t in targets if os.path.exists(t)]
    if not targets:
        print("Nothing to audit.")
        return 0

    auditor = Auditor(cfg)
    paths = sorted(set(source_files(targets, cfg)))
    for path in paths:
        auditor.audit_file(path)

    errors = [f for f in auditor.findings if f.severity == "error"]
    warns = [f for f in auditor.findings if f.severity == "warn"]

    if args.format == "xcode":
        for f in errors + warns:
            level = "error" if f.severity == "error" else "warning"
            print(f"{os.path.abspath(f.path)}:{f.line}: {level}: "
                  f"[{f.rule}] {RULE_HELP[f.rule]}: {f.text}")
        return 1 if errors else 0

    if not args.quiet:
        for label, group in (("ERROR", errors), ("WARN", warns if args.warnings else [])):
            by_rule = defaultdict(list)
            for f in group:
                by_rule[f.rule].append(f)
            for rule in sorted(by_rule, key=lambda r: -len(by_rule[r])):
                print(f"\n{label}  {rule} — {RULE_HELP[rule]}  ({len(by_rule[rule])})")
                for f in by_rule[rule]:
                    print(f"  {f.where()}  {f.text}")

    stats = auditor.stats
    print(f"\n{len(paths)} files audited, {stats['comments']}/{stats['code']} comment/code lines"
          + (f" = {stats['comments'] / stats['code']:.1%}" if stats["code"] else ""))
    print(f"{len(errors)} error(s), {len(warns)} warning(s)"
          + ("" if args.warnings else "  (--warnings to list warnings)"))

    if args.comment_only:
        offenders = comment_only(args.comment_only,
                                 [p for p in paths if not os.path.isabs(p)], cfg["_prefixes"])
        if offenders:
            print(f"\nNot a comment-only change against {args.comment_only}:")
            for path, why in offenders:
                print(f"  {path}  ({why})")
        else:
            print(f"\nComment-only against {args.comment_only}: code is byte-identical.")

    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
