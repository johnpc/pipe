import UIKit

/// Lets the app keep running briefly without audio — e.g. while fetching the
/// next item's stream URL after the current one ends in the background, when
/// iOS would otherwise suspend it mid-fetch. Injectable so tests can observe.
protocol BackgroundActivity {
    func begin(name: String, onExpire: @escaping () -> Void) -> UIBackgroundTaskIdentifier
    func end(_ id: UIBackgroundTaskIdentifier)
}

struct UIKitBackgroundActivity: BackgroundActivity {
    func begin(name: String, onExpire: @escaping () -> Void) -> UIBackgroundTaskIdentifier {
        UIApplication.shared.beginBackgroundTask(withName: name, expirationHandler: onExpire)
    }

    func end(_ id: UIBackgroundTaskIdentifier) {
        UIApplication.shared.endBackgroundTask(id)
    }
}

/// The background hold that keeps the app alive while the next stream loads,
/// so moving from one queue item to the next has no gap.
final class ItemTransition {
    private let activity: BackgroundActivity
    private(set) var holdToken: UIBackgroundTaskIdentifier?
    /// When the current hold began — i.e. when the item started loading — so
    /// the release can report how long the start took.
    private(set) var heldSince: Date?
    /// Called when iOS expires the hold before playback resumed.
    var onExpire: (() -> Void)?

    init(activity: BackgroundActivity = UIKitBackgroundActivity()) {
        self.activity = activity
    }

    var isHolding: Bool { holdToken != nil }

    /// Begin a hold; a no-op while one is already active.
    func beginHold() {
        guard holdToken == nil else { return }
        let token = activity.begin(name: "pipe.itemTransition") { [weak self] in
            self?.onExpire?()
            self?.releaseHold()
        }
        holdToken = token == .invalid ? nil : token
        heldSince = holdToken == nil ? nil : Date()
    }

    /// Release the hold; a no-op when none is active.
    func releaseHold() {
        guard let token = holdToken else { return }
        holdToken = nil
        activity.end(token)
    }
}
