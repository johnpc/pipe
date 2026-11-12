import Foundation

extension Error {
    /// Domain, code and message — plus the underlying error's — so a logged
    /// failure is identifiable instead of a bare "unknown error".
    var diagnosticDescription: String {
        let ns = self as NSError
        var text = "\(ns.domain) \(ns.code): \(ns.localizedDescription)"
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
            text += " [\(underlying.domain) \(underlying.code)]"
        }
        return text
    }
}
