Feature: Offline Downloads
  As a user
  I want to download videos for offline playback
  So that I can listen without a connection

  Scenario: Empty downloads state
    Given I have downloaded nothing
    When I open the Downloads screen from the Feed
    Then I should see a "No Downloads" empty state

  Scenario: Downloading a video adds it to Downloads
    Given I have searched and opened a video
    When I tap the download button
    And I open the Downloads screen from the Feed
    Then I should see the downloaded video

  Scenario: Downloading from a search result's context menu
    Given I have searched for "MrBeast"
    When I download the first result from its context menu
    And I open the Downloads screen from the Feed
    Then I should see the downloaded video
