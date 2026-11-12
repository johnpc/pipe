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

/// State for moving from one queue item to the next without a gap: the
/// background hold that keeps the app alive while the next stream loads, and
/// the id of the upcoming item whose URL is being prefetched.
final class ItemTransition {
    private let activity: BackgroundActivity
    private(set) var holdToken: UIBackgroundTaskIdentifier?
    /// Called when iOS expires the hold before playback resumed.
    var onExpire: (() -> Void)?
    /// Video id of the upcoming item whose stream URL is being (or was last)
    /// prefetched, so the periodic tick doesn't start the same fetch twice.
    var prefetching: String?

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
    }

    /// Release the hold; a no-op when none is active.
    func releaseHold() {
        guard let token = holdToken else { return }
        holdToken = nil
        activity.end(token)
    }
}
