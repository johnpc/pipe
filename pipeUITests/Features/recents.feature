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
