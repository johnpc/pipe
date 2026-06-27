import Testing
import Foundation
@testable import pipe

@MainActor
struct ToastManagerTests {
    @Test func showLoadingSetsMessageAndFlag() {
        let toast = ToastManager()
        toast.showLoading("Loading...")
        #expect(toast.message == "Loading...")
        #expect(toast.isLoading == true)
    }

    @Test func showSuccessSetsMessageClearsLoading() {
        let toast = ToastManager()
        toast.showSuccess("Done")
        #expect(toast.message == "Done")
        #expect(toast.isLoading == false)
    }

    @Test func hideClearsEverything() {
        let toast = ToastManager()
        toast.showLoading("x")
        toast.hide()
        #expect(toast.message == nil)
        #expect(toast.isLoading == false)
    }

    @Test func successAutoHidesAfterDelay() async throws {
        // Short injected delay so the test doesn't race wall-clock under load.
        let toast = ToastManager(successDelay: 50_000_000) // 50ms
        toast.showSuccess("Bye")
        #expect(toast.message == "Bye")
        // Poll up to 5s for the auto-hide so the test is robust under parallel
        // load (the hide fires from a scheduled Task that may be delayed).
        var elapsed: UInt64 = 0
        while toast.message != nil && elapsed < 5_000_000_000 {
            try await Task.sleep(nanoseconds: 50_000_000)
            elapsed += 50_000_000
        }
        #expect(toast.message == nil)
    }

    @Test func showErrorSetsErrorFlag() {
        let toast = ToastManager()
        toast.showError("Something broke")
        #expect(toast.message == "Something broke")
        #expect(toast.isError == true)
        #expect(toast.isLoading == false)
    }

    @Test func loadingClearsErrorFlag() {
        let toast = ToastManager()
        toast.showError("oops")
        toast.showLoading("Loading...")
        #expect(toast.isError == false)
        #expect(toast.isLoading == true)
    }

    @Test func hideClearsErrorFlag() {
        let toast = ToastManager()
        toast.showError("oops")
        toast.hide()
        #expect(toast.message == nil)
        #expect(toast.isError == false)
    }
}
