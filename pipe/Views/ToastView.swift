import SwiftUI
import Combine

struct ToastView: View {
    let message: String
    let isLoading: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            if isLoading {
                ProgressView().tint(.white)
            } else {
                Image(systemName: "checkmark.circle.fill")
            }
            Text(message).font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.8))
        .foregroundColor(.white)
        .cornerRadius(25)
    }
}

class ToastManager: ObservableObject {
    static let shared = ToastManager()
    @Published var message: String?
    @Published var isLoading = false
    private var hideTask: Task<Void, Never>?
    
    func showLoading(_ msg: String) {
        hideTask?.cancel()
        message = msg
        isLoading = true
    }
    
    func showSuccess(_ msg: String) {
        hideTask?.cancel()
        message = msg
        isLoading = false
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if !Task.isCancelled { message = nil }
        }
    }
    
    func hide() {
        hideTask?.cancel()
        message = nil
        isLoading = false
    }
}
