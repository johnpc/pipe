#!/usr/bin/env python3
"""CRAP score analysis for the pipe app.

CRAP = complexity^2 * (1 - coverage)^3 + complexity

Reads an xccov JSON report (produced by `xcrun xccov view --report --json`),
computes per-function cyclomatic complexity by counting real decision points in
the function's source span, and fails if any function exceeds the threshold.

Why count decision points instead of `lines / N`: SwiftUI view `body` getters
are long but flat (declarative view trees with almost no branching). A
line-count proxy mislabels them as highly complex and produces false CRAP
failures even at 100% coverage. Counting actual branches (if/guard/switch/for/
while/&&/||/?:/catch) measures the cyclomatic complexity CRAP is defined on.

Usage:
    xcrun xccov view --report --json TestResults.xcresult > coverage.json
    python3 scripts/crap_check.py coverage.json [SOURCE_ROOT]
"""
from __future__ import annotations

import json
import re
import sys

CRAP_THRESHOLD = 15
MIN_LINES = 5  # Skip trivial accessors/wrappers where complexity is just noise.

# Tokens that each add one independent path (McCabe cyclomatic complexity).
DECISION_RE = re.compile(
    r"\b(if|guard|for|while|case|catch)\b|&&|\|\||\?\?|(?<![?\w])\?(?!\?)"
)


def complexity_for_span(lines: list[str]) -> int:
    """1 + number of decision points found in the source span."""
    decisions = 0
    for line in lines:
        # Strip trailing line comments to avoid counting tokens in prose.
        code = line.split("//", 1)[0]
        decisions += len(DECISION_RE.findall(code))
    return 1 + decisions


def crap(complexity: int, coverage: float) -> float:
    return complexity ** 2 * (1 - coverage) ** 3 + complexity


def load_source(path: str, cache: dict) -> list[str] | None:
    if path not in cache:
        try:
            with open(path) as f:
                cache[path] = f.read().splitlines()
        except OSError:
            cache[path] = None
    return cache[path]


def main(path: str) -> int:
    with open(path) as f:
        data = json.load(f)

    source_cache: dict = {}
    results = []

    for target in data.get("targets", []):
        name = target.get("name", "")
        if "Tests" in name or "UITests" in name:
            continue
        for file in target.get("files", []):
            file_path = file.get("path", "")
            if "/pipe/pipe/" not in file_path:
                continue
            if "Tests/" in file_path or "DerivedData" in file_path or "SourcePackages" in file_path:
                continue
            fname = file_path.split("/")[-1]
            src = load_source(file_path, source_cache)

            funcs = sorted(file.get("functions", []), key=lambda fn: fn.get("lineNumber", 0))
            for i, func in enumerate(funcs):
                lines = func.get("executableLines", 0)
                if lines < MIN_LINES:
                    continue
                covered = func.get("coveredLines", 0)
                cov = covered / lines if lines > 0 else 0.0

                # Determine source span: this function's start to the next one's.
                if src is not None:
                    start = func.get("lineNumber", 1) - 1
                    end = funcs[i + 1].get("lineNumber", len(src) + 1) - 1 if i + 1 < len(funcs) else len(src)
                    complexity = complexity_for_span(src[start:end])
                else:
                    complexity = max(1, lines // 3)

                score = crap(complexity, cov)
                results.append((func.get("name", ""), fname, cov * 100, complexity, lines, score))

    results.sort(key=lambda r: -r[5])
    total = len(results)
    avg = sum(r[5] for r in results) / total if total else 0.0
    over = [r for r in results if r[5] > CRAP_THRESHOLD]

    print(f"Analyzed {total} functions. Average CRAP: {avg:.1f}")
    print("\nTop 10 highest CRAP:")
    for name, fname, cov, cx, lines, score in results[:10]:
        print(f"  {fname}: {name[:42]:<42} CRAP={score:6.1f}  cx={cx:<3} cov={cov:5.1f}%")

    if over:
        print(f"\n❌ FAIL: {len(over)} function(s) exceed CRAP {CRAP_THRESHOLD}:")
        for name, fname, cov, cx, lines, score in over:
            print(f"  {fname}: {name[:48]} CRAP={score:.1f} (complexity={cx}, cov={cov:.0f}%)")
        return 1

    print(f"\n✅ PASS: All functions ≤ CRAP {CRAP_THRESHOLD}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: crap_check.py <coverage.json>", file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
