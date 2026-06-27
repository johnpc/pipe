# Acceptance Tests

These Gherkin specs describe the critical user flows that must pass before
release. They are implemented as XCUITests in `pipeUITests/AcceptanceTests.swift`,
where each `test…` method maps to one Scenario below (Given/When/Then in comments).

The app runs these in **mock mode** (`--uitest-mock`), serving bundled real
Piped fixtures captured from the live instance (`pipe/Fixtures/*.json`). Every
data-reading scenario therefore asserts on **real fixture data** deterministically
— no skips, no dependence on a live backend during CI.

## Feature: Tab Navigation

```gherkin
Feature: Tab Navigation
  As a user
  I want to move between the app's main tabs
  So that I can reach feed, search, recents, following, and settings

  Scenario: All tabs are reachable
    Given the app is launched
    Then I should see the Feed, Search, Recents, Following, and Settings tabs
    When I tap the Search tab
    Then the Search screen should appear
    When I tap the Recents tab
    Then the Recents screen should appear
    When I tap the Following tab
    Then the Following screen should appear
    When I tap the Settings tab
    Then the Settings screen should appear
```

## Feature: Search

```gherkin
Feature: Search Videos
  As a user
  I want to search for videos
  So that I can find content to watch

  Scenario: Empty state shows suggestions
    Given I am on the Search tab
    Then I should see popular channel suggestions
    And I should see an inline search field

  Scenario: Searching returns results
    Given I am on the Search tab
    When I type "MrBeast" into the search field
    And I submit the search
    Then I should see a list of search results

  Scenario: Tapping a suggestion runs a search
    Given I am on the Search tab
    When I tap the "MrBeast" suggestion
    Then I should see a list of search results
```

## Feature: Playback

```gherkin
Feature: Video Playback
  As a user
  I want to play a video from search results
  So that I can listen or watch it

  Scenario: Playing a result starts the mini player
    Given I have searched for "Lex Fridman"
    When I tap the play button on the first result
    Then the mini player bar should appear

  Scenario: Expanding the mini player shows full controls
    Given a video is playing
    When I tap the mini player bar
    Then the full player sheet should appear with playback controls
```

## Feature: Queue

```gherkin
Feature: Playback Queue
  As a user
  I want to add videos to a queue
  So that they play one after another

  Scenario: Queueing a result adds it to the queue
    Given I have searched for "Veritasium"
    When I tap the queue button on the first result
    Then the video should be added to the queue
    And the mini player bar should appear
```

## Feature: Channel Browsing

```gherkin
Feature: Channel Browsing
  As a user
  I want to open a channel from search results
  So that I can browse its videos

  Scenario: Opening a channel shows its videos
    Given I have searched for "MrBeast"
    When I tap a channel result
    Then I should land on the channel screen
    And I should see a "Videos" tab or a list of videos
```

## Feature: Following

```gherkin
Feature: Following Channels
  As a user
  I want to follow channels
  So that their videos appear in my feed

  Scenario: Empty following state
    Given I have not followed any channels
    When I open the Following tab
    Then I should see a "No Channels" empty state

  Scenario: Following a channel from search
    Given I have searched for "Huberman Lab"
    When I tap the follow heart on a channel result
    Then the channel should appear on the Following tab
```

## Feature: Recents

```gherkin
Feature: Recently Played
  As a user
  I want to see videos I have played
  So that I can resume or replay them

  Scenario: Empty recents state
    Given I have not played anything
    When I open the Recents tab
    Then I should see a "No History" empty state

  Scenario: Playing a video records it in Recents
    Given I have searched and played a video
    When I open the Recents tab
    Then the played video should appear in my history
```

## Feature: Settings

```gherkin
Feature: Settings
  As a user
  I want to configure the app
  So that I can choose my Piped instance and manage history

  Scenario: Settings screen shows its sections
    Given the app is launched
    When I open the Settings tab
    Then I should see the "Piped Instance" section
    And I should see the "Sleep Timer" section
    And I should see the "Search History" section

  Scenario: Setting a sleep timer shows the countdown
    Given I am on the Settings tab
    When I tap "Sleep after 30 min"
    Then I should see the remaining time with a Cancel option

  Scenario: Clearing search history empties it
    Given I have performed a search
    When I open Settings and tap "Clear History"
    Then the search history should be empty
```

## Feature: Search History

```gherkin
Feature: Search History
  As a user
  I want my recent searches remembered
  So that I can re-run them quickly

  Scenario: A performed search is remembered
    Given I am on the Search tab
    When I search for "lofi beats"
    And I open the Settings tab
    Then "lofi beats" should appear in the Search History section
```

## Feature: Audio / Video Mode

```gherkin
Feature: Audio and Video Playback Mode
  As a user
  I want to switch between audio-only and video
  So that I can save data when I only need audio

  Scenario: Toggling video mode from the full player
    Given a video is playing
    And I have opened the full player
    When I tap "Show Video"
    Then the control should switch to "Audio Only"
```

## Feature: Save for Later

```gherkin
Feature: Save for Later
  As a user
  I want to save videos to a list
  So that I can watch them later

  Scenario: Empty saved state
    Given I have saved nothing
    When I open the Saved screen from the Feed
    Then I should see a "Nothing Saved" empty state
```

## Feature: Watch History Management

```gherkin
Feature: Watch History Management
  As a user
  I want to clear my watch history
  So that I can manage my privacy

  Scenario: Clearing watch history
    Given I have played a video
    When I open Settings and tap "Clear Watch History"
    Then the watch history should be empty
```

## Feature: Feed Sorting and Filtering

```gherkin
Feature: Feed Sorting and Filtering
  As a user
  I want to sort and filter my feed
  So that I can find content my way

  Scenario: Feed offers sort and hide-watched options
    Given I am on the Feed tab
    When I open the feed options menu
    Then I should see sort options and a "Hide Watched" toggle
```

## Feature: Error Recovery

```gherkin
Feature: Error Recovery
  As a user
  I want a retry option when content fails to load
  So that a flaky connection doesn't dead-end me

  Scenario: Detail view offers retry on failure
    Given a video detail fails to load
    Then I should see a Retry button
```

## Feature: Picture in Picture

```gherkin
Feature: Picture in Picture
  As a user
  I want video to keep playing in a floating window when I leave the app
  So that I can multitask while watching

  Scenario: Video mode presents a PiP-capable player
    Given a video is playing
    And I have opened the full player
    When I enable "Show Video"
    Then the video surface should be shown (PiP-capable)

  # Note: PiP activation on backgrounding is an OS behavior that cannot be
  # driven in a simulator UI test; the PiP-eligibility decision is covered by
  # PiPLogicTests, and the PiP-capable surface is verified by the toggle below.
```
