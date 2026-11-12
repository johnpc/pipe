import Testing
import UIKit
@testable import pipe

struct ItemTransitionTests {
    @Test func beginHoldStartsOneBackgroundTask() {
        let activity = MockBackgroundActivity()
        let transition = ItemTransition(activity: activity)
        transition.beginHold()
        transition.beginHold()  // idempotent while held
        #expect(transition.isHolding)
        #expect(activity.begun == ["pipe.itemTransition"])
    }

    @Test func releaseHoldEndsTheTaskOnce() {
        let activity = MockBackgroundActivity()
        let transition = ItemTransition(activity: activity)
        transition.beginHold()
        transition.releaseHold()
        transition.releaseHold()  // no-op when not held
        #expect(!transition.isHolding)
        #expect(activity.ended == [UIBackgroundTaskIdentifier(rawValue: 1)])
    }

    @Test func expirationReleasesAndNotifies() {
        let activity = MockBackgroundActivity()
        let transition = ItemTransition(activity: activity)
        var expired = false
        transition.onExpire = { expired = true }
        transition.beginHold()
        activity.expire?()
        #expect(expired)
        #expect(!transition.isHolding)
        #expect(activity.ended.count == 1)  // iOS requires the task be ended
    }

    @Test func refusedTaskLeavesNothingHeld() {
        let activity = MockBackgroundActivity()
        activity.nextToken = .invalid
        let transition = ItemTransition(activity: activity)
        transition.beginHold()
        #expect(!transition.isHolding)
        transition.releaseHold()
        #expect(activity.ended.isEmpty)
    }

    @Test func releasingAfterExpirationDoesNotEndTwice() {
        let activity = MockBackgroundActivity()
        let transition = ItemTransition(activity: activity)
        transition.beginHold()
        activity.expire?()
        transition.releaseHold()
        #expect(activity.ended.count == 1)
    }
}
