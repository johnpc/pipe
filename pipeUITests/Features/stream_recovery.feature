Feature: Recovery from a stream that fails to load
  As a user
  I want a stream that never loads to be retried and then reported
  So that playback never sits silently frozen at 0s

  # The bundled fixture's stream URL is an expired googlevideo URL, so AVPlayer
  # genuinely fails to load it — the same condition a dead-on-arrival URL causes
  # in production. The app re-resolves a bounded number of times and then tells
  # the user, instead of leaving the mini player stuck at 0s forever.
  Scenario: A stream that never loads reports itself instead of freezing
    Given I have searched for "MrBeast"
    When I tap the play button on the first result
    Then the mini player bar should appear
    And I should see "Couldn't play Survive 30 Days Chained To A Stranger, Win $250,000 — the stream expired"
