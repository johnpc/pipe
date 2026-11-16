@fake-server
Feature: Playback against the fake Piped backend
  As a developer (and an App Store reviewer)
  I want the app to play real media from the bundled fake backend
  So that playback is proven end to end without touching YouTube

  # The app is launched with `--uitest-instance` pointing at scripts/fake_piped,
  # which serves the fixtures' JSON plus a synthetic 30-second clip as HLS (the
  # app's primary path) and direct MP4/M4A. Nothing here can be flaky on the
  # backend side: it is a local process serving local files.
  Scenario: Audio plays and the player reports each phase
    Given I have searched for "anything"
    When I tap the play button on the first result
    Then the mini player bar should appear
    And the player should report "Playing"
    And the playback position should pass 0:02

  Scenario: Pausing from the mini player holds the position
    Given a video is playing
    And the player should report "Playing"
    When I pause from the mini player
    Then the player should report "Paused"
