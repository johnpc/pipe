#!/usr/bin/env bash
# Full local quality gate for pipe — the same checks CI enforces, in one command.
# Mirrors the non-negotiable gates in CLAUDE.md: view-line limit, unit tests +
# coverage >= 80%, CRAP <= 15, and a clean build.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

SCHEME="pipe"
DESTINATION="${PIPE_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
RESULT="TestResults.xcresult"

echo "▶ [1/4] View file line limit (≤100)"
bash scripts/check_view_lines.sh

echo "▶ [1b/4] Acceptance tests generated from .feature files are in sync"
python3 scripts/generate_acceptance_tests.py --check

echo "▶ [2/4] Unit tests + coverage"
rm -rf "$RESULT"
xcodebuild test \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -only-testing:"pipeTests" \
  -derivedDataPath DerivedData \
  -enableCodeCoverage YES \
  -resultBundlePath "$RESULT" \
  -quiet
xcrun xccov view --report --json "$RESULT" > coverage.json

echo "▶ [3/4] Coverage threshold (≥80%)"
python3 scripts/coverage_check.py coverage.json

echo "▶ [3b/4] CRAP analysis (≤15)"
python3 scripts/crap_check.py coverage.json

echo "▶ [4/4] Build app"
xcodebuild build \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath DerivedData \
  -quiet

echo "✅ Quality gate passed"
