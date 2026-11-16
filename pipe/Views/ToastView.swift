import SwiftUI
import Combine

struct ToastView: View {
    let message: String
    let isLoading: Bool
    var isError: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            if isLoading {
                ProgressView().tint(.white)
            } else {
                Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            }
            Text(message).font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background((isError ? Color.red : Color.black).opacity(0.8))
        .foregroundColor(.white)
        .cornerRadius(25)
    }
}

class ToastManager: ObservableObject {
    static let shared = ToastManager()
    /// The one value the overlay renders; `message`/`isLoading`/`isError` are
    /// views onto it.
    @Published private(set) var state: ToastState = .hidden
    var message: String? { state.message }
    var isLoading: Bool { if case .loading = state { return true }; return false }
    var isError: Bool { if case .error = state { return true }; return false }
    private var hideTask: Task<Void, Never>?

    /// Auto-hide delays (nanoseconds). Injectable so tests aren't coupled to
    /// wall-clock timing under parallel load.
    private let successDelay: UInt64
    private let errorDelay: UInt64

    init(successDelay: UInt64 = 1_500_000_000, errorDelay: UInt64 = 3_000_000_000) {
        self.successDelay = successDelay
        self.errorDelay = errorDelay
    }

    // Avoid the MainActor-isolated-deinit crash under the current toolchain.
    nonisolated deinit {}

    func showLoading(_ msg: String) {
        hideTask?.cancel()
        state = .loading(msg)
    }

    func showSuccess(_ msg: String) {
        autoHide(.success(msg), after: successDelay)
    }

    /// Show an error toast; lingers a little longer than success so it's readable.
    func showError(_ msg: String) {
        autoHide(.error(msg), after: errorDelay)
    }

    private func autoHide(_ next: ToastState, after ns: UInt64) {
        hideTask?.cancel()
        state = next
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: ns)
            if !Task.isCancelled { state = .hidden }
        }
    }

    func hide() {
        hideTask?.cancel()
        state = .hidden
    }
}

/// What the toast overlay shows: nothing, a spinner with a message, or a
/// transient success/error message.
enum ToastState: Equatable {
    case hidden
    case loading(String)
    case success(String)
    case error(String)

    var message: String? {
        switch self {
        case .hidden: return nil
        case let .loading(m), let .success(m), let .error(m): return m
        }
    }
}
