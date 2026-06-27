import UIKit

/// Lightweight haptic feedback for confirming user actions (save, download,
/// queue). Centralized so call sites stay one-liners and it's easy to mute.
enum Haptics {
    /// A light selection/confirmation tap.
    @MainActor
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
