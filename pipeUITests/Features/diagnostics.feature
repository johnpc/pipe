Feature: Diagnostics log
  As a user hitting a playback issue
  I want to export a diagnostic playback log
  So that the problem can be root-caused without guesswork

  Scenario: Settings exposes a diagnostics section
    Given the app is launched
    When I open the Settings tab
    Then I should see the Diagnostics section

  Scenario: Diagnostics upload is off by default and can be turned on
    Given I am on the Settings tab
    Then diagnostics upload should be off
    When I turn on diagnostics upload
    Then diagnostics upload should be on
