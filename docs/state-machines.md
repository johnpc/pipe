# State machines in pipe

Every multi-step behavior in the app is listed here with the type that makes it
explicit, or a note that it is still implicit. The rule (CLAUDE.md →
Architecture): a state machine is an `enum` plus a tested transition function,
never a set of booleans that views and tests have to reassemble. Update this
file when you add or change one.

## 1. Item playback lifecycle — `PlaybackLifecycle` / `PlaybackPhase` (explicit)

The core of the app. `PlayerState` feeds events into the pure reducer
`PlaybackLifecycle.apply(_:)`, publishes the resulting `PlaybackPhase`, and
performs the returned effects (`PlayerState+Lifecycle.swift`). `isPlaying` and
`isBuffering` are derived from the phase; nothing assigns them.

```
idle ──load(refresh)──▶ resolving ──load──▶ loading ──playerStarted──▶ buffering ──status(.playing)──▶ playing
  ▲                        ▲                                                                           │  ▲
  │                        │  ended(premature, budget left) / loadFailed(budget left)                  │  │
  │                        └───────────────────────── retryWithFreshURL ◀─────────────────────────────┘  │
  │                                                                                                      │
  │   loadFailed(budget spent) / unplayable ──▶ failed ──resume──▶ load(force refresh) …                 │
  │   status(.paused) / pause ──▶ paused ──resume──────────────────────────────────────────────────────┘
  │   restored (queue restored at launch) ──▶ paused
  └── stop (queue empty, "stop after this episode", user clear)        ended(finished | budget spent) ──▶ advance
```

| Event | From | To | Effects |
|---|---|---|---|
| `load(id, refresh:true)` | any | `resolving` | `beginHold`; a new id resets both retry budgets |
| `load(id, refresh:false)` | any | `loading` | `beginHold` |
| `load(id, casting:true)` | any | `playing` | `releaseHold("casting")` (the TV plays; no local player) |
| `unplayable(title)` | any | `failed(msg)` | `surfaceError`, `releaseHold("bad url")` |
| `playerStarted` | loading | `buffering` | — |
| `status(.playing)` | any | `playing` | `releaseHold("playing")` (its `ms` field is the start latency) |
| `status(.paused)` | loading/buffering/playing | `paused` | — (an external pause is adopted, never fought) |
| `status(.waiting)` | intends to play | `buffering` | — (while paused: ignored) |
| `ready` | any | same | clears the load-failure budget |
| `pause` | not idle | `paused` | `releaseHold("pause")` |
| `resume` | paused | `playing` | — (`PlayerState.resume` handles `failed` → force refresh, and `player == nil` → load) |
| `ended(reached, expected)` | playing | same / `resolving` | `EndOfItemPolicy`: finished or budget spent → `advance`; premature → `retryWithFreshURL(seekTo: reached)` |
| `loadFailed(title, reason, isLocal)` | any | `resolving` / `failed(msg)` | `ItemFailurePolicy`: retry → `retryWithFreshURL(seekTo: nil)`; give up → `surfaceError`, `releaseHold("gave up")` |
| `restored` | idle | `paused` | — |
| `stop` | any | `idle` | `releaseHold("stop")`; forgets the item and budgets |

What the user sees (`PlaybackPhase.statusText`, mini player second line, and the
play button's accessibility value = `phase.label`): *Loading…* during
`resolving`/`loading`, *Buffering…*, nothing while playing/paused, and
*Couldn't play. Tap play to retry.* in red when failed — where play really does
retry with a fresh URL.

Leaf policies it composes (each pure and unit-tested on its own):
`StreamFreshness` + `RefreshMode` (is a URL stale; `.ifStale` / `.force` /
`.never` — replaces the old `resolvedAt = nil` trick), `EndOfItemPolicy`
(premature end vs genuine finish), `ItemFailurePolicy` (retry budget + user copy),
`NextItemPrefetchPolicy` (when to refresh the next item's URL).

Still outside the reducer, on purpose: `pendingSeek` (a parameter for the next
start, not a phase), `playGeneration` (guards async loads from installing a
superseded player), `ItemTransition` (the UIKit background task the `beginHold`
/ `releaseHold` effects drive).

## 2. Queue item resolution — `QueueItem.resolvedAt` + `RefreshMode` (semi-explicit)

An item is **pending** (empty URLs, `resolvedAt == nil`, built from a list row),
**resolved** (`resolvedAt` set), or **stale** (older than `StreamFreshness.maxAge`).
Resolution happens in the background (`Playback.resolvePending`) or just before
play (`refreshAndPlay`, via the injectable `StreamResolving`). The only in-flight
marker is `ItemTransition.prefetching` for the next-item prefetch; a pending
item being resolved by `Playback` has no marker, which is harmless because
`applyResolvedURLs` ignores the item now playing. If a third resolver appears,
give `QueueItem` an explicit `resolution` enum.

## 3. Cast session — `CastConnectionState` (explicit)

`disconnected → connecting → connected`, mirrored from the SDK by `CastStore`.
`PlayerState+Cast` hands the current item to the TV on the transition into
`connected` (deduplicated) and routes transport to the receiver while
`isCasting`. `castLoadedVideoId` prevents reloading the item already on the TV.

## 4. Async content — `LoadState<Value>` (explicit)

`loading / loaded(value) / failed`, used by `NowPlayingDetail`, `TranscriptStore`,
and the list views, so "still loading", "empty", and "failed, offer Retry" are
distinct.

## 5. Transcript summary — implicit (`isSummarizing` + `summary` text)

`TranscriptStore` encodes idle / summarizing / done / failed in a boolean plus the
summary string's content. Small and contained; convert to an enum if a fourth
state appears.

## 6. Downloads — implicit (three collections)

A video's download state is spread over `items` (done), `inProgress` (set), and
`progress` (dictionary). Views ask three questions to render one row. Candidate
for `enum DownloadState { none, downloading(Double), downloaded(DownloadedItem) }`
when the Downloads UI next changes.

## 7. Toast — implicit (`message` + `isLoading` + `isError`)

`ToastManager` shows loading / success / error / hidden with two booleans and an
optional string. Contained in one file; fine until a fourth kind of toast.

## 8. Mock stream behaviour — implicit (three flags)

`FixtureURLProtocol.failStreams / errorStreams / downStreams` are mutually
exclusive modes modeled as booleans (set from launch arguments). Test-only.

## 9. Sleep — implicit (`sleepMinutesRemaining` + `stopAfterCurrentEpisode`)

Two independent "stop later" modes: a countdown and an end-of-episode flag. They
are genuinely independent (both can be armed), so two values is the honest model.

## 10. Audio session — `wasPlayingBeforeInterruption` + `AudioSessionPolicy`

Interruption began/ended and route changes are decided by the pure
`AudioSessionPolicy`; the one remembered bit is whether to resume.

## Test backends (not app state, but state the tests rely on)

`MockMode`: `--uitest-mock` (in-process fixtures, `/streams/<id>` personalized
by `FixtureCatalog`) or `--uitest-instance <url>` (the fake Piped backend,
`scripts/fake_piped`). Both wipe persisted state and keep the Cast SDK inert.
