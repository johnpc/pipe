Feature: Search As You Type
  As a user
  I want results to appear as I type
  So that searching feels instant

  Scenario: Typing a query shows results without submitting
    Given I am on the Search tab
    When I type "MrBeast" into the search field
    Then I should see a list of search results
