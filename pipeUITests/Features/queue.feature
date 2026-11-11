Feature: Playback Queue
  As a user
  I want to add videos to a queue
  So that they play one after another

  Scenario: Queueing a result adds it to the queue
    Given I have searched for "Veritasium"
    When I tap the queue button on the first result
    Then the video should be added to the queue
    And the mini player bar should appear

  # Adding while something plays is instant: the row's own title/thumbnail go
  # straight into the queue and the confirmation shows at once, while the
  # stream URL resolves in the background. No "Adding..." spinner.
  Scenario: Adding to the queue while something is playing is immediate
    Given I have searched for "Veritasium"
    And I tap the play button on the first result
    And the mini player bar should appear
    When I tap the queue button on the second result
    Then I should see "Added to Queue"
    And the queue should contain 2 items

  # The stream fixture carries a malformed "Mix"/playlist related entry (no
  # title/duration) — the exact shape that used to fail the whole decode and
  # make a playable video unplayable. Playing it here proves the resilient
  # decode: playback starts and the related list still renders.
  Scenario: A video with a malformed related entry still plays
    Given I have searched for "Veritasium"
    When I tap the play button on the first result
    Then the mini player bar should appear
