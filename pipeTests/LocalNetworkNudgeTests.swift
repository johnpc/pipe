import Testing
import Foundation
@testable import pipe

/// The nudge exists to trip the iOS Local Network permission prompt via an
/// NWBrowser. It has no observable return value (the prompt is a system UI), so
/// these tests assert it starts, restarts, and stops without crashing — i.e. the
/// browser lifecycle is sound and safe to call repeatedly from init and rescan.
@MainActor
struct LocalNetworkNudgeTests {

    @Test func triggerAndStopAreSafe() {
        let nudge = LocalNetworkNudge()
        nudge.trigger()
        nudge.stop()
    }

    @Test func repeatedTriggersCancelThePriorBrowse() {
        let nudge = LocalNetworkNudge()
        // Calling trigger() again must cancel and replace the prior browser rather
        // than leak or crash — this backs the "Search Again" path.
        nudge.trigger()
        nudge.trigger()
        nudge.trigger()
        nudge.stop()
    }

    @Test func stopWithoutTriggerIsHarmless() {
        LocalNetworkNudge().stop()
    }
}
