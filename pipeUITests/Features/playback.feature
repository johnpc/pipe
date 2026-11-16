Feature: Video Playback
  As a user
  I want to play a video from search results
  So that I can listen or watch it

  Scenario: Playing a result starts the mini player
    Given I have searched for "Lex Fridman"
    When I tap the play button on the first result
    Then the mini player bar should appear
    And the mini player should show "Guess What Age Punched You"

  Scenario: Expanding the mini player shows full controls
    Given a video is playing
    When I tap the mini player bar
    Then the full player sheet should appear with playback controls
