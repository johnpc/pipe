@fake-server @dead-primary
Feature: Falling back to a second Piped instance
  As a listener whose Piped instance sometimes goes down
  I want pipe to carry on through a fallback instance I configured
  So that one dead server doesn't stop my listening

  # The primary instance is a loopback port nothing listens on (every request
  # is refused at once), and the fallback is the fake Piped backend. Nothing
  # here waits on a timeout: refusal is immediate, so the scenario is exact.
  Scenario: Search and playback work through the fallback when the primary is down
    Given I have searched for "anything"
    When I tap the play button on the first result
    Then the mini player bar should appear
    And the player should report "Playing"
    And the playback position should pass 0:02
