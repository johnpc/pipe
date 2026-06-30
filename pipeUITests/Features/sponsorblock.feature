Feature: SponsorBlock
  As a listener
  I want sponsor segments skipped automatically
  So that I don't have to fast-forward past ads myself

  Scenario: SponsorBlock is on by default and can be turned off
    Given a video is playing
    And I have opened the full player
    Then SponsorBlock should be on
    When I tap the SponsorBlock toggle
    Then SponsorBlock should be off
