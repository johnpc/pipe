Feature: Play Next
  As a user
  I want to play a video right after the current one
  So that I can control the queue order

  Scenario: Play Next is offered in a result's context menu
    Given I have searched for "MrBeast"
    When I long-press the first result
    Then I should see a "Play Next" option
