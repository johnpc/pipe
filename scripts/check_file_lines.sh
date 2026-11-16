#!/usr/bin/env bash
# Enforce the 300-line limit on ALL Swift source files (views, logic, stores).
#
# The limit is a proxy for "one file, one purpose", not a target: a file that
# approaches it is doing more than one job and should be split along a
# responsibility boundary (a subview, a pure helper, a Type+Feature.swift
# extension) — never trimmed to squeak under. 300 leaves room for a complete,
# well-commented type so cuts aren't arbitrary; it still catches the unruly
# file that has grown several concerns.
#
# Exemptions: none in pipe/. Generated/declarative files would be skipped here
# if any existed.
set -euo pipefail

MAX=300
FAILED=0
echo "Checking all source files for line count > $MAX..."

while IFS= read -r file; do
  LINES=$(wc -l < "$file" | tr -d ' ')
  if [ "$LINES" -gt "$MAX" ]; then
    echo "❌ $file: $LINES lines (max $MAX)"
    FAILED=1
  fi
done < <(find pipe -name "*.swift")

if [ "$FAILED" -eq 1 ]; then
  echo ""
  echo "Source files must be ≤ $MAX lines. A file this long has more than one"
  echo "purpose: split it along a responsibility boundary (helper, subview, or"
  echo "Type+Feature.swift extension). Don't trim comments to pass."
  exit 1
fi
echo "✅ All source files ≤ $MAX lines"
