import SwiftUI

/// Overlays the shared toast at the bottom of whatever it's attached to.
///
/// The toast used to live only in `ContentView`, but the Full Player is a
/// `.sheet` presented *above* that view — so toasts fired from the sheet's
/// Up Next / Queue actions rendered behind it and were never seen. Applying
/// this modifier to both the root and the sheet lets whichever layer is
/// frontmost show the toast; both observe the same `ToastManager.shared`.
struct ToastOverlay: ViewModifier {
    @ObservedObject private var toast = ToastManager.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let msg = toast.message {
                ToastView(message: msg, isLoading: toast.isLoading, isError: toast.isError)
                    .padding(.bottom, 120)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toast.message)
    }
}

extension View {
    /// Show the shared toast at the bottom of this view (see `ToastOverlay`).
    func toastOverlay() -> some View { modifier(ToastOverlay()) }
}
