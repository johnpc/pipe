import XCTest

/// Shared state passed to every step handler: the launched app plus the capture
/// groups matched from the step's regex (e.g. the search term in
/// `I type "(.+)" into the search field`).
final class GherkinWorld {
    let app: XCUIApplication
    var captures: [String] = []

    init(app: XCUIApplication) {
        self.app = app
    }

    /// First positional capture group, or fails the test with a clear message.
    func capture(_ index: Int = 0, _ file: StaticString = #file, _ line: UInt = #line) -> String {
        guard index < captures.count else {
            XCTFail("Step expected capture group #\(index) but none was matched", file: file, line: line)
            return ""
        }
        return captures[index]
    }
}

/// A registered step: its compiled regex and the closure that runs it.
private struct StepDefinition {
    let regex: NSRegularExpression
    let handler: (GherkinWorld) -> Void
}

/// Registry of Given/When/Then step definitions keyed by regex. Keywords are
/// interchangeable at match time (Cucumber semantics): a `Given` line can match
/// a step defined with `then`, and `And`/`But` inherit the previous keyword's
/// pool — so we just match against one shared pool.
final class StepRegistry {
    private var steps: [StepDefinition] = []

    /// Register a step. `pattern` is a full-match regex; capture groups are
    /// passed to the handler via `world.captures`.
    func define(_ pattern: String, _ handler: @escaping (GherkinWorld) -> Void) {
        let anchored = pattern.hasPrefix("^") ? pattern : "^\(pattern)$"
        guard let regex = try? NSRegularExpression(pattern: anchored) else {
            fatalError("Invalid step regex: \(pattern)")
        }
        steps.append(StepDefinition(regex: regex, handler: handler))
    }

    /// Find the single definition matching `text`. Returns the handler with its
    /// captures bound, or nil if no (or ambiguous) match.
    func match(_ text: String) -> ((GherkinWorld) -> Void)? {
        let range = NSRange(text.startIndex..., in: text)
        let matches = steps.compactMap { def -> (StepDefinition, NSTextCheckingResult)? in
            guard let m = def.regex.firstMatch(in: text, range: range) else { return nil }
            return (def, m)
        }
        guard matches.count == 1, let (def, result) = matches.first else { return nil }

        var captures: [String] = []
        for i in 1..<result.numberOfRanges {
            if let r = Range(result.range(at: i), in: text) {
                captures.append(String(text[r]))
            }
        }
        return { world in
            world.captures = captures
            def.handler(world)
        }
    }

    /// Whether more than one definition matches (ambiguous step) — surfaced as a
    /// distinct failure so specs don't silently run the wrong handler.
    func isAmbiguous(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return steps.filter { $0.regex.firstMatch(in: text, range: range) != nil }.count > 1
    }
}
