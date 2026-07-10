Feature: Cast to TV
  As a listener with a Chromecast-enabled TV
  I want to send a video from my phone to the TV
  So that I can watch on a bigger screen while my phone acts as the remote

  Scenario: The full player offers a Cast control
    Given a video is playing
    And I open the full player
    Then I should see the Cast control

  Scenario: A search result offers a Cast action
    Given I have searched and played a video
    When I open the context menu for the first result
    Then I should see a "Cast to TV" action
