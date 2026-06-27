#!/usr/bin/env bash
# Enforce the 100-line limit on ALL Swift source files (not just views).
# Logic belongs in small, focused, testable files; long files get split via
# extensions or extracted helpers.
#
# Exemptions (the standard's declarative carve-outs): nothing in pipe/ is exempt
# today. Generated/declarative files would be skipped here if any existed.
set -euo pipefail

MAX=100
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
  echo "Source files must be ≤ $MAX lines. Extract logic into a focused helper"
  echo "or split the type across extension files."
  exit 1
fi
echo "✅ All source files ≤ $MAX lines"
