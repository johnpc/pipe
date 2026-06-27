import Foundation

/// A single Given/When/Then/And/But step within a scenario. `keyword` is the raw
/// Gherkin keyword; `text` is everything after it (used for step matching).
struct GherkinStep: Equatable {
    let keyword: String
    let text: String
    /// 1-based line number in the source .feature file, for diagnostics.
    let line: Int
}

/// A scenario: a name, its ordered steps, and any tags inherited from the
/// scenario or its feature (e.g. `@fail-streams`).
struct GherkinScenario: Equatable {
    let name: String
    let steps: [GherkinStep]
    let tags: Set<String>
}

/// A parsed feature file: its name and scenarios.
struct GherkinFeature: Equatable {
    let name: String
    let scenarios: [GherkinScenario]
}

/// A tiny, dependency-free Gherkin parser. Supports the subset this app's specs
/// use: `Feature:`, `Scenario:`, `Given/When/Then/And/But` steps, `@tags`,
/// comments (`#`), and the free-text "As a / I want / So that" narrative lines
/// (which are ignored). No Background, Scenario Outline, or data tables — if a
/// spec ever needs those, extend here and the runner picks them up for free.
enum GherkinParser {
    private static let stepKeywords = ["Given", "When", "Then", "And", "But"]

    /// Parse one .feature file's contents into a `GherkinFeature`, or nil if it
    /// contains no `Feature:` line.
    static func parse(_ contents: String) -> GherkinFeature? {
        var featureName: String?
        var featureTags: Set<String> = []
        var scenarios: [GherkinScenario] = []

        var pendingTags: Set<String> = []
        var currentName: String?
        var currentTags: Set<String> = []
        var currentSteps: [GherkinStep] = []

        func flushScenario() {
            guard let name = currentName else { return }
            scenarios.append(GherkinScenario(name: name, steps: currentSteps, tags: currentTags))
            currentName = nil
            currentSteps = []
            currentTags = []
        }

        let lines = contents.components(separatedBy: .newlines)
        for (index, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            if line.hasPrefix("@") {
                let tags = line.split(separator: " ").map { String($0) }
                pendingTags.formUnion(tags)
                continue
            }

            if line.hasPrefix("Feature:") {
                featureName = value(after: "Feature:", in: line)
                featureTags = pendingTags
                pendingTags = []
                continue
            }

            if line.hasPrefix("Scenario:") {
                flushScenario()
                currentName = value(after: "Scenario:", in: line)
                currentTags = featureTags.union(pendingTags)
                pendingTags = []
                continue
            }

            if let keyword = stepKeywords.first(where: { line.hasPrefix($0 + " ") }) {
                let text = value(after: keyword, in: line)
                currentSteps.append(GherkinStep(keyword: keyword, text: text, line: index + 1))
                continue
            }
            // Anything else (narrative "As a…/I want…/So that…") is ignored.
        }
        flushScenario()

        guard let name = featureName else { return nil }
        return GherkinFeature(name: name, scenarios: scenarios)
    }

    private static func value(after keyword: String, in line: String) -> String {
        String(line.dropFirst(keyword.count)).trimmingCharacters(in: .whitespaces)
    }
}
