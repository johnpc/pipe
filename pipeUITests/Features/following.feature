Feature: Following Channels
  As a user
  I want to follow channels
  So that their videos appear in my feed

  Scenario: Empty following state
    Given I have not followed any channels
    When I open the Following tab
    Then I should see a "No Channels" empty state

  Scenario: Following a channel from search
    Given I have searched for "Huberman Lab"
    When I tap the follow heart on a channel result
    Then the channel should appear on the Following tab
