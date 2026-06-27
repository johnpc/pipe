Feature: Chapters
  As a user
  I want to jump to sections of a long video
  So that I can skip to the part I care about

  Scenario: Opening a video with chapters shows a tappable chapter list
    Given I have searched and opened a video that has chapters
    Then I should see a "Chapters" list
    When I tap a chapter
    Then playback should jump to that chapter's start

  Scenario: The full player shows the current chapter
    Given I have searched and opened a video that has chapters
    When I tap a chapter
    And I open the full player
    Then I should see the current chapter label
