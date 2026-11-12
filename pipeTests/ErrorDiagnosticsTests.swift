import Testing
import Foundation
@testable import pipe

struct ErrorDiagnosticsTests {
    @Test func includesDomainCodeAndUnderlyingError() {
        let underlying = NSError(domain: "NSOSStatusErrorDomain", code: -12190)
        let error = NSError(domain: "AVFoundationErrorDomain", code: -11800,
                            userInfo: [NSUnderlyingErrorKey: underlying, NSLocalizedDescriptionKey: "The operation could not be completed"])
        #expect(error.diagnosticDescription == "AVFoundationErrorDomain -11800: The operation could not be completed [NSOSStatusErrorDomain -12190]")
    }

    @Test func plainErrorHasNoUnderlyingSuffix() {
        let text = URLError(.notConnectedToInternet).diagnosticDescription
        #expect(text.hasPrefix("NSURLErrorDomain -1009: "))
        #expect(!text.contains("["))
    }
}
