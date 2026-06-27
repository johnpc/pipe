Feature: Sleep Timer End of Episode
  As a user
  I want playback to stop at the end of the current episode
  So that I can fall asleep without cutting off mid-video

  Scenario: Setting an end-of-episode sleep timer shows its state
    Given I am on the Settings tab
    When I tap "Sleep at end of episode"
    Then I should see "Stops after this episode"
