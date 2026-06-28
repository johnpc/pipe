Feature: Playlists
  As a listener
  I want to browse and play playlists
  So that I can queue a whole set of videos at once

  Scenario: A channel's Playlists tab lists its playlists
    Given I have opened a channel with playlists
    When I select the "Playlists" tab
    Then I should see a list of playlists

  Scenario: Opening a playlist shows its videos
    Given I have opened a channel with playlists
    When I select the "Playlists" tab
    And I tap the first playlist
    Then I should see the playlist's videos

  Scenario: Play All queues the playlist
    Given I have opened a playlist
    When I tap "Play All"
    Then the mini player bar should appear

  Scenario: Saving a playlist keeps it in Saved Playlists
    Given I have opened a playlist
    When I tap "Save Playlist"
    And I open Saved Playlists from the Feed
    Then I should see the saved playlist

  Scenario: Playlist results appear in search
    Given I have searched for "MrBeast"
    Then I should see a playlist result
    When I tap the first playlist result
    Then I should see the playlist's videos
