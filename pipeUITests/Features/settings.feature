Feature: Settings
  As a user
  I want to configure the app
  So that I can choose my Piped instance and manage history

  Scenario: Settings screen shows its sections
    Given the app is launched
    When I open the Settings tab
    Then I should see the "Piped Instance" section
    And I should see the "Sleep Timer" section
    And I should see the "Search History" section

  Scenario: Setting a sleep timer shows the countdown
    Given I am on the Settings tab
    When I tap "Sleep after 30 min"
    Then I should see the remaining time with a Cancel option

  Scenario: Clearing search history empties it
    Given I have performed a search
    When I open Settings and tap "Clear History"
    Then the search history should be empty
