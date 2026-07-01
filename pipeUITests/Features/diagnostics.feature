Feature: Diagnostics log
  As a user hitting a playback issue
  I want to export a diagnostic playback log
  So that the problem can be root-caused without guesswork

  Scenario: Settings exposes a diagnostics section
    Given the app is launched
    When I open the Settings tab
    Then I should see the "Diagnostics" section

  Scenario: The playback log can be shared
    Given I am on the Settings tab
    When I tap "Share Playback Log"
    Then I should see the share sheet
