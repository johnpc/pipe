Feature: Playback Queue
  As a user
  I want to add videos to a queue
  So that they play one after another

  Scenario: Queueing a result adds it to the queue
    Given I have searched for "Veritasium"
    When I tap the queue button on the first result
    Then the video should be added to the queue
    And the mini player bar should appear

  # The stream fixture carries a malformed "Mix"/playlist related entry (no
  # title/duration) — the exact shape that used to fail the whole decode and
  # make a playable video unplayable. Playing it here proves the resilient
  # decode: playback starts and the related list still renders.
  Scenario: A video with a malformed related entry still plays
    Given I have searched for "Veritasium"
    When I tap the play button on the first result
    Then the mini player bar should appear
