#!/usr/bin/env bash
# Enforce the 100-line limit on SwiftUI view files.
# View files must only render; logic belongs in *Logic.swift helpers or stores.
set -euo pipefail

MAX=100
FAILED=0
echo "Checking view files for line count > $MAX..."

while IFS= read -r file; do
  # ViewModel files are not pure views and are exempt.
  case "$file" in
    *ViewModel*) continue ;;
  esac
  LINES=$(wc -l < "$file" | tr -d ' ')
  if [ "$LINES" -gt "$MAX" ]; then
    echo "❌ $(basename "$file"): $LINES lines (max $MAX)"
    FAILED=1
  fi
done < <(find pipe/Views -name "*.swift" -not -name "*ViewModel*")

if [ "$FAILED" -eq 1 ]; then
  echo ""
  echo "View files must be ≤ $MAX lines. Extract logic to *Logic.swift helpers"
  echo "or split into subview files."
  exit 1
fi
echo "✅ All view files ≤ $MAX lines"
