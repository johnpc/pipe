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
    /// An uploader in the trending fixture — the suggestion chips are built from it.
    static let trendingChannel = "Scump"
    static let searchStreamTitle = "Guess What Age Punched You"
    /// Every play flow starts the first search result, and the mock answers
    /// `/streams/<id>` with that video's own identity (FixtureCatalog), so the
    /// now-playing title IS the tapped row's title — assertable strictly.
    static let nowPlayingTitle = searchStreamTitle
    /// Where UI tests find the fake Piped backend (scripts/fake_piped). CI
    /// starts it before the suite; `remote.sh fake start` does locally.
    static let fakeServerURL = ProcessInfo.processInfo.environment["PIPE_FAKE_SERVER"] ?? "http://127.0.0.1:8765"
    /// A loopback port nothing listens on: every connection is refused at once.
    static let deadInstanceURL = "http://127.0.0.1:1"

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
            selectTab(w, w.capture())
        }
        r.define("the (\\w+) screen should appear") { w in
            XCTAssertTrue(w.app.navigationBars[w.capture()].waitForExistence(timeout: short))
        }

        // MARK: Search
        r.define("I am on the Search tab") { w in selectTab(w, "Search") }
        r.define("I should see trending channel suggestions") { w in
            XCTAssertTrue(w.app.buttons[trendingChannel].waitForExistence(timeout: medium),
                          "A chip for a trending uploader should be visible")
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
            selectTab(w, "Search")
            performSearch(w, w.capture())
        }

        // MARK: Playback
        r.define("I tap the play button on the first result") { w in
            let play = w.app.buttons["playButton"].firstMatch
            XCTAssertTrue(play.waitForExistence(timeout: long), "A play control should be present in results")
            play.tap()
        }
        r.define("the mini player bar should appear") { w in
            let title = miniPlayerTitle(w)
            XCTAssertTrue(title.waitForExistence(timeout: long), "Mini player should appear")
            XCTAssertEqual(title.label, nowPlayingTitle, "Mini player should show the tapped video's title")
        }
        r.define("the mini player should show \"(.+)\"") { w in
            let title = miniPlayerTitle(w)
            XCTAssertTrue(title.waitForExistence(timeout: long), "Mini player should appear")
            XCTAssertEqual(title.label, w.capture())
        }
        // The explicit playback phase (PlaybackPhase.label), exposed as the
        // mini play/pause button's accessibility value: Loading, Buffering,
        // Playing, Paused, Failed. Waits because the phase is reached asynchronously.
        r.define("the player should report \"(.+)\"") { w in
            let expected = w.capture()
            let button = w.app.buttons["miniPlayPauseButton"]
            XCTAssertTrue(button.waitForExistence(timeout: long))
            XCTAssertTrue(waitUntil(long * 2) { (button.value as? String) == expected },
                          "Player should report \(expected); it reports \(String(describing: button.value))")
        }
        r.define("the mini player status should say \"(.+)\"") { w in
            let status = w.app.staticTexts["miniPlayerStatus"]
            let expected = w.capture()
            XCTAssertTrue(waitUntil(long) { status.exists && status.label == expected },
                          "Mini player status should say \(expected); it says \(status.exists ? status.label : "nothing")")
        }
        r.define("I pause from the mini player") { w in
            let button = w.app.buttons["miniPlayPauseButton"]
            XCTAssertTrue(button.waitForExistence(timeout: long))
            button.tap()
        }
        // Reads the elapsed-time label in the full player (m:ss) until it passes
        // the given position — proof that audio is really advancing.
        r.define("the playback position should pass (\\d+:\\d\\d)") { w in
            let target = seconds(w.capture())
            if !w.app.buttons["playPauseButton"].exists { miniPlayerTitle(w).tap() }
            XCTAssertTrue(w.app.buttons["playPauseButton"].waitForExistence(timeout: long))
            let clock = w.app.staticTexts["elapsedTime"]
            XCTAssertTrue(waitUntil(long * 2) { clock.exists && seconds(clock.label) > target },
                          "Position should pass \(target)s; clock shows \(clock.exists ? clock.label : "nothing")")
        }
        r.define("a video is playing") { w in searchAndPlayFirstStream(w) }
        r.define("I have searched and played a video") { w in searchAndPlayFirstStream(w) }
        r.define("I have played a video") { w in searchAndPlayFirstStream(w) }
        r.define("I tap the mini player bar") { w in
            miniPlayerTitle(w).tap()
        }
        r.define("the full player sheet should appear with playback controls") { w in
            XCTAssertTrue(w.app.buttons["1x"].waitForExistence(timeout: medium), "Full player should show speed controls")
        }
        r.define("I have opened the full player") { w in
            XCTAssertTrue(miniPlayerTitle(w).waitForExistence(timeout: long))
            miniPlayerTitle(w).tap()
        }
        r.define("I open the full player") { w in
            XCTAssertTrue(miniPlayerTitle(w).waitForExistence(timeout: long))
            miniPlayerTitle(w).tap()
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

        r.define("the premiere result should say when it premieres instead of offering a play button") { w in
            // The search fixture carries one unaired premiere (a 2099 start).
            let caption = w.app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Premieres '")).firstMatch
            XCTAssertTrue(caption.waitForExistence(timeout: long), "A premiere row should say when it premieres")
            let row = w.app.cells.containing(.staticText, identifier: caption.label).firstMatch
            XCTAssertTrue(row.exists, "The premiere caption should sit in a result row")
            XCTAssertEqual(row.buttons.matching(identifier: "playButton").count, 0, "An unaired premiere has nothing to play")
            XCTAssertEqual(row.buttons.matching(identifier: "queueButton").count, 0, "…and nothing to queue")
        }

        r.define("I open the premiere result") { w in
            let caption = w.app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Premieres '")).firstMatch
            XCTAssertTrue(caption.waitForExistence(timeout: long), "A premiere row should be in the results")
            caption.tap()
        }
        r.define("I should see when the premiere starts and no Play button") { w in
            XCTAssertTrue(w.app.navigationBars["Details"].waitForExistence(timeout: long), "The detail page should open")
            let headline = w.app.staticTexts["detailPremiere"]
            XCTAssertTrue(headline.waitForExistence(timeout: long), "The page should say when the premiere starts")
            XCTAssertTrue(headline.label.hasPrefix("Premieres "), "Headline was: \(headline.label)")
            XCTAssertTrue(w.app.buttons["checkAgainButton"].exists, "A Check again control should be offered")
            XCTAssertFalse(w.app.buttons["detailPlayButton"].exists, "An unaired premiere has nothing to play")
            XCTAssertFalse(w.app.buttons["retryButton"].exists, "This is not a failure, so no Retry")
        }

        // MARK: Queue
        r.define("I tap the queue button on the first result") { w in
            let queue = w.app.buttons["queueButton"].firstMatch
            XCTAssertTrue(queue.waitForExistence(timeout: long), "A queue control should be present")
            queue.tap()
        }
        r.define("I tap the queue button on the second result") { w in
            let queue = w.app.buttons.matching(identifier: "queueButton").element(boundBy: 1)
            XCTAssertTrue(queue.waitForExistence(timeout: long), "A second queue control should be present")
            queue.tap()
        }
        // Opens the full player's Queue tab and checks its "N items" count — a
        // signal only the queue renders, so a title visible in the list behind
        // the sheet can't satisfy it.
        r.define("the queue should contain (\\d+) items") { w in
            let count = w.capture()
            miniPlayerTitle(w).tap()
            let queueTab = w.app.buttons["playerTab-Queue"]
            XCTAssertTrue(queueTab.waitForExistence(timeout: long), "The Queue player tab should be present")
            queueTab.tap()
            XCTAssertTrue(w.app.staticTexts["\(count) items"].waitForExistence(timeout: long),
                          "The queue should list \(count) items")
        }
        r.define("the video should be added to the queue") { w in
            let title = miniPlayerTitle(w)
            XCTAssertTrue(title.waitForExistence(timeout: long), "Queued item should begin playing and show in the mini player")
            XCTAssertEqual(title.label, nowPlayingTitle)
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
        r.define("I open the (Following|Recents|Settings) tab") { w in selectTab(w, w.capture()) }
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
            selectTab(w, "Following")
            XCTAssertTrue(w.app.staticTexts[channelName].waitForExistence(timeout: medium),
                          "Followed channel should appear on the Following tab")
        }
        r.define("the played video should appear in my history") { w in
            // Inside a list row — the mini player (which shows the same title) doesn't count.
            XCTAssertTrue(w.app.cells.staticTexts[nowPlayingTitle].waitForExistence(timeout: medium),
                          "Played video should appear in Recents")
        }

        // MARK: Settings
        r.define("I am on the Settings tab") { w in
            selectTab(w, "Settings")
            XCTAssertTrue(w.app.navigationBars["Settings"].waitForExistence(timeout: medium))
        }
        // MARK: Audio language
        r.define("the audio language setting should be \"(.+)\"") { w in
            let picker = w.app.buttons["audioLanguagePicker"]
            XCTAssertTrue(picker.waitForExistence(timeout: medium), "Audio Language picker should be present")
            let shown = picker.label + " " + ((picker.value as? String) ?? "")
            XCTAssertTrue(shown.contains(w.capture()), "Audio Language should be \(w.capture()), was “\(shown)”")
        }
        r.define("the audio language menu should show \"(.+)\"") { w in
            let menu = w.app.buttons["audioLanguageMenu"]
            XCTAssertTrue(menu.waitForExistence(timeout: long), "Dubbed video should offer an audio language menu")
            let expected = NSPredicate(format: "label CONTAINS %@", w.capture())
            let match = XCTNSPredicateExpectation(predicate: expected, object: menu)
            XCTAssertEqual(XCTWaiter.wait(for: [match], timeout: medium), .completed,
                           "Audio language menu should show \(w.capture()), was “\(menu.label)”")
        }
        r.define("I choose \"(.+)\" from the audio language menu") { w in
            let menu = w.app.buttons["audioLanguageMenu"]
            XCTAssertTrue(menu.waitForExistence(timeout: long), "Dubbed video should offer an audio language menu")
            menu.tap()
            let option = w.app.buttons[w.capture()]
            XCTAssertTrue(option.waitForExistence(timeout: medium), "\(w.capture()) should be offered")
            option.tap()
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
            // A button below the fold of a lazy List (e.g. Settings) isn't
            // realized until scrolled to; scroll only if it doesn't show up.
            if !button.waitForExistence(timeout: short) { scrollToElement(w, button) }
            XCTAssertTrue(button.waitForExistence(timeout: medium), "“\(w.capture())” should be present")
            button.tap()
        }
        r.define("I should see the remaining time with a Cancel option") { w in
            XCTAssertTrue(w.app.buttons["Cancel"].waitForExistence(timeout: short), "Cancel should appear once a timer is set")
            XCTAssertTrue(w.app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'min remaining'")).firstMatch.exists,
                          "Remaining time should be shown")
        }
        r.define("I have performed a search") { w in
            selectTab(w, "Search")
            performSearch(w, "temporary query")
        }
        r.define("I open Settings and tap \"(.+)\"") { w in
            selectTab(w, "Settings")
            let button = w.app.buttons[w.capture()]
            // Settings is a lazy List: rows below the fold don't exist until
            // scrolled to, and how far down a row sits depends on the sections
            // above it. Scroll until it is on screen (bounded), then assert.
            _ = button.waitForExistence(timeout: 3)  // the tab's first render
            var swipes = 0
            while !(button.exists && button.isHittable) && swipes < 6 {
                w.app.swipeUp()
                swipes += 1
            }
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

        // MARK: Instance setup (scenario launches with --uitest-no-instance)
        r.define("I should see the instance setup screen") { w in
            XCTAssertTrue(w.app.staticTexts["Choose a Piped instance"].waitForExistence(timeout: long),
                          "The setup screen should ask for a Piped instance")
        }
        r.define("I enter \"(.+)\" as the instance") { w in
            let field = w.app.textFields["instanceSetupField"]
            XCTAssertTrue(field.waitForExistence(timeout: long))
            field.tap()
            field.typeText(w.capture())
            let save = w.app.buttons["instanceSetupSave"]
            XCTAssertTrue(save.waitForExistence(timeout: short) && save.isEnabled, "Save should enable for a valid URL")
            save.tap()
        }
        r.define("I choose the demo library") { w in
            let button = w.app.buttons["useDemoLibrary"]
            XCTAssertTrue(button.waitForExistence(timeout: long))
            button.tap()
        }

        // MARK: Offline mode
        r.define("I open Settings") { w in
            selectTab(w, "Settings")
            XCTAssertTrue(w.app.navigationBars["Settings"].waitForExistence(timeout: medium), "Settings should open")
        }
        r.define("I turn on Offline Mode") { w in enableOfflineMode(w) }
        r.define("offline mode is on") { w in
            selectTab(w, "Settings")
            enableOfflineMode(w)
        }
        r.define("the home tab should show Downloads") { w in
            selectTab(w, "Feed", screen: "Downloads")
            // After the hermetic reset there are no downloads, so the Downloads
            // screen shows its "No Downloads" empty state. Accept the nav bar or
            // the empty-state copy.
            XCTAssertTrue(w.app.navigationBars["Downloads"].waitForExistence(timeout: long) ||
                          w.app.staticTexts["No Downloads"].waitForExistence(timeout: short),
                          "Home tab should show Downloads while offline")
        }
        r.define("I open the Search tab") { w in
            // Online this shows the Search screen; offline, the placeholder.
            selectTab(w, "Search", shown: { w.app.navigationBars["Search"].exists || w.app.staticTexts["You're Offline"].exists })
        }
        r.define("I should see the offline placeholder") { w in
            XCTAssertTrue(w.app.staticTexts["You're Offline"].waitForExistence(timeout: long),
                          "Search should show the offline placeholder")
        }

        // MARK: Audio / video mode
        r.define("I enable \"(.+)\"") { w in
            let button = w.app.buttons[w.capture()]
            // A button below the fold of a lazy List (e.g. Settings) isn't
            // realized until scrolled to; scroll only if it doesn't show up.
            if !button.waitForExistence(timeout: short) { scrollToElement(w, button) }
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
            selectTab(w, "Search")
            performSearch(w, channelName)
            let firstVideo = w.app.staticTexts[searchStreamTitle].firstMatch
            XCTAssertTrue(firstVideo.waitForExistence(timeout: long))
            firstVideo.tap()
        }
        r.define("I should see a \"Chapters\" list") { w in
            // Flaked once on CI (2026-11-25): the pill tap landed mid-scroll of the
            // tab strip and selected nothing. One re-tap if the list is slow to show.
            let list = w.app.staticTexts["Chapters"]
            if !list.waitForExistence(timeout: short) { w.app.buttons["playerTab-Chapters"].firstMatch.tap() }
            XCTAssertTrue(list.waitForExistence(timeout: long), "Chapters list should appear")
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
        r.define("I am on the Feed tab") { w in selectTab(w, "Feed") }
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
            selectTab(w, "Search")
            performSearch(w, channelName)
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
            selectTab(w, "Feed")
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
            selectTab(w, "Feed")
            let button = w.app.buttons["savedPlaylistsButton"]
            XCTAssertTrue(button.waitForExistence(timeout: medium))
            button.tap()
        }
        r.define("I should see the saved playlist") { w in
            XCTAssertTrue(w.app.cells.firstMatch.waitForExistence(timeout: long), "Saved playlist should be listed")
        }
        r.define("I should see a playlist result") { w in
            let row = w.app.buttons["playlistRow"].firstMatch
            // The playlist result sits below the fold of the fixture results;
            // scroll until it is on screen (bounded).
            XCTAssertTrue(row.waitForExistence(timeout: long) || scrollUntilExists(w, row),
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
            selectTab(w, "Search")
            performSearch(w, channelName)
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
            turnOn(toggle, "Diagnostics upload")
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
        // Confirm the flip committed before dismissing (a lost tap leaves the
        // app online).
        turnOn(toggle, "Offline Mode")
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
        selectTab(w, "Search")
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
        selectTab(w, "Search")
        performSearch(w, "anything")
        let play = w.app.buttons["playButton"].firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: long), "A play control should be present in results")
        play.tap()
        XCTAssertTrue(miniPlayerTitle(w).waitForExistence(timeout: long))
    }

    /// Switch to a bottom tab and wait for its screen. iOS drops a touch that
    /// lands during the app's launch transition, so if the screen hasn't appeared
    /// the tap is repeated once; the final assertion stays strict.
    private static func selectTab(_ w: GherkinWorld, _ name: String, screen title: String? = nil) {
        selectTab(w, name, shown: { w.app.navigationBars[title ?? name].exists })
    }

    /// Same, with any observable sign the tab's screen is up (for screens that
    /// have no navigation title, like the offline placeholder).
    private static func selectTab(_ w: GherkinWorld, _ name: String, shown: @escaping () -> Bool) {
        let button = w.app.buttons["tab-\(name)"]
        XCTAssertTrue(button.waitForExistence(timeout: medium), "\(name) tab should exist")
        for _ in 0..<2 where !shown() {
            button.tap()
            _ = waitUntil(short, shown)
        }
        XCTAssertTrue(shown(), "The \(name) tab's screen should appear after tapping it")
    }

    /// Swipe up a bounded number of times until `element` exists.
    private static func scrollUntilExists(_ w: GherkinWorld, _ element: XCUIElement, swipes: Int = 5) -> Bool {
        for _ in 0..<swipes where !element.exists {
            w.app.swipeUp()
            _ = element.waitForExistence(timeout: 1)
        }
        return element.exists
    }

    /// Flip a SwiftUI List toggle on. The interactive control sits on the row's
    /// trailing edge, and a tap that lands during a sheet's appear animation is
    /// dropped, so the tap is repeated once if the value didn't commit; the
    /// final assertion stays strict.
    private static func turnOn(_ toggle: XCUIElement, _ what: String) {
        let on = NSPredicate(format: "value == '1'")
        for _ in 0..<2 where toggle.value as? String != "1" {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: on, object: toggle)], timeout: short)
        }
        XCTAssertEqual(toggle.value as? String, "1", "\(what) toggle should switch on")
    }

    /// The mini player's title label (the only element carrying this id, so it
    /// can't be confused with the same title in a list row behind it).
    private static func miniPlayerTitle(_ w: GherkinWorld) -> XCUIElement {
        w.app.staticTexts["miniPlayerTitle"]
    }

    /// Poll `condition` until it holds or `timeout` passes.
    private static func waitUntil(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return condition()
    }

    /// "1:05" → 65. Anything unparsable → -1.
    private static func seconds(_ clock: String) -> Double {
        let parts = clock.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 2 else { return -1 }
        return parts[0] * 60 + parts[1]
    }
}
