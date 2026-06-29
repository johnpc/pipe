Feature: Full Player Tabs
  As a listener
  I want comments, related videos, and details while a video plays
  So that playback isn't a dead end

  Scenario: Up Next is reachable from the full player
    Given a video is playing
    And I open the full player
    When I open the "Up Next" player tab
    Then I should see a related video

  Scenario: Comments are reachable from the full player
    Given a video is playing
    And I open the full player
    When I open the "Comments" player tab
    Then I should see a comment in the player
