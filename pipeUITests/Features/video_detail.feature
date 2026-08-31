Feature: Video Detail Page
  As a user
  I want to open a video's detail page from its title
  So that I can read the description and comments without playing it

  Scenario: Opening a video shows its details without starting playback
    Given I have searched and opened a video
    Then I should see the video detail page
    And playback should not have started

  Scenario: The detail page shows the description and comments
    Given I have searched and opened a video
    Then I should see the video description
    When I open the comments
    Then I should see at least one comment
