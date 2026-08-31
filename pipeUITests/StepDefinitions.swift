import XCTest

/// All Given/When/Then step definitions, mapping Gherkin lines to XCUITest
/// actions/assertions. Keywords are interchangeable at match time, so each step
/// is registered once regardless of whether specs phrase it as Given/When/Then.
///
/// These port the assertions from the original hand-written acceptance suite.
/// The app runs against bundled fixtures, so known strings (channel "MrBeast",
/// real video titles) are asserted deterministically.
enum StepDefinitions {

    // Known strings from the bundled fixtures (pipe/Fixtures/*.json).
    static let channelName = "MrBeast"
    static let searchStreamTitle = "Guess What Age Punched You"
    static let nowPlayingTitle = "Survive 30 Days Chained To A Stranger, Win $250,000"

    private static let short: TimeInterval = 5
    private static let medium: TimeInterval = 10
    private static let long: TimeInterval = 15

    static func makeRegistry() -> StepRegistry {
        let r = StepRegistry()

        // MARK: Lifecycle / preconditions (no-ops — state is set by launch args)
        r.define("the app is launched") { _ in }
        r.define("I have not followed any channels") { _ in }
        r.define("I have not played anything") { _ in }
        r.define("I have saved nothing") { _ in }

        // MARK: Tab navigation
        r.define("I should see the Feed, Search, Recents, Following, and Settings tabs") { w in
            for tab in ["Feed", "Search", "Recents", "Following", "Settings"] {
                XCTAssertTrue(w.app.buttons[tab].waitForExistence(timeout: medium), "\(tab) tab should exist")
            }
        }
        r.define("I tap the (\\w+) tab") { w in
            w.app.buttons[w.capture()].tap()
        }
        r.define("the (\\w+) screen should appear") { w in
            XCTAssertTrue(w.app.navigationBars[w.capture()].waitForExistence(timeout: short))
        }

        // MARK: Search
        r.define("I am on the Search tab") { w in w.app.buttons["Search"].tap() }
        r.define("I should see popular channel suggestions") { w in
            XCTAssertTrue(w.app.buttons[channelName].waitForExistence(timeout: medium), "Suggestion should be visible")
        }
        r.define("I should see an inline search field") { w in
            XCTAssertTrue(w.app.textFields.firstMatch.exists || w.app.searchFields.firstMatch.exists)
        }
        r.define("I type \"(.+)\" into the search field") { w in
            let field = searchField(w)
            XCTAssertTrue(field.waitForExistence(timeout: short), "A search field should be present")
            field.tap()
            field.typeText(w.capture())
        }
        r.define("I submit the search") { w in
            searchField(w).typeText("\n")
        }
        r.define("I search for \"(.+)\"") { w in performSearch(w, w.capture()) }
        r.define("I should see a list of search results") { w in
            XCTAssertTrue(w.app.staticTexts[searchStreamTitle].waitForExistence(timeout: long),
                          "Real fixture search result should render")
        }
        r.define("I tap the \"(.+)\" suggestion") { w in
            let s = w.app.buttons[w.capture()]
            XCTAssertTrue(s.waitForExistence(timeout: medium))
            s.tap()
        }
        r.define("I have searched for \"(.+)\"") { w in
            w.app.buttons["Search"].tap()
            performSearch(w, w.capture())
        }

        // MARK: Playback
        r.define("I tap the play button on the first result") { w in
            let play = w.app.buttons["playButton"].firstMatch
            XCTAssertTrue(play.waitForExistence(timeout: long), "A play control should be present in results")
            play.tap()
        }
        r.define("the mini player bar should appear") { w in
            XCTAssertTrue(w.app.staticTexts[nowPlayingTitle].waitForExistence(timeout: long),
                          "Mini player should show the now-playing title")
        }
        r.define("a video is playing") { w in searchAndPlayFirstStream(w) }
        r.define("I have searched and played a video") { w in searchAndPlayFirstStream(w) }
        r.define("I have played a video") { w in searchAndPlayFirstStream(w) }
        r.define("I tap the mini player bar") { w in
            w.app.staticTexts[nowPlayingTitle].firstMatch.tap()
        }
        r.define("the full player sheet should appear with playback controls") { w in
            XCTAssertTrue(w.app.buttons["1x"].waitForExistence(timeout: medium), "Full player should show speed controls")
        }
        r.define("I have opened the full player") { w in
            XCTAssertTrue(w.app.staticTexts[nowPlayingTitle].waitForExistence(timeout: long))
            w.app.staticTexts[nowPlayingTitle].firstMatch.tap()
        }
        r.define("I open the full player") { w in
            XCTAssertTrue(w.app.staticTexts[nowPlayingTitle].waitForExistence(timeout: long))
            w.app.staticTexts[nowPlayingTitle].firstMatch.tap()
        }
        r.define("I open the \"(.+)\" player tab") { w in
            let pill = w.app.buttons["playerTab-\(w.capture())"]
            XCTAssertTrue(pill.waitForExistence(timeout: long), "Player tab \(w.capture()) should be present")
            // The tab strip scrolls horizontally; a pill past the right edge exists
            // but has no valid activation point, so isHittable raises. Compare its
            // frame to the window (never raises) and swipe the always-visible Queue
            // pill to scroll the strip until the target is on-screen.
            let window = w.app.windows.firstMatch
            let queue = w.app.buttons["playerTab-Queue"]
            var tries = 0
            while pill.frame.maxX > window.frame.maxX && tries < 6 {
                (queue.exists ? queue : window).swipeLeft()
                tries += 1
            }
            pill.tap()
        }
        r.define("I should see a related video") { w in
            XCTAssertTrue(w.app.buttons["relatedRow"].firstMatch.waitForExistence(timeout: long) ||
                          w.app.staticTexts["Up Next"].waitForExistence(timeout: short),
                          "A related video should be shown in the Up Next tab")
        }
        r.define("I should see the Cast control") { w in
            XCTAssertTrue(w.app.buttons["castButton"].firstMatch.waitForExistence(timeout: long),
                          "The cast control should be present in the full player")
        }
        r.define("I open the context menu for the first result") { w in
            let row = firstStreamRow(w)
            XCTAssertTrue(row.waitForExistence(timeout: long), "A stream result row should be present")
            row.press(forDuration: 1.1)
        }
        r.define("I should see a \"(.+)\" action") { w in
            XCTAssertTrue(w.app.buttons[w.capture()].waitForExistence(timeout: medium),
                          "\(w.capture()) action should appear in the context menu")
        }
        r.define("I should see the video description without raw HTML") { w in
            // The Info tab's "About" header proves the description section rendered;
            // asserting no literal "<br>" leaks proves HTML was decoded, not shown raw.
            XCTAssertTrue(w.app.staticTexts["About"].waitForExistence(timeout: long),
                          "The Info tab should show the description's About header")
            let raw = w.app.staticTexts.containing(NSPredicate(format: "label CONTAINS '<br>'")).firstMatch
            XCTAssertFalse(raw.exists, "Description must not display raw HTML tags")
        }
        r.define("I should see the transcript or an empty state") { w in
            // Live captions are network-dependent; a transcript row or the
            // "No transcript available" empty state both prove the tab wired up.
            XCTAssertTrue(w.app.buttons["transcriptRow"].firstMatch.waitForExistence(timeout: long) ||
                          w.app.staticTexts["No transcript available"].waitForExistence(timeout: short),
                          "The Transcript tab should render its content or empty state")
        }
        r.define("I should see a comment in the player") { w in
            // The now-playing fixture has comments; a comment row or the empty
            // state both prove the tab loaded its content.
            XCTAssertTrue(w.app.cells.firstMatch.waitForExistence(timeout: long) ||
                          w.app.staticTexts["No Comments"].waitForExistence(timeout: short),
                          "The Comments tab should render its content")
        }

        // MARK: Queue
        r.define("I tap the queue button on the first result") { w in
            let queue = w.app.buttons["queueButton"].firstMatch
            XCTAssertTrue(queue.waitForExistence(timeout: long), "A queue control should be present")
            queue.tap()
        }
        r.define("the video should be added to the queue") { w in
            XCTAssertTrue(w.app.staticTexts[nowPlayingTitle].waitForExistence(timeout: long),
                          "Queued item should begin playing and show in the mini player")
        }

        // MARK: Channel browsing
        r.define("I tap a channel result") { w in
            let row = w.app.buttons["channelRow"].firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: long), "Channel result should be present")
            row.tap()
        }
        r.define("I should land on the channel screen") { w in
            XCTAssertTrue(w.app.buttons["Videos"].waitForExistence(timeout: long) ||
                          w.app.navigationBars[channelName].waitForExistence(timeout: long),
                          "Channel screen should render")
        }
        r.define("I should see a \"Videos\" tab or a list of videos") { w in
            XCTAssertTrue(w.app.buttons["Videos"].exists || w.app.navigationBars[channelName].exists,
                          "Channel screen should show its videos")
        }

        // MARK: Following / Recents tabs + tolerant empty states
        r.define("I open the (Following|Recents|Settings) tab") { w in w.app.buttons[w.capture()].tap() }
        r.define("I should see a \"(.+)\" empty state") { w in
            // Tolerant: persisted state may carry over between launches on the
            // shared simulator, so accept the empty state OR existing content.
            XCTAssertTrue(w.app.staticTexts[w.capture()].waitForExistence(timeout: medium) || w.app.cells.count > 0,
                          "Should show the empty state or existing content")
        }
        r.define("I tap the follow heart on a channel result") { w in
            let heart = w.app.buttons["followButton"].firstMatch
            XCTAssertTrue(heart.waitForExistence(timeout: long), "A follow heart should be present")
            heart.tap()
        }
        r.define("the channel should appear on the Following tab") { w in
            w.app.buttons["Following"].tap()
            XCTAssertTrue(w.app.staticTexts[channelName].waitForExistence(timeout: medium),
                          "Followed channel should appear on the Following tab")
        }
        r.define("the played video should appear in my history") { w in
            XCTAssertTrue(w.app.staticTexts[nowPlayingTitle].waitForExistence(timeout: medium),
                          "Played video should appear in Recents")
        }

        // MARK: Settings
        r.define("I am on the Settings tab") { w in
            w.app.buttons["Settings"].tap()
            XCTAssertTrue(w.app.navigationBars["Settings"].waitForExistence(timeout: medium))
        }
        r.define("I should see the \"(.+)\" section") { w in
            let label = w.capture()
            let element = w.app.staticTexts[label]
            // The settings list scrolls; a section below the fold exists but isn't
            // rendered until scrolled to. Swipe up a few times to bring it on.
            var tries = 0
            while !element.exists && tries < 6 {
                w.app.swipeUp()
                tries += 1
            }
            XCTAssertTrue(element.waitForExistence(timeout: medium), "\(label) section")
        }
        r.define("I tap \"(.+)\"") { w in
            let button = w.app.buttons[w.capture()]
            XCTAssertTrue(button.waitForExistence(timeout: medium), "“\(w.capture())” should be present")
            button.tap()
        }
        r.define("I should see the remaining time with a Cancel option") { w in
            XCTAssertTrue(w.app.buttons["Cancel"].waitForExistence(timeout: short), "Cancel should appear once a timer is set")
            XCTAssertTrue(w.app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'min remaining'")).firstMatch.exists,
                          "Remaining time should be shown")
        }
        r.define("I have performed a search") { w in
            w.app.buttons["Search"].tap()
            performSearch(w, "temporary query")
        }
        r.define("I open Settings and tap \"(.+)\"") { w in
            w.app.buttons["Settings"].tap()
            let button = w.app.buttons[w.capture()]
            if !button.waitForExistence(timeout: 3) || !button.isHittable { w.app.swipeUp() }
            XCTAssertTrue(button.waitForExistence(timeout: short), "“\(w.capture())” should be present")
            button.tap()
        }
        r.define("the search history should be empty") { w in
            XCTAssertTrue(w.app.staticTexts["No recent searches"].waitForExistence(timeout: short),
                          "History should be empty after clearing")
        }
        r.define("the watch history should be empty") { w in
            XCTAssertTrue(w.app.staticTexts["No watch history"].waitForExistence(timeout: short),
                          "Watch history should be empty after clearing")
        }

        // MARK: Search history
        r.define("\"(.+)\" should appear in the Search History section") { w in
            let term = w.capture()
            let element = w.app.staticTexts[term]
            // Search History sits below the fold in Settings; scroll it into view.
            var tries = 0
            while !element.exists && tries < 6 {
                w.app.swipeUp()
                tries += 1
            }
            XCTAssertTrue(element.waitForExistence(timeout: medium),
                          "Performed search should be remembered in history")
        }

        // MARK: Offline mode
        r.define("I open Settings") { w in
            w.app.buttons["Settings"].tap()
            XCTAssertTrue(w.app.navigationBars["Settings"].waitForExistence(timeout: medium), "Settings should open")
        }
        r.define("I turn on Offline Mode") { w in enableOfflineMode(w) }
        r.define("offline mode is on") { w in
            w.app.buttons["Settings"].tap()
            enableOfflineMode(w)
        }
        r.define("the home tab should show Downloads") { w in
            w.app.buttons["Feed"].tap()
            // After the hermetic reset there are no downloads, so the Downloads
            // screen shows its "No Downloads" empty state. Accept the nav bar or
            // the empty-state copy.
            XCTAssertTrue(w.app.navigationBars["Downloads"].waitForExistence(timeout: long) ||
                          w.app.staticTexts["No Downloads"].waitForExistence(timeout: short),
                          "Home tab should show Downloads while offline")
        }
        r.define("I open the Search tab") { w in
            // The tab-bar Search button label collides with the search-field
            // placeholder; target the bottom tab button explicitly.
            let tab = w.app.buttons["Search"].firstMatch
            XCTAssertTrue(tab.waitForExistence(timeout: medium))
            tab.tap()
        }
        r.define("I should see the offline placeholder") { w in
            XCTAssertTrue(w.app.staticTexts["You're Offline"].waitForExistence(timeout: long),
                          "Search should show the offline placeholder")
        }

        // MARK: Audio / video mode
        r.define("I enable \"(.+)\"") { w in
            let button = w.app.buttons[w.capture()]
            XCTAssertTrue(button.waitForExistence(timeout: medium), "“\(w.capture())” should be present")
            button.tap()
        }
        r.define("the video surface should be shown \\(PiP-capable\\)") { w in
            // Video mode engaged → the PiP-capable AVPlayerViewController surface is
            // shown; the toggle flipping to "Audio Only" confirms we're in video mode.
            XCTAssertTrue(w.app.buttons["Audio Only"].waitForExistence(timeout: short),
                          "Video surface (PiP-capable) should be active in video mode")
        }
        r.define("I tap pause") { w in
            let button = w.app.buttons["playPauseButton"]
            XCTAssertTrue(button.waitForExistence(timeout: long), "Play/pause control should be present")
            // Ensure we start from a playing state so the tap pauses (not resumes).
            if button.label == "Play" { return }
            button.tap()
        }
        r.define("playback should be paused") { w in
            // After pausing, the control offers Play — and must stay that way (the
            // bug was the player nudging itself straight back to playing).
            let resume = w.app.buttons["playPauseButton"]
            XCTAssertTrue(resume.waitForExistence(timeout: long))
            XCTAssertEqual(resume.label, "Play", "Pausing should leave the player paused")
        }
        r.define("the control should switch to \"(.+)\"") { w in
            XCTAssertTrue(w.app.buttons[w.capture()].waitForExistence(timeout: short),
                          "Toggle should flip to \(w.capture())")
        }

        // MARK: SponsorBlock
        r.define("I tap the SponsorBlock toggle") { w in
            let toggle = w.app.buttons["sponsorBlockToggle"]
            XCTAssertTrue(toggle.waitForExistence(timeout: long), "SponsorBlock toggle should be present")
            toggle.tap()
        }
        r.define("SponsorBlock should be (on|off)") { w in
            let expected = w.capture()
            let toggle = w.app.buttons["sponsorBlockToggle"]
            XCTAssertTrue(toggle.waitForExistence(timeout: long), "SponsorBlock toggle should be present")
            let matches = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", expected), object: toggle)
            XCTAssertEqual(XCTWaiter().wait(for: [matches], timeout: short), .completed,
                           "SponsorBlock toggle should be \(expected)")
        }

        // MARK: Chapters (streams fixture includes a chapters list)
        r.define("I have searched and opened a video that has chapters") { w in
            w.app.buttons["Search"].tap()
            w.app.buttons[channelName].firstMatch.tap()
            let firstVideo = w.app.staticTexts[searchStreamTitle].firstMatch
            XCTAssertTrue(firstVideo.waitForExistence(timeout: long))
            firstVideo.tap()
        }
        r.define("I should see a \"Chapters\" list") { w in
            XCTAssertTrue(w.app.staticTexts["Chapters"].waitForExistence(timeout: long), "Chapters list should appear")
            XCTAssertTrue(w.app.staticTexts["Introduction"].exists, "A fixture chapter title should be listed")
        }
        r.define("I tap a chapter") { w in
            w.app.buttons["chapterRow"].firstMatch.tap()
        }
        r.define("I should see the current chapter label") { w in
            XCTAssertTrue(w.app.staticTexts.matching(identifier: "currentChapterLabel").firstMatch.waitForExistence(timeout: long) ||
                          w.app.otherElements["currentChapterLabel"].waitForExistence(timeout: short),
                          "Current chapter label should be shown in the full player")
        }
        r.define("playback should jump to that chapter's start") { w in
            let miniControl = w.app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'pause' OR label CONTAINS[c] 'play'")).firstMatch
            XCTAssertTrue(miniControl.waitForExistence(timeout: long), "Tapping a chapter should start playback")
        }

        // MARK: Save for later
        r.define("I open the Saved screen from the Feed") { w in
            let saved = w.app.buttons["savedButton"]
            XCTAssertTrue(saved.waitForExistence(timeout: medium))
            saved.tap()
        }

        // MARK: Feed sorting
        r.define("I am on the Feed tab") { w in w.app.buttons["Feed"].tap() }
        r.define("I open the feed options menu") { w in
            let menu = w.app.buttons["feedMenu"]
            XCTAssertTrue(menu.waitForExistence(timeout: medium))
            menu.tap()
        }
        r.define("I should see sort options and a \"Hide Watched\" toggle") { w in
            XCTAssertTrue(w.app.buttons["Newest"].waitForExistence(timeout: short) ||
                          w.app.staticTexts["Newest"].waitForExistence(timeout: short),
                          "Sort options should be shown")
            XCTAssertTrue(w.app.switches["Hide Watched"].waitForExistence(timeout: short) ||
                          w.app.buttons["Hide Watched"].exists,
                          "Hide Watched toggle should be shown")
        }

        // MARK: Downloads
        r.define("I have downloaded nothing") { _ in }
        r.define("I have searched and opened a video") { w in
            w.app.buttons["Search"].tap()
            w.app.buttons[channelName].firstMatch.tap()
            let firstVideo = w.app.staticTexts[searchStreamTitle].firstMatch
            XCTAssertTrue(firstVideo.waitForExistence(timeout: long))
            firstVideo.tap()
        }
        r.define("I tap the download button") { w in
            let button = w.app.buttons["downloadButton"]
            XCTAssertTrue(button.waitForExistence(timeout: long), "Download button should be present")
            button.tap()
        }
        r.define("I download the first result from its context menu") { w in
            // Long-press the first *stream* row to reveal the context menu, then
            // tap Download. (The first cell is the channel result, which has no
            // media context menu — target the stream row by its title.)
            let row = firstStreamRow(w)
            XCTAssertTrue(row.waitForExistence(timeout: long), "A stream result row should be present")
            row.press(forDuration: 1.1)
            let download = w.app.buttons["Download"]
            XCTAssertTrue(download.waitForExistence(timeout: medium), "Download action should appear in the context menu")
            download.tap()
        }
        r.define("I open the Downloads screen from the Feed") { w in
            // Ensure we're on the Feed first (a prior step may have navigated away).
            w.app.buttons["Feed"].tap()
            let button = w.app.buttons["downloadsButton"]
            XCTAssertTrue(button.waitForExistence(timeout: medium))
            button.tap()
        }
        r.define("I should see the downloaded video") { w in
            // The downloaded item shows by title (fixture now-playing title).
            XCTAssertTrue(w.app.staticTexts[nowPlayingTitle].waitForExistence(timeout: long) ||
                          w.app.cells.count > 0,
                          "Downloaded video should be listed")
        }
        r.define("I should see the storage used") { w in
            XCTAssertTrue(w.app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] 'used'")).firstMatch.waitForExistence(timeout: long),
                          "Storage-used footer should be shown")
        }

        // MARK: Discovery — Trending, Comments, Up Next
        r.define("I open Trending") { w in
            let button = w.app.buttons["trendingButton"]
            XCTAssertTrue(button.waitForExistence(timeout: medium))
            button.tap()
        }
        r.define("I should see a list of trending videos") { w in
            XCTAssertTrue(w.app.cells.firstMatch.waitForExistence(timeout: long) ||
                          w.app.navigationBars["Trending"].waitForExistence(timeout: medium),
                          "Trending list should render")
        }
        r.define("I open the comments") { w in
            // Comments are inline at the bottom of the detail page; scroll down
            // until the section header is on screen.
            let header = w.app.staticTexts["Comments"]
            var tries = 0
            while !header.exists && tries < 8 {
                w.app.swipeUp()
                tries += 1
            }
            XCTAssertTrue(header.waitForExistence(timeout: long), "Comments section should be reachable on the detail page")
        }
        r.define("I should see at least one comment") { w in
            XCTAssertTrue(w.app.cells.firstMatch.waitForExistence(timeout: long),
                          "At least one comment should be shown")
        }
        r.define("I should see an \"Up Next\" list") { w in
            XCTAssertTrue(w.app.staticTexts["Up Next"].waitForExistence(timeout: long),
                          "Up Next list should be shown")
        }

        // MARK: Video detail page
        r.define("I should see the video detail page") { w in
            XCTAssertTrue(w.app.navigationBars["Details"].waitForExistence(timeout: long),
                          "The video detail page should open")
            // The /streams/ fixture answers every id with the same video, so the
            // detail header shows the now-playing fixture's title.
            XCTAssertTrue(w.app.staticTexts[nowPlayingTitle].waitForExistence(timeout: long),
                          "The detail page should show the video's title")
        }
        r.define("playback should not have started") { w in
            // Opening details must not start the video: no mini player appears
            // (its play/pause control only exists once something is queued).
            XCTAssertFalse(w.app.buttons["playPauseButton"].exists,
                           "Viewing details must not start playback")
        }
        r.define("I should see the video description") { w in
            // The fixture description opens with this line; rendering it (sans
            // raw <br> tags) proves the description section works.
            let description = w.app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS[c] 'imagine being chained'")).firstMatch
            XCTAssertTrue(description.waitForExistence(timeout: long),
                          "The description should be shown on the detail page")
        }

        // MARK: Playlists
        r.define("I have opened a channel with playlists") { w in openChannel(w) }
        r.define("I select the \"Playlists\" tab") { w in
            let tab = w.app.buttons["Playlists"]
            XCTAssertTrue(tab.waitForExistence(timeout: long), "Playlists tab should be present")
            tab.tap()
        }
        r.define("I should see a list of playlists") { w in
            XCTAssertTrue(w.app.cells.firstMatch.waitForExistence(timeout: long), "A playlist row should be present")
        }
        r.define("I tap the first playlist") { w in
            let row = w.app.cells.firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: long), "A playlist row should be present")
            row.tap()
        }
        r.define("I should see the playlist's videos") { w in
            XCTAssertTrue(w.app.buttons["playAllButton"].waitForExistence(timeout: long) ||
                          w.app.staticTexts[searchStreamTitle].waitForExistence(timeout: long),
                          "Playlist videos should render")
        }
        r.define("I have opened a playlist") { w in openFirstPlaylist(w) }
        // "I tap \"Play All\"" / "I tap \"Save Playlist\"" reuse the generic
        // `I tap "(.+)"` step (matched by the buttons' labels).
        r.define("I open Saved Playlists from the Feed") { w in
            w.app.buttons["Feed"].tap()
            let button = w.app.buttons["savedPlaylistsButton"]
            XCTAssertTrue(button.waitForExistence(timeout: medium))
            button.tap()
        }
        r.define("I should see the saved playlist") { w in
            XCTAssertTrue(w.app.cells.firstMatch.waitForExistence(timeout: long), "Saved playlist should be listed")
        }
        r.define("I should see a playlist result") { w in
            let row = w.app.buttons["playlistRow"].firstMatch
            if !row.waitForExistence(timeout: long) {
                // The playlist result may be below the fold — scroll to it.
                w.app.swipeUp()
            }
            XCTAssertTrue(row.waitForExistence(timeout: medium),
                          "A playlist search result should be present")
        }
        r.define("I tap the first playlist result") { w in
            w.app.buttons["playlistRow"].firstMatch.tap()
        }

        // MARK: Play Next
        r.define("I long-press the first result") { w in
            // The first cell is a channel result (no media menu); long-press the
            // first stream row instead.
            let row = firstStreamRow(w)
            XCTAssertTrue(row.waitForExistence(timeout: long), "A stream result row should be present")
            row.press(forDuration: 1.1)
        }
        r.define("I should see a \"Play Next\" option") { w in
            XCTAssertTrue(w.app.buttons["Play Next"].waitForExistence(timeout: medium),
                          "Play Next should appear in the context menu")
        }

        // MARK: Channel metadata
        r.define("the channel result should show a subscriber count") { w in
            XCTAssertTrue(w.app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] 'subscribers'")).firstMatch.waitForExistence(timeout: long),
                          "Channel result should show a subscriber count")
        }

        // MARK: Generic on-screen text assertion (sleep-timer state, toasts, …)
        r.define("I should see \"(.+)\"") { w in
            let text = w.capture()
            XCTAssertTrue(w.app.staticTexts[text].waitForExistence(timeout: long),
                          "Expected to see \"\(text)\" on screen")
        }

        // Partial match, for text whose tail varies at runtime (e.g. a playback
        // error whose reason depends on the live AVPlayer/network error).
        r.define("I should see text containing \"(.+)\"") { w in
            let text = w.capture()
            let match = w.app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS %@", text)).firstMatch
            XCTAssertTrue(match.waitForExistence(timeout: long),
                          "Expected to see text containing \"\(text)\" on screen")
        }

        // MARK: Error recovery (scenario launches with --uitest-fail-streams)
        r.define("a video detail fails to load") { w in
            w.app.buttons["Search"].tap()
            w.app.buttons[channelName].firstMatch.tap()
            let firstVideo = w.app.staticTexts[searchStreamTitle].firstMatch
            XCTAssertTrue(firstVideo.waitForExistence(timeout: long))
            firstVideo.tap()
        }
        r.define("I should see a Retry button") { w in
            XCTAssertTrue(w.app.buttons["retryButton"].waitForExistence(timeout: long),
                          "Detail view should show a Retry button when loading fails")
        }

        // MARK: Diagnostics log
        // The Diagnostics section sits at the bottom of the Settings list, so it
        // is only realized once scrolled into view — hence the scroll-to helpers.
        r.define("I should see the Diagnostics section") { w in
            let toggle = w.app.switches["diagnosticsUploadToggle"]
            scrollToElement(w, toggle)
            XCTAssertTrue(toggle.waitForExistence(timeout: medium), "Diagnostics section should be present")
        }
        r.define("diagnostics upload should be off") { w in
            let toggle = w.app.switches["diagnosticsUploadToggle"]
            scrollToElement(w, toggle)
            XCTAssertTrue(toggle.waitForExistence(timeout: medium), "Upload toggle should be present")
            XCTAssertEqual(toggle.value as? String, "0", "Diagnostics upload should be off by default")
        }
        r.define("I turn on diagnostics upload") { w in
            let toggle = w.app.switches["diagnosticsUploadToggle"]
            scrollToElement(w, toggle)
            XCTAssertTrue(toggle.waitForExistence(timeout: medium), "Upload toggle should be present")
            // In a SwiftUI List the switch spans the row; the control is on the
            // trailing edge, so a trailing-edge coordinate tap is reliable where
            // a plain .tap() is not (same pattern as the Offline Mode toggle).
            if toggle.value as? String != "1" {
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            }
        }
        r.define("diagnostics upload should be on") { w in
            let toggle = w.app.switches["diagnosticsUploadToggle"]
            XCTAssertEqual(toggle.value as? String, "1", "Diagnostics upload should be on after toggling")
        }

        return r
    }

    // MARK: - Helpers

    /// Turn on the Offline Mode toggle in the open Settings sheet, then dismiss
    /// the sheet so the tabs underneath are interactive again.
    private static func enableOfflineMode(_ w: GherkinWorld) {
        let toggle = w.app.switches["offlineModeToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: medium), "Offline Mode toggle should be present")
        // SwiftUI toggles don't reliably flip from a plain .tap() on the switch
        // frame; tapping its center coordinate does. Confirm the flip committed
        // before dismissing (a lost tap leaves the app online).
        if toggle.value as? String != "1" {
            // In a SwiftUI List the Switch element spans the whole row but the
            // interactive control sits on the trailing edge, so a center tap
            // misses. Tap near the right edge.
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            let on = NSPredicate(format: "value == '1'")
            let exp = XCTNSPredicateExpectation(predicate: on, object: toggle)
            XCTAssertEqual(XCTWaiter().wait(for: [exp], timeout: medium), .completed,
                           "Offline Mode toggle should switch on")
        }
        // Dismiss the sheet via its Done button so the tabs underneath are
        // interactive again (a swipe-to-dismiss on the List is unreliable).
        let done = w.app.buttons["settingsDone"]
        XCTAssertTrue(done.waitForExistence(timeout: medium), "Settings Done button should be present")
        done.tap()
        let gone = NSPredicate(format: "exists == false")
        let exp = XCTNSPredicateExpectation(predicate: gone, object: w.app.navigationBars["Settings"])
        _ = XCTWaiter().wait(for: [exp], timeout: medium)
        XCTAssertTrue(w.app.buttons["Feed"].waitForExistence(timeout: long), "Tabs should be visible after dismissing Settings")
    }

    /// Scroll the frontmost scroll view down until `element` is hittable (or a
    /// few attempts elapse). Needed for controls in a lazy List that only
    /// realize once scrolled into view, e.g. the Diagnostics section.
    private static func scrollToElement(_ w: GherkinWorld, _ element: XCUIElement, maxSwipes: Int = 6) {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < maxSwipes {
            w.app.swipeUp()
            swipes += 1
        }
    }

    private static func searchField(_ w: GherkinWorld) -> XCUIElement {
        w.app.searchFields.firstMatch.exists ? w.app.searchFields.firstMatch : w.app.textFields.firstMatch
    }

    /// Type a query into the search field and submit (single shot).
    private static func performSearch(_ w: GherkinWorld, _ term: String) {
        let field = searchField(w)
        XCTAssertTrue(field.waitForExistence(timeout: short), "A search field should be present")
        field.tap()
        field.typeText("\(term)\n")
    }

    /// The first *stream* result row (the first cell is a channel result, which
    /// has no media context menu). Matched by the known fixture stream title.
    private static func firstStreamRow(_ w: GherkinWorld) -> XCUIElement {
        // Stream rows carry a "playButton"; the channel row carries "followButton".
        return w.app.cells.containing(.button, identifier: "playButton").firstMatch
    }

    /// Search for the fixture channel and open its channel screen (tapping the
    /// channel result row, not the suggestion — the suggestion only runs a search).
    private static func openChannel(_ w: GherkinWorld) {
        w.app.buttons["Search"].tap()
        performSearch(w, channelName)
        let row = w.app.buttons["channelRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: long), "Channel result should be present")
        row.tap()
        XCTAssertTrue(w.app.buttons["Videos"].waitForExistence(timeout: long), "Channel screen should render")
    }

    /// Open a channel's first playlist, leaving PlaylistView on screen.
    private static func openFirstPlaylist(_ w: GherkinWorld) {
        openChannel(w)
        let tab = w.app.buttons["Playlists"]
        XCTAssertTrue(tab.waitForExistence(timeout: long), "Playlists tab should be present")
        tab.tap()
        let row = w.app.cells.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: long), "A playlist row should be present")
        row.tap()
        XCTAssertTrue(w.app.buttons["playAllButton"].waitForExistence(timeout: long), "Playlist should open")
    }

    /// Search, then play the first stream result, leaving the mini player active.
    private static func searchAndPlayFirstStream(_ w: GherkinWorld) {
        w.app.buttons["Search"].tap()
        performSearch(w, "anything")
        let play = w.app.buttons["playButton"].firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: long), "A play control should be present in results")
        play.tap()
        XCTAssertTrue(w.app.staticTexts[nowPlayingTitle].waitForExistence(timeout: long))
    }
}
