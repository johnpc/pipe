Feature: Chapters
  As a user
  I want to jump to sections of a long video
  So that I can skip to the part I care about

  Scenario: Opening a video with chapters shows a tappable chapter list
    Given I have searched and opened a video that has chapters
    Then I should see a "Chapters" list
    When I tap a chapter
    Then playback should jump to that chapter's start
