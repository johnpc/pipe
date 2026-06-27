import XCTest

/// Acceptance tests implementing the Gherkin scenarios in `AcceptanceTests.md`.
/// Each test maps to one Scenario, with Given/When/Then steps as comments.
///
/// The app is launched in **mock mode** (`--uitest-mock`), serving bundled real
/// Piped fixtures (captured from pipedapi.jpc.io) instead of the live network.
/// This makes every data-reading flow deterministic — scenarios assert on the
/// real fixture data (channel "MrBeast", real video titles) and never skip.
///
/// Run with:
///   xcodebuild test -scheme pipe \
///     -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
///     -only-testing:"pipeUITests/AcceptanceTests"
final class AcceptanceTests: XCTestCase {

    private var app: XCUIApplication!

    // Known strings from the bundled fixtures (pipe/Fixtures/*.json).
    private let fixtureChannelName = "MrBeast"
    private let fixtureSearchStreamTitle = "Guess What Age Punched You"
    private let fixtureNowPlayingTitle = "Survive 30 Days Chained To A Stranger, Win $250,000"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitest-mock"]
        app.launch()
    }

    // MARK: - Feature: Tab Navigation

    /// Scenario: All tabs are reachable
    func testAllTabsAreReachable() throws {
        for tab in ["Feed", "Search", "Recents", "Following", "Settings"] {
            XCTAssertTrue(app.buttons[tab].waitForExistence(timeout: 10), "\(tab) tab should exist")
        }
        app.buttons["Search"].tap()
        XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 5))
        app.buttons["Recents"].tap()
        XCTAssertTrue(app.navigationBars["Recents"].waitForExistence(timeout: 5))
        app.buttons["Following"].tap()
        XCTAssertTrue(app.navigationBars["Following"].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    // MARK: - Feature: Search

    /// Scenario: Empty state shows suggestions
    func testSearchEmptyStateShowsSuggestions() throws {
        app.buttons["Search"].tap()
        XCTAssertTrue(app.buttons["MrBeast"].waitForExistence(timeout: 10), "Suggestion should be visible")
        XCTAssertTrue(app.textFields.firstMatch.exists || app.searchFields.firstMatch.exists)
    }

    /// Scenario: Searching returns results
    func testSearchReturnsResults() throws {
        app.buttons["Search"].tap()
        performSearch("anything")
        // Then I should see the real fixture results (a known video title).
        XCTAssertTrue(app.staticTexts[fixtureSearchStreamTitle].waitForExistence(timeout: 15),
                      "Real fixture search result should render")
    }

    /// Scenario: Tapping a suggestion runs a search
    func testTappingSuggestionRunsSearch() throws {
        app.buttons["Search"].tap()
        let suggestion = app.buttons["MrBeast"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 10))
        suggestion.tap()
        XCTAssertTrue(app.staticTexts[fixtureSearchStreamTitle].waitForExistence(timeout: 15),
                      "Results should render after tapping a suggestion")
    }

    // MARK: - Feature: Playback

    /// Scenario: Playing a result starts the mini player
    func testPlayingResultStartsMiniPlayer() throws {
        searchAndPlayFirstStream()
        // Then the mini player shows the now-playing title from the streams fixture.
        XCTAssertTrue(app.staticTexts[fixtureNowPlayingTitle].waitForExistence(timeout: 15),
                      "Mini player should show the now-playing title")
    }

    /// Scenario: Expanding the mini player shows full controls
    func testExpandingMiniPlayerShowsFullControls() throws {
        searchAndPlayFirstStream()
        XCTAssertTrue(app.staticTexts[fixtureNowPlayingTitle].waitForExistence(timeout: 15))
        app.staticTexts[fixtureNowPlayingTitle].firstMatch.tap()
        XCTAssertTrue(app.buttons["1x"].waitForExistence(timeout: 10), "Full player should show speed controls")
    }

    // MARK: - Feature: Queue

    /// Scenario: Queueing a result adds it to the queue
    func testQueueingResultAddsToQueue() throws {
        app.buttons["Search"].tap()
        performSearch("anything")
        let queueButton = app.buttons["queueButton"].firstMatch
        XCTAssertTrue(queueButton.waitForExistence(timeout: 15), "A queue control should be present")
        queueButton.tap()
        XCTAssertTrue(app.staticTexts[fixtureNowPlayingTitle].waitForExistence(timeout: 15),
                      "Queued item should begin playing and show in the mini player")
    }

    // MARK: - Feature: Channel Browsing

    /// Scenario: Opening a channel shows its videos
    func testOpeningChannelShowsVideos() throws {
        app.buttons["Search"].tap()
        performSearch("anything")
        // The channel result row (fixture: "MrBeast").
        let channelRow = app.buttons["channelRow"].firstMatch
        XCTAssertTrue(channelRow.waitForExistence(timeout: 15), "Channel result should be present")
        channelRow.tap()
        // Channel screen shows its title and a Videos tab.
        XCTAssertTrue(app.buttons["Videos"].waitForExistence(timeout: 15) ||
                      app.navigationBars[fixtureChannelName].waitForExistence(timeout: 15),
                      "Channel screen should render with its videos")
    }

    // MARK: - Feature: Following

    /// Scenario: Empty following state
    func testFollowingEmptyState() throws {
        app.buttons["Following"].tap()
        XCTAssertTrue(app.staticTexts["No Channels"].waitForExistence(timeout: 10) || app.cells.count > 0,
                      "Following tab should show empty state or a channel list")
    }

    /// Scenario: Following a channel from search
    func testFollowingChannelFromSearch() throws {
        app.buttons["Search"].tap()
        performSearch("anything")
        // Tap the follow heart on the channel result.
        let heart = app.buttons["followButton"].firstMatch
        XCTAssertTrue(heart.waitForExistence(timeout: 15), "A follow heart should be present on the channel result")
        heart.tap()
        // The followed channel appears on the Following tab.
        app.buttons["Following"].tap()
        XCTAssertTrue(app.staticTexts[fixtureChannelName].waitForExistence(timeout: 10),
                      "Followed channel should appear on the Following tab")
    }

    // MARK: - Feature: Recents

    /// Scenario: Empty recents state
    func testRecentsEmptyState() throws {
        app.buttons["Recents"].tap()
        XCTAssertTrue(app.staticTexts["No History"].waitForExistence(timeout: 10) || app.cells.count > 0,
                      "Recents tab should show empty state or history")
    }

    /// Scenario: Playing a video records it in Recents
    func testPlayedVideoAppearsInRecents() throws {
        searchAndPlayFirstStream()
        XCTAssertTrue(app.staticTexts[fixtureNowPlayingTitle].waitForExistence(timeout: 15))
        app.buttons["Recents"].tap()
        XCTAssertTrue(app.staticTexts[fixtureNowPlayingTitle].waitForExistence(timeout: 10),
                      "Played video should appear in Recents")
    }

    // MARK: - Feature: Settings

    /// Scenario: Settings screen shows its sections
    func testSettingsShowsSections() throws {
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Piped Instance"].exists, "Piped Instance section")
        XCTAssertTrue(app.staticTexts["Sleep Timer"].exists, "Sleep Timer section")
        XCTAssertTrue(app.staticTexts["Search History"].exists, "Search History section")
    }

    /// Scenario: Setting a sleep timer shows the countdown
    func testSleepTimerShowsCountdown() throws {
        app.buttons["Settings"].tap()
        let option = app.buttons["Sleep after 30 min"]
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        option.tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5), "Cancel should appear once a timer is set")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'min remaining'")).firstMatch.exists,
                      "Remaining time should be shown")
    }

    /// Scenario: Clearing search history empties it
    func testClearSearchHistory() throws {
        app.buttons["Search"].tap()
        performSearch("temporary query")
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Search History"].waitForExistence(timeout: 10))
        // Clear History sits below the history list; scroll it into view.
        let clearButton = app.buttons["Clear History"]
        if !clearButton.waitForExistence(timeout: 3) || !clearButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5), "Clear History should be present after a search")
        clearButton.tap()
        XCTAssertTrue(app.staticTexts["No recent searches"].waitForExistence(timeout: 5),
                      "History should be empty after clearing")
    }

    // MARK: - Feature: Search History

    /// Scenario: A performed search is remembered
    func testSearchIsRemembered() throws {
        app.buttons["Search"].tap()
        performSearch("lofi beats")
        // The term is recorded; verify it in the Settings → Search History section.
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["lofi beats"].waitForExistence(timeout: 10),
                      "Performed search should be remembered in history")
    }

    // MARK: - Feature: Audio / Video Mode

    /// Scenario: Toggling video mode from the full player
    func testToggleVideoModeFromFullPlayer() throws {
        searchAndPlayFirstStream()
        XCTAssertTrue(app.staticTexts[fixtureNowPlayingTitle].waitForExistence(timeout: 15))
        app.staticTexts[fixtureNowPlayingTitle].firstMatch.tap()
        let showVideo = app.buttons["Show Video"]
        XCTAssertTrue(showVideo.waitForExistence(timeout: 10), "Full player should offer Show Video")
        showVideo.tap()
        XCTAssertTrue(app.buttons["Audio Only"].waitForExistence(timeout: 5), "Toggle should flip to Audio Only")
    }

    // MARK: - Helpers

    /// Type a query into the search field and submit.
    private func performSearch(_ term: String) {
        let field = app.searchFields.firstMatch.exists ? app.searchFields.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "A search field should be present")
        field.tap()
        field.typeText("\(term)\n")
    }

    /// Search, then play the first stream result, leaving the mini player active.
    private func searchAndPlayFirstStream() {
        app.buttons["Search"].tap()
        performSearch("anything")
        let playButton = app.buttons["playButton"].firstMatch
        XCTAssertTrue(playButton.waitForExistence(timeout: 15), "A play control should be present in results")
        playButton.tap()
    }
}
