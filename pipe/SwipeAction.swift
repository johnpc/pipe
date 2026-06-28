import CoreGraphics

/// Pure mapping from a drag translation to a mini-player action, so the
/// gesture thresholds are unit-testable.
enum SwipeAction: Equatable {
    case dismiss   // swipe down
    case next      // swipe left
    case none

    /// Decide the action from a drag translation. Vertical-down beyond
    /// `threshold` dismisses; horizontal-left beyond it skips to next. The
    /// dominant axis wins; small drags do nothing.
    static func from(translationWidth dx: CGFloat, translationHeight dy: CGFloat,
                     threshold: CGFloat = 60) -> SwipeAction {
        if abs(dy) > abs(dx) {
            return dy > threshold ? .dismiss : .none
        } else {
            return dx < -threshold ? .next : .none
        }
    }

    /// Apply this action to the player (dismiss clears the queue, next advances).
    /// Returns whether anything happened (so the view can fire haptics once).
    @MainActor
    @discardableResult
    func apply(to player: PlayerState) -> Bool {
        switch self {
        case .dismiss: player.clearQueue(); return true
        case .next: player.playNext(); return true
        case .none: return false
        }
    }
}
