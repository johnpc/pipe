Feature: Picture in Picture
  As a user
  I want video to keep playing in a floating window when I leave the app
  So that I can multitask while watching

  # Note: PiP activation on backgrounding is an OS behavior that cannot be
  # driven in a simulator UI test; the PiP-eligibility decision is covered by
  # PiPLogicTests, and the PiP-capable surface is verified by the toggle below.
  Scenario: Video mode presents a PiP-capable player
    Given a video is playing
    And I have opened the full player
    When I enable "Show Video"
    Then the video surface should be shown (PiP-capable)

  # Regression: pausing the PiP-capable player must actually pause and stay
  # paused (the PiP pause button drove AVPlayer directly while our stall-recovery
  # nudged it straight back on). Driven here via the full player's pause control
  # in video mode, which shares the same timeControlStatus-sync path.
  Scenario: Pausing the video-mode player pauses playback
    Given a video is playing
    And I have opened the full player
    When I enable "Show Video"
    And I tap pause
    Then playback should be paused
