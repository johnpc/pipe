Feature: Watch History Management
  As a user
  I want to clear my watch history
  So that I can manage my privacy

  Scenario: Clearing watch history
    Given I have played a video
    When I open Settings and tap "Clear Watch History"
    Then the watch history should be empty
