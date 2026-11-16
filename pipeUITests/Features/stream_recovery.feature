Feature: Recovery from a stream that fails to load
  As a user
  I want a stream that never loads to be retried and then reported
  So that playback never sits silently frozen at 0s

  # The bundled fixture's stream URL is an expired googlevideo URL, so AVPlayer
  # genuinely fails to load it — the same condition a dead-on-arrival URL causes
  # in production. The app re-resolves a bounded number of times and then tells
  # the user, instead of leaving the mini player stuck at 0s forever. The
  # lifecycle ends in the explicit Failed phase, which the mini player shows
  # until the user taps play to try again.
  Scenario: A stream that never loads reports itself instead of freezing
    Given I have searched for "MrBeast"
    When I tap the play button on the first result
    Then the mini player bar should appear
    And I should see text containing "Couldn't play Guess What Age Punched You —"
    And the player should report "Failed"
    And the mini player status should say "Couldn't play. Tap play to retry."
