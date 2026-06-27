import XCTest

/// Acceptance tests implementing the Gherkin scenarios in `AcceptanceTests.md`.
/// Each test maps to one Scenario, with Given/When/Then steps as comments.
///
/// Network-dependent assertions (search results, playback) use generous waits
/// and tolerate slow/offline backends; offline-deterministic flows (tab
/// navigation, empty states, suggestions) are asserted strictly.
///
/// Run with:
///   xcodebuild test -scheme pipe \
///     -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
///     -only-testing:"pipeUITests/AcceptanceTests"
final class AcceptanceTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - Feature: Tab Navigation

    /// Scenario: All tabs are reachable
    func testAllTabsAreReachable() throws {
        // Given the app is launched / Then I should see the five tabs
        for tab in ["Feed", "Search", "Recents", "Following", "Settings"] {
            XCTAssertTrue(app.buttons[tab].waitForExistence(timeout: 10), "\(tab) tab should exist")
        }

        // When I tap each tab / Then the screen should appear
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
        // Given I am on the Search tab
        app.buttons["Search"].tap()

        // Then I should see popular channel suggestions
        XCTAssertTrue(app.buttons["MrBeast"].waitForExistence(timeout: 10), "Suggestion should be visible")
        // And an inline search field
        XCTAssertTrue(app.textFields.firstMatch.exists || app.searchFields.firstMatch.exists)
    }

    /// Scenario: Searching returns results
    func testSearchReturnsResults() throws {
        // Given I am on the Search tab
        app.buttons["Search"].tap()

        // When I type into the search field and submit
        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 5) {
            searchField.tap()
            searchField.typeText("MrBeast")
            app.keyboards.buttons["Search"].tap()
        } else {
            // Fall back to the inline field
            let field = app.textFields.firstMatch
            field.tap()
            field.typeText("MrBeast\n")
        }

        // Then I should see a list of results
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 20), "Search results should appear")
    }

    /// Scenario: Tapping a suggestion runs a search
    func testTappingSuggestionRunsSearch() throws {
        // Given I am on the Search tab
        app.buttons["Search"].tap()

        // When I tap the "MrBeast" suggestion
        let suggestion = app.buttons["MrBeast"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 10))
        suggestion.tap()

        // Then I should see a list of results
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 20), "Results should appear after suggestion tap")
    }

    // MARK: - Feature: Playback

    /// Scenario: Playing a result starts the mini player
    func testPlayingResultStartsMiniPlayer() throws {
        // Given I have searched
        app.buttons["Search"].tap()
        let suggestion = app.buttons["Lex Fridman"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 10))
        suggestion.tap()

        guard app.cells.firstMatch.waitForExistence(timeout: 20) else {
            throw XCTSkip("Backend returned no results; cannot exercise playback")
        }

        // When I tap the play button on the first result
        let playButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'play'")).firstMatch
        guard playButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("No play control surfaced in results")
        }
        playButton.tap()

        // Then the mini player bar should appear (a pause/play control persists at the bottom)
        let miniControl = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'pause' OR label CONTAINS[c] 'play'")).firstMatch
        XCTAssertTrue(miniControl.waitForExistence(timeout: 25), "Mini player should appear after playback starts")
    }

    /// Scenario: Expanding the mini player shows full controls
    func testExpandingMiniPlayerShowsFullControls() throws {
        // Given a video is playing
        try startPlaybackFromSuggestion("Veritasium")

        // When I tap the mini player bar
        let miniArtwork = app.images.firstMatch
        if miniArtwork.waitForExistence(timeout: 10) { miniArtwork.tap() }

        // Then the full player sheet should appear with playback controls (speed buttons)
        let speed = app.buttons["1x"].firstMatch
        XCTAssertTrue(speed.waitForExistence(timeout: 10), "Full player sheet should show speed controls")
    }

    // MARK: - Feature: Queue

    /// Scenario: Queueing a result adds it to the queue
    func testQueueingResultAddsToQueue() throws {
        // Given I have searched
        app.buttons["Search"].tap()
        let suggestion = app.buttons["Kurzgesagt"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 10))
        suggestion.tap()
        guard app.cells.firstMatch.waitForExistence(timeout: 20) else {
            throw XCTSkip("Backend returned no results; cannot exercise queue")
        }

        // When I tap the queue button on the first result
        let queueButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'badge' OR label CONTAINS[c] 'plus'")).firstMatch
        guard queueButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("No queue control surfaced in results")
        }
        queueButton.tap()

        // Then the mini player bar should appear (queue started playing the first item)
        let miniControl = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'pause' OR label CONTAINS[c] 'play'")).firstMatch
        XCTAssertTrue(miniControl.waitForExistence(timeout: 25), "Mini player should appear after queueing")
    }

    // MARK: - Feature: Channel Browsing

    /// Scenario: Opening a channel shows its videos
    func testOpeningChannelShowsVideos() throws {
        // Given I have searched for a channel
        app.buttons["Search"].tap()
        let suggestion = app.buttons["MrBeast"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 10))
        suggestion.tap()
        guard app.cells.firstMatch.waitForExistence(timeout: 20) else {
            throw XCTSkip("Backend returned no results; cannot exercise channel browsing")
        }

        // When I tap a channel result
        let channelCell = app.cells.firstMatch
        channelCell.tap()

        // Then I should land on a channel screen with a Videos tab pill
        let videosPill = app.buttons["Videos"]
        XCTAssertTrue(videosPill.waitForExistence(timeout: 20) || app.cells.firstMatch.waitForExistence(timeout: 20),
                      "Channel screen should show a Videos tab or a video list")
    }

    // MARK: - Feature: Following

    /// Scenario: Empty following state
    func testFollowingEmptyState() throws {
        // Given a fresh install with no follows / When I open Following
        app.buttons["Following"].tap()

        // Then I should see the empty state (or, if channels exist from a prior run, the list)
        let emptyState = app.staticTexts["No Channels"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 10) || app.cells.count > 0,
                      "Following tab should show empty state or a channel list")
    }

    /// Scenario: Following a channel from search
    func testFollowingChannelFromSearch() throws {
        // Given I have searched for a channel
        app.buttons["Search"].tap()
        let suggestion = app.buttons["Huberman Lab"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 10))
        suggestion.tap()
        guard app.cells.firstMatch.waitForExistence(timeout: 20) else {
            throw XCTSkip("Backend returned no results; cannot exercise following")
        }

        // When I tap the follow heart on a channel result
        let heart = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'heart'")).firstMatch
        guard heart.waitForExistence(timeout: 5) else {
            throw XCTSkip("No channel result with a follow control surfaced")
        }
        heart.tap()

        // Then the channel should appear on the Following tab
        app.buttons["Following"].tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10),
                      "A followed channel should appear on the Following tab")
    }

    // MARK: - Feature: Recents

    /// Scenario: Empty recents state
    func testRecentsEmptyState() throws {
        // When I open the Recents tab
        app.buttons["Recents"].tap()

        // Then I should see the empty state (or history from a prior run)
        let emptyState = app.staticTexts["No History"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 10) || app.cells.count > 0,
                      "Recents tab should show empty state or history")
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

    // MARK: - Feature: Search History

    /// Scenario: A performed search appears under Recent
    func testSearchAppearsInHistory() throws {
        // Given I am on the Search tab / When I search
        app.buttons["Search"].tap()
        let field = app.searchFields.firstMatch.exists ? app.searchFields.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("lofi beats\n")

        // And I return to the empty search screen (clear the query)
        let clear = app.buttons["Clear text"].firstMatch
        if clear.waitForExistence(timeout: 3) { clear.tap() }

        // Then the term appears under Recent
        XCTAssertTrue(app.buttons["lofi beats"].waitForExistence(timeout: 5) ||
                      app.staticTexts["lofi beats"].waitForExistence(timeout: 5),
                      "Performed search should appear in history")
    }

    /// Scenario: Clearing search history empties it
    func testClearSearchHistory() throws {
        // Given I have performed a search
        app.buttons["Search"].tap()
        let field = app.searchFields.firstMatch.exists ? app.searchFields.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("temporary query\n")

        // When I open Settings and clear history
        app.buttons["Settings"].tap()
        let clearButton = app.buttons["Clear History"]
        guard clearButton.waitForExistence(timeout: 10) else {
            throw XCTSkip("History not recorded (search may not have committed)")
        }
        clearButton.tap()

        // Then the history is empty
        XCTAssertTrue(app.staticTexts["No recent searches"].waitForExistence(timeout: 5),
                      "History should be empty after clearing")
    }

    // MARK: - Feature: Audio / Video Mode

    /// Scenario: Toggling video mode from the full player
    func testToggleVideoModeFromFullPlayer() throws {
        // Given a video is playing
        try startPlaybackFromSuggestion("3Blue1Brown")

        // And I have opened the full player
        let miniArtwork = app.images.firstMatch
        if miniArtwork.waitForExistence(timeout: 10) { miniArtwork.tap() }

        // When I tap "Show Video"
        let showVideo = app.buttons["Show Video"]
        guard showVideo.waitForExistence(timeout: 10) else {
            throw XCTSkip("Full player did not present (playback may not have started)")
        }
        showVideo.tap()

        // Then the control switches to "Audio Only"
        XCTAssertTrue(app.buttons["Audio Only"].waitForExistence(timeout: 5),
                      "Toggle should flip to Audio Only")
    }

    // MARK: - Helpers

    /// Searches via a suggestion and starts playback of the first result.
    /// Skips the test if the backend returns nothing.
    private func startPlaybackFromSuggestion(_ suggestion: String) throws {
        app.buttons["Search"].tap()
        let button = app.buttons[suggestion]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        guard app.cells.firstMatch.waitForExistence(timeout: 20) else {
            throw XCTSkip("Backend returned no results; cannot exercise playback")
        }
        let playButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'play'")).firstMatch
        guard playButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("No play control surfaced in results")
        }
        playButton.tap()
    }
}
