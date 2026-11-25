Feature: Search Videos
  As a user
  I want to search for videos
  So that I can find content to watch

  Scenario: Empty state suggests channels trending on the instance
    Given I am on the Search tab
    Then I should see trending channel suggestions
    And I should see an inline search field

  Scenario: Searching returns results
    Given I am on the Search tab
    When I type "MrBeast" into the search field
    And I submit the search
    Then I should see a list of search results

  Scenario: Tapping a suggestion runs a search
    Given I am on the Search tab
    When I tap the "Scump" suggestion
    Then I should see a list of search results

  Scenario: A premiere that has not aired yet offers nothing to play
    Given I have searched for "MrBeast"
    Then the premiere result should say when it premieres instead of offering a play button
