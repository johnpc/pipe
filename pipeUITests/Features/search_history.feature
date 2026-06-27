Feature: Search History
  As a user
  I want my recent searches remembered
  So that I can re-run them quickly

  Scenario: A performed search is remembered
    Given I am on the Search tab
    When I search for "lofi beats"
    And I open the Settings tab
    Then "lofi beats" should appear in the Search History section
