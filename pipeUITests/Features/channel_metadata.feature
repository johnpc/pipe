Feature: Channel Metadata
  As a user
  I want to see how big and trustworthy a channel is
  So that I can judge search results at a glance

  Scenario: Channel results show subscriber count and verified badge
    Given I have searched for "MrBeast"
    Then the channel result should show a subscriber count
