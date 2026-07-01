import Foundation
import UIKit

/// App-lifecycle flushing for the remote sink. Passive listening emits few
/// events, so relying on the batch threshold alone would strand logs in memory.
/// Flush when the app backgrounds/resigns active (a session naturally ending)
/// and on a periodic timer while active.
extension RemoteLogSink {
    func observeAppLifecycle() {
        let center = NotificationCenter.default
        for name in [UIApplication.didEnterBackgroundNotification,
                     UIApplication.willResignActiveNotification] {
            center.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
                self?.flush()
            }
        }
        // Periodic flush so a long, foregrounded listening session still ships
        // its logs without waiting for a background transition.
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.flush()
        }
        RunLoop.main.add(timer, forMode: .common)
    }
}
