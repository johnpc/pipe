#!/usr/bin/env python3
"""Enforce a minimum line-coverage threshold over the app's source files.

Reads an xccov JSON report and sums executable/covered lines for the `pipe`
app target only (test targets excluded). Fails below THRESHOLD percent.

Usage:
    xcrun xccov view --report --json TestResults.xcresult > coverage.json
    python3 scripts/coverage_check.py coverage.json
"""
import json
import sys

THRESHOLD = 80.0


def main(path: str) -> int:
    with open(path) as f:
        data = json.load(f)

    total_lines = 0
    covered_lines = 0
    per_file = []
    for target in data.get("targets", []):
        name = target.get("name", "")
        if "Tests" in name or "UITests" in name:
            continue
        if "pipe" not in name:
            continue
        for file in target.get("files", []):
            ex = file.get("executableLines", 0)
            cov = file.get("coveredLines", 0)
            total_lines += ex
            covered_lines += cov
            if ex > 0:
                per_file.append((file.get("name", ""), cov / ex * 100, cov, ex))

    pct = (covered_lines / total_lines * 100) if total_lines else 0.0

    per_file.sort(key=lambda r: r[1])
    print("Per-file coverage (lowest first):")
    for fname, fpct, cov, ex in per_file:
        flag = "⚠️ " if fpct < THRESHOLD else "   "
        print(f"  {flag}{fname:<32} {fpct:5.1f}%  ({cov}/{ex})")

    print(f"\nTotal coverage: {pct:.1f}% ({covered_lines}/{total_lines} lines)")
    if pct < THRESHOLD:
        print(f"❌ FAIL: Coverage {pct:.1f}% is below {THRESHOLD:.0f}% threshold")
        return 1
    print(f"✅ PASS: Coverage {pct:.1f}% ≥ {THRESHOLD:.0f}%")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: coverage_check.py <coverage.json>", file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
