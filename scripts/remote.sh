#!/usr/bin/env bash
# Build, test, and look at pipe on the Mac mini (the machine CI runs on) from a
# laptop without Xcode. Edit locally; this syncs the tree and runs things there.
#
#   scripts/remote.sh sync                 # rsync the working tree (no .git, no build output)
#   scripts/remote.sh unit [TestClass]     # unit tests (+ coverage.json), optionally one class
#   scripts/remote.sh gate                 # the full quality gate (scripts/quality.sh)
#   scripts/remote.sh ui [FeatureClass]    # Gherkin acceptance tests, optionally one feature
#   scripts/remote.sh fake start|stop|log  # the fake Piped backend on the mini (127.0.0.1:8765)
#   scripts/remote.sh app [args...]        # build, install, and launch the app on the simulator
#   scripts/remote.sh shot NAME            # screenshot the simulator → /tmp/pipe-shots/NAME.png (local)
#   scripts/remote.sh rec start|stop NAME  # record the simulator → /tmp/pipe-shots/NAME.mp4 (local)
#   scripts/remote.sh logs [N]             # last N lines of the app's playback log (unified logging)
#   scripts/remote.sh ssh [cmd]            # a shell (or one command) on the mini
#
# Every long run writes a log on the mini (/tmp/pipe-*.log) and prints its tail,
# so a dropped connection never loses the result. Set PIPE_MINI (user@host) to
# target a different box; the default is the self-hosted CI runner.
set -euo pipefail
MINI="${PIPE_MINI:-john@johns-Mac-Mini.local}"
REMOTE_DIR="${PIPE_REMOTE_DIR:-~/repo/pipe}"
DEST="platform=iOS Simulator,name=iPhone 17 Pro"
SIM_NAME="iPhone 17 Pro"
BUNDLE_ID="com.johncorser.pipe"
FAKE_PORT=8765
SHOTS=/tmp/pipe-shots
SSH=(ssh -o BatchMode=yes -o ConnectTimeout=8 "$MINI")

cd "$(git rev-parse --show-toplevel)"
mkdir -p "$SHOTS"

sync_tree() {
  rsync -az --delete --exclude .git --exclude DerivedData --exclude build \
    --exclude TestResults.xcresult --exclude AcceptanceResults.xcresult --exclude coverage.json \
    --exclude 'pipe/Secrets.xcconfig' ./ "$MINI:$REMOTE_DIR/"
  echo "✓ synced to $MINI:$REMOTE_DIR"
}

# Run a command on the mini with its output captured to a log, then show the tail.
run_logged() { # name, command
  local name="$1"; shift
  "${SSH[@]}" "cd $REMOTE_DIR && ( $* ) > /tmp/pipe-$name.log 2>&1; echo EXIT=\$? >> /tmp/pipe-$name.log; tail -n 25 /tmp/pipe-$name.log"
}

xcodebuild_test() { # only-testing selector, extra flags
  echo "rm -rf TestResults.xcresult && xcodebuild test -scheme pipe -destination '$DEST' -derivedDataPath DerivedData -only-testing:$1 -resultBundlePath TestResults.xcresult $2 -quiet 2>&1 | grep -vE '^\s*$' ; echo; xcrun xcresulttool get test-results summary --path TestResults.xcresult 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(\"passed\", d.get(\"passedTests\"), \"failed\", d.get(\"failedTests\"), \"skipped\", d.get(\"skippedTests\")); [print(\"❌\", f[\"testIdentifierString\"], \"—\", f[\"failureText\"]) for f in d.get(\"testFailures\", [])]'"
}

booted_udid() {
  "${SSH[@]}" "xcrun simctl list devices booted -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next((x[\"udid\"] for r in d[\"devices\"].values() for x in r if x[\"name\"]==\"$SIM_NAME\"), \"\"))'"
}

ensure_booted() {
  local udid; udid=$(booted_udid)
  if [ -z "$udid" ]; then
    "${SSH[@]}" "xcrun simctl boot '$SIM_NAME' >/dev/null 2>&1 || true; xcrun simctl bootstatus '$SIM_NAME' -b >/dev/null"
  fi
}

case "${1:-}" in
  sync) sync_tree ;;
  unit)
    sync_tree
    sel="pipeTests${2:+/$2}"
    run_logged unit "$(xcodebuild_test "$sel" "-enableCodeCoverage YES") && xcrun xccov view --report --json TestResults.xcresult > coverage.json && python3 scripts/coverage_check.py coverage.json | tail -n 3 && python3 scripts/crap_check.py coverage.json | tail -n 3"
    ;;
  gate) sync_tree; run_logged quality "bash scripts/quality.sh" ;;
  ui)
    sync_tree
    sel="pipeUITests${2:+/$2}"
    run_logged ui "$(xcodebuild_test "$sel" "-parallel-testing-enabled YES -parallel-testing-worker-count 4")"
    ;;
  fake)
    case "${2:-}" in
      start) sync_tree; "${SSH[@]}" "cd $REMOTE_DIR && (pgrep -f 'fake_piped/server.py' >/dev/null && echo 'already running') || (nohup python3 -I scripts/fake_piped/server.py --port $FAKE_PORT > /tmp/pipe-fake.log 2>&1 & sleep 1; curl -fsS http://127.0.0.1:$FAKE_PORT/healthz && echo && lsof -nP -iTCP:$FAKE_PORT -sTCP:LISTEN | tail -n 1)" ;;
      stop) "${SSH[@]}" "pkill -f 'fake_piped/server.py' && echo stopped || echo 'not running'" ;;
      log) "${SSH[@]}" "tail -n ${3:-40} /tmp/pipe-fake.log" ;;
      *) echo "usage: remote.sh fake start|stop|log"; exit 2 ;;
    esac ;;
  app)
    shift; sync_tree; ensure_booted
    args="${*:-}"
    "${SSH[@]}" "cd $REMOTE_DIR && xcodebuild build -scheme pipe -destination '$DEST' -derivedDataPath DerivedData -quiet 2>&1 | tail -n 5; APP=\$(find DerivedData/Build/Products/Debug-iphonesimulator -maxdepth 1 -name pipe.app | head -n 1); xcrun simctl install '$SIM_NAME' \"\$APP\" && xcrun simctl terminate '$SIM_NAME' $BUNDLE_ID >/dev/null 2>&1 || true; xcrun simctl launch '$SIM_NAME' $BUNDLE_ID $args"
    ;;
  shot)
    name="${2:?name}"; ensure_booted
    "${SSH[@]}" "xcrun simctl io '$SIM_NAME' screenshot /tmp/pipe-shot.png >/dev/null" && scp -q "$MINI:/tmp/pipe-shot.png" "$SHOTS/$name.png" && echo "$SHOTS/$name.png"
    ;;
  rec)
    name="${3:?name}"
    case "${2:-}" in
      start) ensure_booted; "${SSH[@]}" "nohup xcrun simctl io '$SIM_NAME' recordVideo --codec h264 --force /tmp/pipe-rec.mp4 </dev/null >/tmp/pipe-rec.log 2>&1 & echo \$! > /tmp/pipe-rec.pid; echo recording" ;;
      stop) "${SSH[@]}" "kill -INT \$(cat /tmp/pipe-rec.pid) && sleep 2" ; scp -q "$MINI:/tmp/pipe-rec.mp4" "$SHOTS/$name.mp4" && echo "$SHOTS/$name.mp4" ;;
      *) echo "usage: remote.sh rec start|stop NAME"; exit 2 ;;
    esac ;;
  logs)
    "${SSH[@]}" "xcrun simctl spawn '$SIM_NAME' log show --last 10m --style compact --predicate 'subsystem == \"$BUNDLE_ID\"' 2>/dev/null | tail -n ${2:-60}"
    ;;
  ssh) shift; "${SSH[@]}" "cd $REMOTE_DIR && ${*:-\$SHELL -l}" ;;
  *) sed -n '2,20p' "$0"; exit 2 ;;
esac
