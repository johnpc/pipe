Feature: Audio language
  As a listener
  I want dubbed videos to play in my language
  So that I hear English by default and can switch to another track when I want

  Scenario: Audio language defaults to English
    Given I am on the Settings tab
    Then the audio language setting should be "English"

  Scenario: A dubbed video starts in English
    Given a video is playing
    And I open the full player
    Then the audio language menu should show "English"

  Scenario: Switching a dubbed video to another language
    Given a video is playing
    And I open the full player
    When I choose "Spanish" from the audio language menu
    Then the audio language menu should show "Spanish"
