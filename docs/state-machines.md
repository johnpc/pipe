# State machines in pipe

Every multi-step behavior in the app is listed here with the type that makes it
explicit, or a note that it is still implicit. The rule (CLAUDE.md →
Architecture): a state machine is an `enum` plus a tested transition function,
never a set of booleans that views and tests have to reassemble. Update this
file when you add or change one.

## 1. Item playback lifecycle — `PlaybackLifecycle` / `PlaybackPhase` (explicit)

The core of the app. `PlayerState` feeds events into the pure reducer
`PlaybackLifecycle.apply(_:)` and performs the returned effects
(`PlayerState+Lifecycle.swift`); it makes no playback decisions of its own.
The reducer owns the **whole load loop**: the phase, the load **generation**
(async results from an older load are ignored), the **start position** for the
next player, whether the load targets a **TV receiver**, and both retry
budgets. `isPlaying` and `isBuffering` are derived from the phase; nothing
assigns them.

```
idle ─load(refresh)─▶ resolving ─resolved / resolveFailed─▶ loading ─playerStarted─▶ buffering ─status(.playing)─▶ playing
  ▲                      ▲                                                                                      │   ▲
  │                      │  ended(premature, budget left) / loadFailed(budget left): resolve(item, gen+1)      │   │
  │                      └────────────────────────────────────────────────────────────────────────────────────┘   │
  │   loadFailed(budget spent) / unplayable ──▶ failed ──resume (PlayerState: load(force refresh)) …               │
  │   status(.paused) / pause / receiver(.paused) ──▶ paused ──resume─────────────────────────────────────────────┘
  │   restored (queue restored at launch) ──▶ paused
  └── stop (queue empty, "stop after this episode", user clear)        ended(finished | budget spent) ──▶ advance
```

| Event | From | To | Effects |
|---|---|---|---|
| `load(item, refresh:true, casting)` | any | `resolving` | gen+1; `beginHold`, `resolve(item, gen)`; a new id resets both retry budgets |
| `load(item, refresh:false, casting:false)` | any | `loading` | gen+1; `beginHold`, `build(item, gen)` |
| `load(item, refresh:false, casting:true)` | any | `playing` | gen+1; `releaseHold("casting")`, `cast(item)` |
| `resolved(item, gen)` | resolving | `loading` / `playing` | ignored unless `gen` is current; `store(item)` then `build` or (casting) `cast` |
| `resolveFailed(item, gen)` | resolving | `loading` / `playing` | ignored unless current; `build`/`cast` with the stored URLs |
| `startAt(t)` | any | same | the next `build` seeks to `t`; consumed by `playerStarted`, dropped on failure |
| `unplayable(title)` | any | `failed(msg)` | `surfaceError`, `releaseHold("bad url")` |
| `playerStarted` | loading | `buffering` | clears `startAt` |
| `status(.playing)` | any | `playing` | `releaseHold("playing")` (its `ms` field is the start latency) |
| `status(.paused)` | loading/buffering/playing | `paused` | — (an external pause is adopted, never fought) |
| `status(.waiting)` | intends to play | `buffering` | — (while paused: ignored) |
| `receiver(state)` | casting, not idle/failed | `playing` / `paused` / `buffering` | — (`idle` is not mirrored; the finish arrives as `ended`) |
| `ready` | any | same | clears the load-failure budget |
| `pause` | not idle | `paused` | `releaseHold("pause")` |
| `resume` | paused | `playing` | — (`PlayerState.resume` handles `failed` → force refresh, and `player == nil` → load) |
| `ended(item, reached, expected)` | playing | same / `resolving` | `EndOfItemPolicy`: finished or budget spent → `advance`; premature → `startAt = reached`, gen+1, `beginHold`, `resolve(item, gen)` |
| `loadFailed(item, reason, isLocal)` | any | `resolving` / `failed(msg)` | `ItemFailurePolicy`: retry → gen+1, `beginHold`, `resolve(item, gen)`; give up → `surfaceError`, `releaseHold("gave up")` |
| `restored` | idle | `paused` | — |
| `stop` | any | `idle` | gen+1 (in-flight work is dropped); `releaseHold("stop")`; forgets the item, budgets, start position |

Effects are performed by `PlayerState`: `resolve` → `resolveAndPlay` (the
injectable `StreamResolving`, answering with `resolved`/`resolveFailed`);
`build` → `buildPlayer(for:generation:)` (local file / native HLS / composed /
single stream; its async completions check `lifecycle.isCurrent(generation)`);
`cast` → `castItem`; `store` → `updateQueueItem`; `advance` →
`advanceAfterFinish`; holds → `ItemTransition`.

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

Still outside the reducer, on purpose: `ItemTransition` (the UIKit background
task the `beginHold` / `releaseHold` effects drive) and `castLoadedVideoId`
(a receiver-side dedupe, not a phase).

## 2. Queue item resolution — `QueueItem.resolution` (explicit)

`StreamResolution`: **pending** (queued from a list row, no URLs yet),
**resolving** (a background fetch is in flight), **resolved(Date)** (stale once
older than `StreamFreshness.maxAge`), or **failed** (a background fetch failed;
the play path's own refresh is the retry). Derived from the persisted
`resolvedAt` plus the in-memory `resolveAttempt`, which `Playback.resolvePending`
(instant "Add to queue") and the next-item prefetch both record. `isBusy`
(resolving or failed) is what `NextItemPrefetchPolicy` consults, so two
resolvers never race for one item and a failed fetch is not retried every tick.
`RefreshMode` (`.ifStale` / `.force` / `.never`) is how `playItem` treats the
stored URLs.

## 3. Cast session — `CastConnectionState` + `CastPlaybackState` (explicit)

Connection: `disconnected → connecting → connected`, mirrored from the SDK by
`CastStore`. Playback: `idle / buffering / playing / paused`, read from the
receiver's media status and mirrored onto the phone's `PlaybackPhase` by the
lifecycle's `receiver` event, so the phone shows what the TV is doing. On the
transition into `connected`, `PlayerState+Cast` runs the current item through
`playItem(casting: true)`, so a stale URL is refreshed before the hand-off.
`castLoadedVideoId` prevents reloading the item already on the TV.

## 4. Async content — `LoadState<Value>` (explicit)

`loading / loaded(value) / failed`, used by `NowPlayingDetail`, `TranscriptStore`,
and the list views, so "still loading", "empty", and "failed, offer Retry" are
distinct.

## 5. Transcript summary — `SummaryState` (explicit)

`idle / summarizing(partial) / done(text) / failed(message)` on
`TranscriptStore.summaryState`; `summary` and `isSummarizing` are views onto it.

## 6. Downloads — `DownloadState` (explicit)

`DownloadStore.state(for:)` answers `none / downloading(progress) /
downloaded(item)` from the persisted `items` plus the live `downloading`
dictionary, so a row asks one question.

## 7. Toast — `ToastState` (explicit)

`hidden / loading(msg) / success(msg) / error(msg)` on `ToastManager.state`;
`message`, `isLoading`, `isError` are derived.

## 8. Mock stream behaviour — `FixtureURLProtocol.StreamMode` (explicit)

`normal / networkFailure / pipedError / instanceDown`, chosen from the launch
flags by `StreamMode.from(arguments:)`. Test-only.

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

## Instance choice — `SettingsLogic.initialInstance` (explicit, decided once)

stored value (including an explicit clear, "") → that; else prior app *content*
present → `legacyInstance` (upgrade keeps what the user had); else `noInstance`
(a fresh install ships with no server). Persisted on first launch so the decision
is never re-evaluated. `isConfigured` drives `OfflineLogic.screen`: Feed/Search
show `InstanceSetupView` (enter a URL, or "Try the demo library") until set.
