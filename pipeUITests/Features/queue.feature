Feature: Playback Queue
  As a user
  I want to add videos to a queue
  So that they play one after another

  Scenario: Queueing a result adds it to the queue
    Given I have searched for "Veritasium"
    When I tap the queue button on the first result
    Then the video should be added to the queue
    And the mini player bar should appear
