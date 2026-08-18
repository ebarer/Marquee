#!/usr/bin/env python3
"""Find comments (line or block) that span 3+ lines in Swift source files."""

import argparse
import os
import re
import sys

LINE_COMMENT_RE = re.compile(r'^\s*//')


def is_boilerplate_header(lines, start, end, filename):
    """Detect the standard Xcode file header, e.g.:
    //
    //  MediaList.swift
    //  MovieTracker
    //
    Only applies to a comment block at the very top of the file.
    """
    if start != 0:
        return False
    block = [l.strip() for l in lines[start:end]]
    if len(block) < 2:
        return False
    filename_re = re.compile(r'^//\s*' + re.escape(filename) + r'\s*$')
    return any(filename_re.match(l) for l in block[:3])


def find_swift_files(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [
            d for d in dirnames
            if d not in ('.git', '.build', 'DerivedData', 'Pods')
            and not d.endswith('Tests') and not d.endswith('UITests')
        ]
        for name in filenames:
            if name.endswith('.swift') and 'Tests' not in name:
                yield os.path.join(dirpath, name)


def find_long_comments(path, min_lines):
    with open(path, encoding='utf-8', errors='replace') as f:
        lines = f.readlines()

    filename = os.path.basename(path)
    results = []
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]
        stripped = line.strip()

        # Consecutive // line comments
        if LINE_COMMENT_RE.match(line):
            start = i
            while i < n and LINE_COMMENT_RE.match(lines[i]):
                i += 1
            length = i - start
            if length >= min_lines and not is_boilerplate_header(lines, start, i, filename):
                results.append((start + 1, i, length))
            continue

        # /* ... */ block comments (non-nested, simple scan)
        idx = stripped.find('/*')
        if idx != -1 and not stripped.startswith('//'):
            start = i
            end_idx = line.find('*/', line.find('/*') + 2)
            j = i
            while end_idx == -1 and j + 1 < n:
                j += 1
                end_idx = lines[j].find('*/')
            end = j
            length = end - start + 1
            if length >= min_lines:
                results.append((start + 1, end + 1, length))
            i = end + 1
            continue

        i += 1

    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', nargs='?', default='.', help='Project root to scan')
    parser.add_argument('--min-lines', type=int, default=3, help='Minimum comment length (default: 3)')
    args = parser.parse_args()

    root = os.path.abspath(args.root)
    total = 0
    RED = '\033[31m'
    RESET = '\033[0m'
    for path in sorted(find_swift_files(root)):
        for start, end, length in find_long_comments(path, args.min_lines):
            rel = os.path.relpath(path, root)
            line = f'{rel}:{start}-{end} ({length} lines)'
            if length >= 5:
                line = f'{RED}{line}{RESET}'
            print(line)
            total += 1

    print(f'\n{total} comment block(s) with {args.min_lines}+ lines', file=sys.stderr)


if __name__ == '__main__':
    main()
