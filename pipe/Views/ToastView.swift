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
    @Published var message: String?
    @Published var isLoading = false
    @Published var isError = false
    private var hideTask: Task<Void, Never>?

    func showLoading(_ msg: String) {
        hideTask?.cancel()
        message = msg
        isLoading = true
        isError = false
    }

    func showSuccess(_ msg: String) {
        autoHide(msg, error: false, after: 1_500_000_000)
    }

    /// Show an error toast; lingers a little longer than success so it's readable.
    func showError(_ msg: String) {
        autoHide(msg, error: true, after: 3_000_000_000)
    }

    private func autoHide(_ msg: String, error: Bool, after ns: UInt64) {
        hideTask?.cancel()
        message = msg
        isLoading = false
        isError = error
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: ns)
            if !Task.isCancelled { message = nil }
        }
    }

    func hide() {
        hideTask?.cancel()
        message = nil
        isLoading = false
        isError = false
    }
}
