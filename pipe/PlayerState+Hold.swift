import Foundation

/// Keeps the app alive across the gap in audio while the next item loads.
///
/// iOS suspends a background-audio app seconds after its audio stops. Without
/// this hold, a track ending in the background froze the queue on the stream
/// fetch until the user next opened the app — in device logs, a "refreshing
/// stale url" followed by the next "play start" minutes or hours later.
/// The hold starts whenever an item begins loading and ends once audio is
/// actually playing, or the load is abandoned (pause, stop, give-up).
extension PlayerState {
    func holdForTransition() {
        guard !transition.isHolding else { return }
        transition.onExpire = { [weak self] in self?.log.event("hold", "expired") }
        transition.beginHold()
        if transition.isHolding { log.event("hold", "begin") }
    }

    func releaseTransitionHold(_ reason: String) {
        guard transition.isHolding else { return }
        transition.releaseHold()
        log.event("hold", "release", fields: ["reason": reason])
    }
}
