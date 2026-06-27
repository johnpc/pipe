Feature: Audio and Video Playback Mode
  As a user
  I want to switch between audio-only and video
  So that I can save data when I only need audio

  Scenario: Toggling video mode from the full player
    Given a video is playing
    And I have opened the full player
    When I tap "Show Video"
    Then the control should switch to "Audio Only"
