import Foundation

/// Generic async-content load state, so views can distinguish "still loading"
/// from "loaded empty" from "failed" and offer a Retry. Pure value type, fully
/// testable.
enum LoadState<Value: Equatable>: Equatable {
    case loading
    case loaded(Value)
    case failed

    var value: Value? {
        if case let .loaded(v) = self { return v }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var didFail: Bool {
        if case .failed = self { return true }
        return false
    }

    /// Map an optional result from a `try?` network call into a state:
    /// nil → failed, non-nil → loaded.
    static func from(_ result: Value?) -> LoadState<Value> {
        result.map { .loaded($0) } ?? .failed
    }
}
