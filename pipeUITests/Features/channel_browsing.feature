Feature: Channel Browsing
  As a user
  I want to open a channel from search results
  So that I can browse its videos

  Scenario: Opening a channel shows its videos
    Given I have searched for "MrBeast"
    When I tap a channel result
    Then I should land on the channel screen
    And I should see a "Videos" tab or a list of videos
