import UIKit
@testable import pipe

/// Records background-task begin/end calls and lets a test fire the expiration
/// handler, standing in for `UIApplication` so hold behavior is deterministic.
final class MockBackgroundActivity: BackgroundActivity {
    var begun: [String] = []
    var ended: [UIBackgroundTaskIdentifier] = []
    var expire: (() -> Void)?
    /// What `begin` hands back; set to `.invalid` to simulate a refusal.
    var nextToken = UIBackgroundTaskIdentifier(rawValue: 1)

    func begin(name: String, onExpire: @escaping () -> Void) -> UIBackgroundTaskIdentifier {
        begun.append(name)
        expire = onExpire
        return nextToken
    }

    func end(_ id: UIBackgroundTaskIdentifier) { ended.append(id) }
}
