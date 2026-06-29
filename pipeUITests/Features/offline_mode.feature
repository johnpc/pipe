Feature: Offline Mode
  As a listener with no connection
  I want the app to focus on my downloads
  So that I can keep listening without the network

  Scenario: Enabling offline mode opens Downloads
    Given I open Settings
    When I turn on Offline Mode
    Then the home tab should show Downloads

  Scenario: Search shows an offline state when offline mode is on
    Given offline mode is on
    When I open the Search tab
    Then I should see the offline placeholder

  Scenario: Following still works offline
    Given offline mode is on
    When I open the Following tab
    Then I should see a "No Channels" empty state
