#!/usr/bin/env bash
# Background-CPU budget gate.
#
# iOS kills a background app that averages over 80% CPU for 60 s
# (cpu_resource_fatal). On 2026-11-26 pipe was killed that way mid-listen:
# while audio played, the feed re-sorted and re-parsed every row's date on
# each one-second playback tick, even with the phone locked. Unit tests can't
# see that class of bug, since each function is fast on its own and the cost
# comes from how often SwiftUI runs it. So this measures the real thing: the
# BackgroundCPUProbe UI test stages a 600-video feed, plays, and backgrounds
# the app; this script samples the app process's CPU time from the host over
# a 60 s window and fails if it averages more than the budget.
#
# The Mac's cores are much faster than an iPhone's, so the budget is far below
# iOS's 80%. Calibrated on the Mac mini, 2026-11-26: the build that was killed
# on the phone (f7df00f) measured 36.7%, its fix (9955c71) 8.7%. 20% fails the
# first with room to spare and leaves the second ~2x headroom.
#
# Usage: bash scripts/perf/background_cpu.sh [--build]
#   --build   build-for-testing first (CI reuses the build job's DerivedData)
# Env: PERF_BUDGET (percent), PERF_WINDOW (s), PERF_SIM (simulator name)
set -euo pipefail
cd "$(dirname "$0")/../.."

BUDGET="${PERF_BUDGET:-20}"
WARMUP=10
WINDOW="${PERF_WINDOW:-60}"
SIM_NAME="${PERF_SIM:-pipe-perf}"
PORT=8766

UDID=$(xcrun simctl list devices available | awk -v n="$SIM_NAME" -F'[()]' '$1 ~ "^ +"n" $" {print $2; exit}')
[ -n "$UDID" ] || UDID=$(xcrun simctl create "$SIM_NAME" "iPhone 17 Pro")
xcrun simctl boot "$UDID" 2>/dev/null || true
DEST="id=$UDID"

if [ "${1:-}" = "--build" ]; then
  xcodebuild build-for-testing -scheme pipe -destination "$DEST" -derivedDataPath DerivedData -quiet
fi

MARKERS=$(mktemp -d /tmp/pipe-perf.XXXXXX)
LOG="$MARKERS/xcodebuild.log"
cleanup() {
  kill "$(cat "$MARKERS/fake.pid" 2>/dev/null)" 2>/dev/null || true
  [ -n "${TEST_PID:-}" ] && kill "$TEST_PID" 2>/dev/null || true
}
trap cleanup EXIT

python3 -I scripts/fake_piped/server.py --port "$PORT" --feed-size 600 --daemon \
  --log "$MARKERS/fake.log" --pidfile "$MARKERS/fake.pid"
for _ in $(seq 1 40); do curl -fsS "http://127.0.0.1:$PORT/healthz" >/dev/null && break || sleep 0.5; done

TEST_RUNNER_PIPE_PERF_MARKER_DIR="$MARKERS" \
TEST_RUNNER_PIPE_PERF_INSTANCE="http://127.0.0.1:$PORT" \
TEST_RUNNER_PIPE_PERF_HOLD=$((WARMUP + WINDOW + 10)) \
  xcodebuild test-without-building -scheme pipe -destination "$DEST" -derivedDataPath DerivedData \
    -only-testing:pipeUITests/BackgroundCPUProbe > "$LOG" 2>&1 &
TEST_PID=$!

for _ in $(seq 1 300); do [ -f "$MARKERS/backgrounded" ] && break; kill -0 "$TEST_PID" 2>/dev/null || break; sleep 1; done
if [ ! -f "$MARKERS/backgrounded" ]; then
  echo "❌ The probe never reached the background (see below)"; tail -40 "$LOG"; exit 1
fi

APP_PID=$(pgrep -f "Devices/$UDID/data/Containers/Bundle/Application/.*/pipe.app/pipe" | head -1)
[ -n "$APP_PID" ] || { echo "❌ pipe isn't running on $SIM_NAME"; exit 1; }

cpu_seconds() { ps -o time= -p "$1" | python3 -I scripts/perf/cpu_seconds.py; }
sleep "$WARMUP"
C0=$(cpu_seconds "$APP_PID"); T0=$(date +%s)
sleep "$WINDOW"
C1=$(cpu_seconds "$APP_PID"); T1=$(date +%s)

wait "$TEST_PID" || { echo "❌ The probe test failed"; tail -40 "$LOG"; exit 1; }
TEST_PID=""

python3 -I scripts/perf/verdict.py "$C0" "$C1" "$T0" "$T1" "$BUDGET"
