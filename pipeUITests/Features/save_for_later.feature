Feature: Save for Later
  As a user
  I want to save videos to a list
  So that I can watch them later

  Scenario: Empty saved state
    Given I have saved nothing
    When I open the Saved screen from the Feed
    Then I should see a "Nothing Saved" empty state
