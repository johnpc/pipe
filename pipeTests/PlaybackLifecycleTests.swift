import Testing
import Foundation
import AVFoundation
@testable import pipe

/// The item state machine, transition by transition. Pure: no player, no
/// network, no PlayerState.
struct PlaybackLifecycleTests {
    private func loaded(refresh: Bool = false) -> PlaybackLifecycle {
        var l = PlaybackLifecycle()
        _ = l.apply(.load(videoId: "a", refresh: refresh, casting: false))
        return l
    }

    private func playing() -> PlaybackLifecycle {
        var l = loaded()
        _ = l.apply(.playerStarted)
        _ = l.apply(.status(.playing))
        return l
    }

    // MARK: Loading

    @Test func loadingTakesTheHoldAndShowsLoading() {
        var l = PlaybackLifecycle()
        #expect(l.apply(.load(videoId: "a", refresh: false, casting: false)) == [.beginHold])
        #expect(l.phase == .loading)
        #expect(l.phase.intendsToPlay && l.phase.isWaiting)
    }

    @Test func loadingWithRefreshIsResolving() {
        var l = PlaybackLifecycle()
        #expect(l.apply(.load(videoId: "a", refresh: true, casting: false)) == [.beginHold])
        #expect(l.phase == .resolving)
    }

    @Test func castingPlaysWithoutAHold() {
        var l = PlaybackLifecycle()
        #expect(l.apply(.load(videoId: "a", refresh: false, casting: true)) == [.releaseHold("casting")])
        #expect(l.phase == .playing)
    }

    @Test func aDifferentItemResetsRetryBudgets() {
        var l = loaded()
        l.loadFailures = 1
        l.prematureEnds = 1
        _ = l.apply(.load(videoId: "a", refresh: true, casting: false))  // same item: kept
        #expect(l.loadFailures == 1 && l.prematureEnds == 1)
        _ = l.apply(.load(videoId: "b", refresh: false, casting: false))
        #expect(l.loadFailures == 0 && l.prematureEnds == 0)
    }

    @Test func unplayableURLFailsAndReleasesTheHold() {
        var l = loaded()
        let effects = l.apply(.unplayable(title: "T"))
        #expect(effects == [.surfaceError("Couldn't play T"), .releaseHold("bad url")])
        #expect(l.phase == .failed("Couldn't play T"))
        #expect(!l.phase.intendsToPlay)
    }

    // MARK: Player status

    @Test func playerStartIsBufferingUntilAudible() {
        var l = loaded()
        #expect(l.apply(.playerStarted) == [])
        #expect(l.phase == .buffering)
        #expect(l.apply(.status(.playing)) == [.releaseHold("playing")])
        #expect(l.phase == .playing)
        #expect(!l.phase.isWaiting)
    }

    @Test func rebufferingMidPlayKeepsIntentToPlay() {
        var l = playing()
        #expect(l.apply(.status(.waitingToPlayAtSpecifiedRate)) == [])
        #expect(l.phase == .buffering)
        #expect(l.phase.intendsToPlay)
    }

    @Test func externalPauseIsAdopted() {
        var l = playing()
        #expect(l.apply(.status(.paused)) == [])
        #expect(l.phase == .paused)
    }

    @Test func waitingWhilePausedStaysPaused() {
        var l = playing()
        _ = l.apply(.status(.paused))
        _ = l.apply(.status(.waitingToPlayAtSpecifiedRate))
        #expect(l.phase == .paused)
    }

    @Test func pausedStatusDuringLoadKeepsTheHold() {
        var l = loaded()
        #expect(l.apply(.status(.paused)) == [])  // no release: the hold outlives it
        #expect(l.phase == .paused)
    }

    @Test func statusWhileIdleOrFailedIsIgnored() {
        var l = PlaybackLifecycle()
        _ = l.apply(.status(.paused))
        #expect(l.phase == .idle)
        _ = l.apply(.unplayable(title: "T"))
        _ = l.apply(.status(.paused))
        #expect(l.phase.isFailed)
    }

    // MARK: User transport

    @Test func pauseAndResume() {
        var l = playing()
        #expect(l.apply(.pause) == [.releaseHold("pause")])
        #expect(l.phase == .paused)
        #expect(l.apply(.resume) == [])
        #expect(l.phase == .playing)
    }

    @Test func pauseWhileIdleStaysIdle() {
        var l = PlaybackLifecycle()
        _ = l.apply(.pause)
        #expect(l.phase == .idle)
    }

    @Test func restoredQueueIsPaused() {
        var l = PlaybackLifecycle()
        #expect(l.apply(.restored) == [])
        #expect(l.phase == .paused)
    }

    @Test func stopIsIdleAndForgetsTheItem() {
        var l = playing()
        l.loadFailures = 1
        #expect(l.apply(.stop) == [.releaseHold("stop")])
        #expect(l.phase == .idle)
        #expect(l.itemId == nil && l.loadFailures == 0)
    }

    // MARK: End of item

    @Test func genuineFinishAdvances() {
        var l = playing()
        l.prematureEnds = 1
        #expect(l.apply(.ended(reached: 100, expected: 100)) == [.advance])
        #expect(l.prematureEnds == 0)
        #expect(l.phase == .playing)  // the next item's load sets the phase
    }

    @Test func unknownDurationCountsAsFinished() {
        var l = playing()
        #expect(l.apply(.ended(reached: 5, expected: nil)) == [.advance])
    }

    @Test func prematureEndRetriesWithAFreshURLFromWhereItDied() {
        var l = playing()
        #expect(l.apply(.ended(reached: 1800, expected: 3600)) == [.retryWithFreshURL(seekTo: 1800)])
        #expect(l.phase == .resolving)
        #expect(l.prematureEnds == 1)
    }

    @Test func prematureEndGivesUpAfterMaxRetriesAndAdvances() {
        var l = playing()
        l.prematureEnds = EndOfItemPolicy.maxRetries
        #expect(l.apply(.ended(reached: 1800, expected: 3600)) == [.advance])
        #expect(l.prematureEnds == 0)
    }

    // MARK: Load failure

    @Test func loadFailureRetriesWithAFreshURL() {
        var l = loaded()
        #expect(l.apply(.loadFailed(title: "T", reason: "r", isLocal: false)) == [.retryWithFreshURL(seekTo: nil)])
        #expect(l.phase == .resolving)
        #expect(l.loadFailures == 1)
    }

    @Test func loadFailureGivesUpAfterMaxRetries() {
        var l = loaded()
        l.loadFailures = ItemFailurePolicy.maxRetries
        let message = ItemFailurePolicy.failureMessage(title: "T", reason: "no connection")
        #expect(l.apply(.loadFailed(title: "T", reason: "no connection", isLocal: false)) == [.surfaceError(message), .releaseHold("gave up")])
        #expect(l.phase == .failed(message))
        #expect(l.loadFailures == 0)
    }

    @Test func localFileFailureGivesUpImmediately() {
        var l = loaded()
        _ = l.apply(.loadFailed(title: "T", reason: "corrupt", isLocal: true))
        #expect(l.phase.isFailed)
    }

    @Test func readyClearsTheLoadFailureBudget() {
        var l = loaded()
        l.loadFailures = 1
        #expect(l.apply(.ready) == [])
        #expect(l.loadFailures == 0)
    }

    // MARK: Phase presentation

    @Test func statusTextExplainsWaitingAndFailure() {
        #expect(PlaybackPhase.resolving.statusText == "Loading…")
        #expect(PlaybackPhase.loading.statusText == "Loading…")
        #expect(PlaybackPhase.buffering.statusText == "Buffering…")
        #expect(PlaybackPhase.failed("x").statusText == "Couldn't play. Tap play to retry.")
        #expect(PlaybackPhase.playing.statusText == nil)
        #expect(PlaybackPhase.paused.subtitle(artist: "Band") == "Band")
        #expect(PlaybackPhase.loading.subtitle(artist: "Band") == "Loading…")
        #expect(PlaybackPhase.idle.subtitle(artist: nil) == "")
    }

    @Test func labelsAreDistinct() {
        let phases: [PlaybackPhase] = [.idle, .resolving, .loading, .buffering, .playing, .paused, .failed("x")]
        #expect(Set(phases.map(\.label)).count == phases.count)
        #expect(PlaybackPhase.failed("x").isFailed && !PlaybackPhase.paused.isFailed)
    }
}
