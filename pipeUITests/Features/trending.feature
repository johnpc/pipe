Feature: Trending
  As a user
  I want to explore trending videos
  So that I can discover content without following anyone

  Scenario: Opening Trending shows videos
    Given I am on the Feed tab
    When I open Trending
    Then I should see a list of trending videos
