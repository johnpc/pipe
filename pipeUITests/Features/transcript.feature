Feature: Transcript
  As a listener
  I want a transcript of what I'm watching, with an option to summarize it
  So that I can read along, jump to a moment, or get the gist quickly

  Scenario: Transcript tab is reachable from the full player
    Given a video is playing
    And I open the full player
    When I open the "Transcript" player tab
    Then I should see the transcript or an empty state
