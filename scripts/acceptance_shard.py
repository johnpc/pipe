#!/usr/bin/env python3
"""Print the `-only-testing` xcodebuild args for one themed acceptance shard.

The acceptance suite is split across parallel CI jobs grouped BY THEME (Playback,
Discovery, Library, …) so a red job names what broke ("Acceptance: Playback")
instead of an opaque "shard 3". Each job stays small enough to just retry the
whole shard — no fragile "re-run only the failed test" parsing, which is how a
real failure once slipped through green.

Each theme owns a set of .feature files. Scenarios are enumerated using the SAME
method-naming rule as generate_acceptance_tests.py so the `-only-testing`
identifiers always match the generated XCTest methods.

A feature file that belongs to NO theme is a hard error — otherwise a new feature
would be silently skipped (the exact masking bug this split exists to prevent).

Usage:
  python3 scripts/acceptance_shard.py --theme playback   # args for one theme
  python3 scripts/acceptance_shard.py --themes           # print theme names (CI matrix)
  python3 scripts/acceptance_shard.py --check            # verify every feature is assigned
  python3 scripts/acceptance_shard.py --list             # show the full split
"""
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_acceptance_tests import parse_features, selector_fragment  # noqa: E402

SUITE = "pipeUITests/AcceptanceTests"

# Theme → the .feature files it owns. Keep this exhaustive: every file in
# pipeUITests/Features/ must appear in exactly one theme (enforced by --check).
THEMES = {
    "playback": [
        "playback.feature",
        "queue.feature",
        "play_next.feature",
        "chapters.feature",
        "audio_video_mode.feature",
        "picture_in_picture.feature",
        "sleep_timer.feature",
    ],
    "discovery": [
        "search.feature",
        "search_as_you_type.feature",
        "trending.feature",
        "comments.feature",
        "up_next.feature",
        "playlists.feature",
    ],
    "library": [
        "downloads.feature",
        "save_for_later.feature",
        "recents.feature",
        "watch_history_management.feature",
        "following.feature",
    ],
    "navigation": [
        "tab_navigation.feature",
        "channel_browsing.feature",
        "channel_metadata.feature",
        "settings.feature",
        "error_recovery.feature",
        "search_history.feature",
        "feed_sorting.feature",
    ],
}


def methods_by_file():
    """{file_name: ['pipeUITests/AcceptanceTests/test_<frag>', ...]}."""
    out = {}
    for _feature, file_name, scenarios in parse_features():
        out[file_name] = [
            f"{SUITE}/test_{selector_fragment(s)}" for s in scenarios
        ]
    return out


def assigned_files():
    return {f for files in THEMES.values() for f in files}


def check():
    """Fail if any feature file is unassigned or assigned to multiple themes."""
    actual = set(methods_by_file().keys())
    assigned = assigned_files()
    errors = []
    missing = actual - assigned
    if missing:
        errors.append(f"feature files not assigned to any theme: {sorted(missing)}")
    phantom = assigned - actual
    if phantom:
        errors.append(f"themes reference nonexistent feature files: {sorted(phantom)}")
    seen = {}
    for theme, files in THEMES.items():
        for f in files:
            if f in seen:
                errors.append(f"{f} is in both '{seen[f]}' and '{theme}'")
            seen[f] = theme
    if errors:
        for e in errors:
            print(f"✗ {e}", file=sys.stderr)
        print("  Update THEMES in scripts/acceptance_shard.py.", file=sys.stderr)
        sys.exit(1)
    print(f"✓ All {len(actual)} feature files assigned across {len(THEMES)} themes.")


def theme_methods(theme):
    by_file = methods_by_file()
    members = []
    for f in THEMES[theme]:
        members.extend(by_file.get(f, []))
    return sorted(members)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--theme", help="emit -only-testing args for this theme")
    ap.add_argument("--themes", action="store_true", help="print theme names as JSON (CI matrix)")
    ap.add_argument("--check", action="store_true", help="verify every feature is assigned")
    ap.add_argument("--list", action="store_true", help="print the full split")
    args = ap.parse_args()

    if args.check:
        check()
        return
    if args.themes:
        print(json.dumps(sorted(THEMES.keys())))
        return
    if args.list:
        for theme in sorted(THEMES):
            members = theme_methods(theme)
            print(f"# {theme} — {len(members)} scenarios")
            for m in members:
                print(f"  {m}")
        return
    if not args.theme:
        ap.error("one of --theme / --themes / --check / --list is required")
    if args.theme not in THEMES:
        ap.error(f"unknown theme '{args.theme}'; known: {sorted(THEMES)}")
    members = theme_methods(args.theme)
    if not members:
        print(f"error: theme '{args.theme}' has no scenarios", file=sys.stderr)
        sys.exit(1)
    print(" ".join(f"-only-testing:{m}" for m in members))


if __name__ == "__main__":
    main()
