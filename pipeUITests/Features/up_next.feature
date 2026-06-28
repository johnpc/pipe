Feature: Up Next
  As a user
  I want to see related videos under what I'm watching
  So that I have somewhere to go when it ends

  Scenario: A video's detail shows related videos
    Given I have searched and opened a video
    Then I should see an "Up Next" list
