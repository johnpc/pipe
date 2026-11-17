@no-instance
Feature: Choosing a Piped instance
  As a new user
  I want the app to ask me which Piped instance to use
  So that pipe never talks to a server I didn't choose

  # pipe ships with no server. Until an instance is set, Feed and Search show
  # the setup screen; Recents and Following (local data) keep working.
  Scenario: A fresh install asks for an instance on the network tabs
    Given the app is launched
    Then I should see the instance setup screen
    When I tap the Search tab
    Then I should see the instance setup screen
    When I tap the Recents tab
    Then the Recents screen should appear

  Scenario: Entering an instance unlocks the Feed
    Given the app is launched
    When I enter "https://pipedapi.example.com" as the instance
    Then the Feed screen should appear

  Scenario: The demo library is one tap away
    Given the app is launched
    When I choose the demo library
    Then the Feed screen should appear
