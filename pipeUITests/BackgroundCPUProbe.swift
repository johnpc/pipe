import XCTest

/// Drives the app into the state that got it killed on 2026-11-26 —
/// a big followed-channel feed on screen, audio playing, app in the
/// background — and holds it there while `scripts/perf/background_cpu.sh`
/// measures the process's CPU from the host. This test asserts nothing about
/// CPU itself (a simulator test can't see another process's usage); it only
/// stages the scene and writes marker files so the host knows when to sample.
///
/// Skipped unless the host passes `TEST_RUNNER_PIPE_PERF_MARKER_DIR`, so the
/// acceptance run (which runs every pipeUITests class) never pays for it.
final class BackgroundCPUProbe: XCTestCase {
    private var markerDir: String? { ProcessInfo.processInfo.environment["PIPE_PERF_MARKER_DIR"] }
    private var instance: String { ProcessInfo.processInfo.environment["PIPE_PERF_INSTANCE"] ?? "http://127.0.0.1:8766" }
    private var holdSeconds: UInt32 { UInt32(ProcessInfo.processInfo.environment["PIPE_PERF_HOLD"] ?? "") ?? 80 }

    func testPlayingInTheBackgroundWithABigFeed() throws {
        guard let dir = markerDir else {
            throw XCTSkip("Run by scripts/perf/background_cpu.sh (TEST_RUNNER_PIPE_PERF_MARKER_DIR unset)")
        }
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-instance", instance]
        app.launch()

        followChannelAndQueueFromSearch(app, extra: 3)  // the clip is 30 s; four outlast the hold
        openFeed(app)

        mark(dir, "backgrounded")
        XCUIDevice.shared.press(.home)
        sleep(holdSeconds)
        XCTAssertNotEqual(app.state, .notRunning, "The app died in the background")
    }

    private func tab(_ app: XCUIApplication, _ name: String) {
        let button = app.buttons["tab-\(name)"]
        XCTAssertTrue(button.waitForExistence(timeout: 15), "\(name) tab should exist")
        button.tap()
        if !app.navigationBars[name].waitForExistence(timeout: 3) { button.tap() }  // launch transition can drop a tap
    }

    /// Search for the fixture channel, follow it, then play the first video
    /// result and queue more (the feed's rows are links; search rows are the
    /// play path the acceptance tests already rely on).
    private func followChannelAndQueueFromSearch(_ app: XCUIApplication, extra: Int) {
        tab(app, "Search")
        let field = app.searchFields.firstMatch.exists ? app.searchFields.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "A search field should be present")
        field.tap()
        field.typeText("MrBeast\n")
        let heart = app.buttons["followButton"].firstMatch
        XCTAssertTrue(heart.waitForExistence(timeout: 20), "A follow heart should be present")
        heart.tap()
        let play = app.buttons["playButton"].firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: 20), "A playable result should be present")
        play.tap()
        XCTAssertTrue(app.staticTexts["miniPlayerTitle"].waitForExistence(timeout: 20), "Playback should start")
        let queue = app.buttons.matching(identifier: "queueButton")
        for index in 1...extra where index < queue.count {
            queue.element(boundBy: index).tap()
        }
    }

    /// Leave the big feed on screen, the way it was when the phone was locked.
    private func openFeed(_ app: XCUIApplication) {
        tab(app, "Feed")
        let row = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '#'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30), "The 600-video feed should load")
        app.swipeUp(); app.swipeDown()  // scroll like a person, so rows below the fold exist too
        sleep(3)
    }

    /// The simulator shares the host's filesystem, so the host script sees this file.
    private func mark(_ dir: String, _ name: String) {
        let stamp = String(Date().timeIntervalSince1970)
        FileManager.default.createFile(atPath: "\(dir)/\(name)", contents: Data(stamp.utf8))
    }
}
