Feature: Stream error messages
  As a user
  I want a failed add/play to tell me why it failed
  So that a Piped-instance error isn't hidden behind a generic message

  @error-streams
  Scenario: A Piped instance error surfaces its real message
    Given I have searched for "Veritasium"
    When I tap the queue button on the first result
    Then I should see "Couldn't add — JSON response is too short"

  @down-instance
  Scenario: A dead Piped instance names the HTTP error
    Given I have searched for "Veritasium"
    When I tap the queue button on the first result
    Then I should see "Couldn't add — the Piped instance returned an error (502)"
