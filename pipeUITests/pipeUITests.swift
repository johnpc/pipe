import XCTest

final class pipeUITests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }
    
    func testSearchFlow() throws {
        // Tap Search tab
        app.buttons["Search"].tap()
        
        // Verify search field exists
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field should exist")
        
        // Tap search field and type
        searchField.tap()
        searchField.typeText("MrBeast")
        
        // Submit search
        app.keyboards.buttons["Search"].tap()
        
        // Wait for results
        let cell = app.cells.firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 10), "Search results should appear")
    }
    
    func testSuggestionTap() throws {
        // Tap Search tab
        app.buttons["Search"].tap()
        
        // Tap a suggestion button
        let suggestion = app.buttons["MrBeast"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5), "Suggestion should exist")
        suggestion.tap()
        
        // Wait for results
        let cell = app.cells.firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 10), "Search results should appear after tapping suggestion")
    }
}
