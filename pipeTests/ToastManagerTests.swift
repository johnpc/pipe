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
        let toast = ToastManager()
        toast.showSuccess("Bye")
        #expect(toast.message == "Bye")
        try await Task.sleep(nanoseconds: 1_800_000_000)
        #expect(toast.message == nil)
    }
}
