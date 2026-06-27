import Foundation
@testable import pipe

/// Builds a PlayerState backed by an isolated, ephemeral UserDefaults suite so
/// queue persistence never leaks between tests or into the real app domain.
@MainActor
func isolatedPlayer() -> PlayerState {
    let suite = UserDefaults(suiteName: "test-player-\(UUID().uuidString)")!
    return PlayerState(defaults: suite)
}
