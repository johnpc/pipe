Feature: Tab Navigation
  As a user
  I want to move between the app's main tabs
  So that I can reach feed, search, recents, following, and settings

  Scenario: All tabs are reachable
    Given the app is launched
    Then I should see the Feed, Search, Recents, Following, and Settings tabs
    When I tap the Search tab
    Then the Search screen should appear
    When I tap the Recents tab
    Then the Recents screen should appear
    When I tap the Following tab
    Then the Following screen should appear
    When I tap the Settings tab
    Then the Settings screen should appear
