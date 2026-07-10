# pipe

A native iOS audio/video player for Piped (YouTube frontend). SwiftUI app focused
on **audio-first** playback — background audio, a mini player, a queue, followed
channels, a chronological feed, and watch history.

## How we work together (read this first)

The person directing you may be **non-technical** — an "idea guy" who owns the
**product**. They define **WHAT**: features, intent, and Gherkin acceptance
scenarios. **You own the HOW**: architecture, code quality, testing, and every
technical decision below.

- **Never ask them to make a technical call.** Don't surface coverage numbers,
  CRAP, lint, file-length, or library choices as questions. Decide them yourself,
  to the standards in this file, silently.
- **Translate vague ideas into Gherkin.** When they describe a feature, propose
  concrete `.feature` scenarios (Given/When/Then) and confirm those — that's the
  spec you build to.
- **Only escalate genuine _product_ questions** — ambiguous behavior, scope, copy,
  what a screen should do. Those are theirs. Everything technical is yours.
- The standards here are the owner's, non-negotiable defaults. Apply them by
  default; you don't need permission to enforce them.

## Workflow: specs-first vertical slices

Every feature ships as one **thin vertical slice** — view + logic helper + store/
API + tests, just enough for the scenario, nothing speculative.

1. **Spec first.** Write/confirm Gherkin acceptance scenarios as real
   `.feature` files in `pipeUITests/Features/` (the source of truth), executed
   by the native Swift runner (`GherkinParser` + `StepDefinitions` +
   `StepRegistry`). **Prefer reusing existing step phrasings** — each step must
   match exactly one definition in `StepDefinitions.swift`, so a near-duplicate
   line fails as undefined or ambiguous; a genuinely new phrasing needs a new
   definition there (its pattern is a regex — escape literals like `(` and `?`).
   Then regenerate **and commit** the concrete XCUITest methods
   (`AcceptanceTests.generated.swift`):
   `python3 scripts/generate_acceptance_tests.py`. See `AcceptanceTests.md` for
   a worked example.
2. **Implement to pass the spec** — follow the architecture and conventions below.
3. **Run the full quality gate** and get it green locally (`bash scripts/quality.sh`).
4. **Conventional commit, push, CI green.** Open a PR; CI blocks the merge.

## Stack

- **Client:** SwiftUI, iOS 26+, Swift 5. Playback via **AVFoundation (`AVPlayer`)**.
- **Backend:** none of ours — talks to a Piped API instance over HTTPS
  (`PipedAPI.swift`). No auth.
- **Tests:** Swift Testing (`@Test`) + XCTest for view-render and acceptance tests.

## Architecture (the one mental model that matters)

- **Views only render.** No data transformation, no fetching, no business logic in
  a `View`. Those move to a `*Logic.swift` pure helper or a store/`ObservableObject`.
- **Stores own state + side effects.** `PlayerState` (playback + queue),
  `RecentsStore` (history), `FollowingStore` (subscriptions) are
  `ObservableObject`s. They take injectable dependencies (`UserDefaults`,
  `URLSession`) so they're testable in isolation.
- **`PipedAPI` is the only network layer.** It exposes a static, injectable
  `session` and pure URL-builder functions so decoding and URL construction are
  unit-testable via `MockURLProtocol`.
- **Pure logic lives in `*Logic.swift` / free functions** (`Playback`, `SearchLogic`,
  `StreamURLHelper`) — easily unit-tested, keeps views short.

### Code organization (follow the existing shape)

- **`X.swift` view** — renders only. ≤100 lines. Split subviews into their own
  files (`VideoRow`, `QueueSection`, `SearchSuggestionsView`).
- **`XLogic.swift` / free functions** — pure, synchronous where possible, fully tested.
- **`XStore.swift`** — `ObservableObject` state; injectable deps; `nonisolated deinit`.
- **Tests colocated by type** under `pipeTests/` (unit) and `pipeUITests/` (Gherkin).

## Quality gates (non-negotiable — CI + pre-commit enforce them)

These are hard gates. **Enforce them yourself without asking** — when one fails, fix
the code, never the gate.

- **No force-unwraps in logic, no `as!`, no `try!` outside tests.** Handle the
  optional/error path. (Test fixtures may use `try!`/`!` for brevity.)
- **Every source file ≤ 100 lines** (`scripts/check_file_lines.sh`) — views *and*
  logic/stores. The limit is a proxy for **one file, one purpose**: when a file
  goes over, **split it** — extract a focused helper, a subview, or another type
  across `Type+Feature.swift` extension files — so each piece does one thing.
  **Do not** squeak under the limit by deleting comments or collapsing lines;
  that defeats the purpose. **Never raise the limit.**
- **≥ 80% line coverage** across the app target (`scripts/coverage_check.py`). Fix by
  **writing tests** — never by adding exclusions. 80% is a floor; push to 90%+.
- **CRAP ≤ 15 per function** (`scripts/crap_check.py`, decision-point based). Over →
  raise its coverage or reduce its complexity (extract the branchy bit into a tested
  helper).
- **Acceptance tests are always Gherkin** — real `.feature` files in
  `pipeUITests/Features/`, executed by the native runner. Never ship a feature
  without its acceptance scenario. The concrete XCUITest methods are **generated**
  from the `.feature` files (`AcceptanceTests.generated.swift`); a gate
  (`scripts/generate_acceptance_tests.py --check`, in `quality.sh` and CI) fails
  if they drift, so regenerate after editing any `.feature` file.
- **Build must pass** for the app, unit, and UI-test targets.

### Honest e2e: exercise the real behavior, not just navigation

- An acceptance test must assert on **observable app behavior** (a control appears,
  state changes, the mini player shows up), never merely that a tab is selected.
- Network-dependent scenarios (search, playback) use generous waits and
  `XCTSkip` gracefully when the live Piped instance returns nothing — so CI stays
  green when the backend is flaky — but **offline-deterministic flows** (tab nav,
  empty states, suggestions, Settings) are asserted **strictly**.
- A feature whose logic can be unit-tested deterministically (stream selection,
  queue math, persistence) **must** have those unit tests in addition to the
  Gherkin flow. The Gherkin proves the wiring; the unit tests prove the logic.

## Definition of done

A slice is done only when **all** of these hold:

1. Full quality gate green locally (`bash scripts/quality.sh`): view-line limit,
   coverage ≥80%, CRAP ≤15, build.
2. Gherkin acceptance Scenario(s) added as `.feature` files in
   `pipeUITests/Features/` (generated methods regenerated), and colocated unit
   tests, all passing.
3. Conventional commit, branch pushed, PR open, **CI green**.

## Conventions

- **Conventional commits** (`feat:`, `fix:`, `chore:`, `ci:`, `docs:` …).
- Keep logic out of views — helpers/stores hold logic, views only render.
- Throwaway scripts go in `/tmp`, not the repo.
- Inject dependencies (`UserDefaults`, `URLSession`) rather than reaching for
  singletons, so everything is testable.

## Commands

```bash
bash scripts/quality.sh          # full local gate: view-lines + tests + coverage + CRAP + build
bash scripts/install-hooks.sh    # install the pre-commit hook
# Run tests directly:
xcodebuild test -scheme pipe -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:pipeTests -enableCodeCoverage YES -resultBundlePath TestResults.xcresult
```

## Key facts

- **Repo:** `johnpc/pipe`.
- **iOS bundle id:** `com.johncorser.pipe`. Apple **team id `JW5SC3NYUV`**.
  `ITSAppUsesNonExemptEncryption=NO` (no encryption prompt on upload).
- **Piped instance:** `https://pipedapi.jpc.io` (configurable in Settings).
- **Diagnostics/telemetry:** structured playback logs live on-device (share via
  Settings → Diagnostics) and, when the user opts in, upload to the **pipe-logs**
  backend (private repo `johnpc/pipe-logs`; AWS profile `personal`, us-west-2:
  API Gateway → Lambda → S3). To read a device's logs, see that repo's
  `CLAUDE.md`. The ingest API key is injected at build time from
  `pipe/Secrets.xcconfig` (gitignored) as `$(PIPE_LOGS_API_KEY)` → `Info.plist`
  → `DiagnosticsConfig.apiKey`. **Set it up locally** (never commit it):
  ```bash
  cp pipe/Secrets.example.xcconfig pipe/Secrets.xcconfig
  KEY=$(aws apigateway get-api-key --api-key 9kowamshy4 --include-value \
    --profile personal --region us-west-2 --query value --output text)
  printf 'PIPE_LOGS_API_KEY = %s\n' "$KEY" >> pipe/Secrets.xcconfig
  ```
- **CI:** `.github/workflows/quality-gates.yml` blocks PRs (build, view-line limit,
  unit tests + coverage, CRAP, Gherkin acceptance) and deploys to App Store Connect
  on push to `main`. Repo secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT`,
  `TEAM_ID`.
- **Casting (Chromecast / Android TV):** casting to a TV runs through the **Google
  Cast SDK**, which Google ships **only** as a CocoaPod (`google-cast-sdk`) or a
  manually-added static `GoogleCast.xcframework` — *not* as a Swift Package. The
  whole app is built to work **with or without** it: every `GCK*` call is confined
  to `GoogleCaster.swift`/`GoogleCaster+Listeners.swift` behind `#if canImport(GoogleCast)`,
  with an unavailable fallback (same containment as `AppleIntelligenceSummarizer`).
  So the app + tests build and ship green **without** the SDK; the cast button just
  stays hidden. **To light it up:** add `GoogleCast.xcframework` (v4.8.4, from
  `https://dl.google.com/dl/chromecast/sdk/ios/GoogleCastSDK-ios-4.8.4_static.zip`)
  to the `pipe` target in Xcode as "Embed & Sign" (or `pod 'google-cast-sdk'`). The
  Info.plist local-network + `_googlecast._tcp` Bonjour keys are already present.
  The rest of the app talks to casting only through the `Casting` protocol +
  `CastStore` (see `Casting.swift`, `CastLogic.swift`), which are fully unit-tested
  with a `MockCaster` — no SDK needed for CI.
