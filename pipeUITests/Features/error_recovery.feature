@fail-streams
Feature: Error Recovery
  As a user
  I want a retry option when content fails to load
  So that a flaky connection doesn't dead-end me

  Scenario: Detail view offers retry on failure
    Given a video detail fails to load
    Then I should see a Retry button
