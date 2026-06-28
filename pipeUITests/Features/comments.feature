Feature: Comments
  As a user
  I want to read a video's comments
  So that I get context and reactions

  Scenario: Opening comments shows them
    Given I have searched and opened a video
    When I open the comments
    Then I should see at least one comment
