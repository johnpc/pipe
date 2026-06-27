# Acceptance Tests

The **source of truth for acceptance specs is the `.feature` files** in
[`pipeUITests/Features/`](pipeUITests/Features/). They are real Gherkin, parsed
and executed at runtime by a native Swift runner — there is no separate Markdown
mirror to keep in sync.

## How it works

- **`pipeUITests/Features/*.feature`** — one feature per file, standard Gherkin
  (`Feature:` / `Scenario:` / `Given`/`When`/`Then`/`And`). A `@fail-streams` tag
  on a scenario or feature launches the app with `/streams/` requests failing, to
  exercise error-recovery UI. These files are bundled into the UI-test target.
- **`pipeUITests/GherkinParser.swift`** — dependency-free parser → feature/scenario/step values.
- **`pipeUITests/StepDefinitions.swift`** — maps each `Given/When/Then` line (by
  regex, with capture groups) to an XCUITest action/assertion.
- **`pipeUITests/StepRegistry.swift`** — step registration + matching (flags
  undefined/ambiguous steps as failures).
- **`pipeUITests/AcceptanceTests.generated.swift`** — `@generated`: one concrete
  `test…` per scenario, each delegating to the runtime runner. Concrete methods
  are required so XCTest's `-only-testing` filtering and crash recovery work
  (CI's targeted retry depends on them). **Do not edit by hand.**

## Adding or changing a scenario

1. Edit (or add) a `.feature` file under `pipeUITests/Features/`.
2. If a step is new, add a matching definition in `StepDefinitions.swift`.
3. Regenerate the test methods:

   ```bash
   python3 scripts/generate_acceptance_tests.py
   ```

The generated file is checked in; a quality gate
(`generate_acceptance_tests.py --check`, run in `scripts/quality.sh` and CI)
fails the build if it drifts from the `.feature` files.

> **Reuse step phrasings.** Each step line must match **exactly one** definition.
> A near-duplicate fails as *undefined* (no match) or *ambiguous* (two matches).
> Reach for an existing step before inventing new wording.

### Worked example

A scenario in `pipeUITests/Features/picture_in_picture.feature`:

```gherkin
  Scenario: Video mode presents a PiP-capable player
    Given a video is playing
    And I have opened the full player
    When I enable "Show Video"
    Then the video surface should be shown (PiP-capable)
```

`Given a video is playing` and `And I have opened the full player` already exist,
so they need nothing. The last two lines are new phrasings, so each gets a
definition in `StepDefinitions.swift` — note the pattern is a **regex**, so the
literal parentheses in the last step are escaped:

```swift
r.define("I enable \"(.+)\"") { w in
    let button = w.app.buttons[w.capture()]
    XCTAssertTrue(button.waitForExistence(timeout: medium))
    button.tap()
}
r.define("the video surface should be shown \\(PiP-capable\\)") { w in
    XCTAssertTrue(w.app.buttons["Audio Only"].waitForExistence(timeout: short),
                  "Video surface (PiP-capable) should be active in video mode")
}
```

The capture group `"(.+)"` is passed to the handler as `w.capture()`.

## Determinism

The app launches in mock mode (`--uitest-mock`), serving bundled real Piped
fixtures (`pipe/Fixtures/*.json`) captured from the live instance. Every
data-reading scenario asserts on **real fixture data** (channel "MrBeast", real
video titles) — no skips, no dependence on a live backend during CI.

## Running

```bash
xcodebuild test -scheme pipe \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -only-testing:"pipeUITests/AcceptanceTests"
```

## Feature: Picture in Picture

```gherkin
Feature: Picture in Picture
  As a user
  I want video to keep playing in a floating window when I leave the app
  So that I can multitask while watching

  Scenario: Video mode presents a PiP-capable player
    Given a video is playing
    And I have opened the full player
    When I enable "Show Video"
    Then the video surface should be shown (PiP-capable)

  # Note: PiP activation on backgrounding is an OS behavior that cannot be
  # driven in a simulator UI test; the PiP-eligibility decision is covered by
  # PiPLogicTests, and the PiP-capable surface is verified by the toggle below.
```

## Feature: Chapters

```gherkin
Feature: Chapters
  As a user
  I want to jump to sections of a long video
  So that I can skip to the part I care about

  Scenario: Opening a video with chapters shows a tappable chapter list
    Given I have searched and opened a video that has chapters
    Then I should see a "Chapters" list
    When I tap a chapter
    Then playback should jump to that chapter's start
```
