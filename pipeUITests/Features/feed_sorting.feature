Feature: Feed Sorting and Filtering
  As a user
  I want to sort and filter my feed
  So that I can find content my way

  Scenario: Feed offers sort and hide-watched options
    Given I am on the Feed tab
    When I open the feed options menu
    Then I should see sort options and a "Hide Watched" toggle
