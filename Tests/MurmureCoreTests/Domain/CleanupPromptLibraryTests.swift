import XCTest
@testable import MurmureCore

final class CleanupPromptLibraryTests: XCTestCase {
    func testSavingTrimsNameAndRejectsDuplicateNamesIgnoringWhitespaceAndCase() {
        let existing = CleanupPrompt(name: "Standard", systemImageName: "wand.and.stars", instructions: "Useful")
        let candidate = CleanupPrompt(name: " standard ", systemImageName: "sparkles", instructions: "Other")

        XCTAssertEqual(
            CleanupPromptLibrary.validatedSaving(candidate, into: [existing]),
            .failure(.duplicateName)
        )
    }

    func testSavingRejectsEmptyValuesAndUnsupportedIcons() {
        XCTAssertEqual(
            CleanupPromptLibrary.validatedSaving(.init(name: " ", systemImageName: "sparkles", instructions: "Text"), into: []),
            .failure(.emptyName)
        )
        XCTAssertEqual(
            CleanupPromptLibrary.validatedSaving(.init(name: "Name", systemImageName: "sparkles", instructions: " "), into: []),
            .failure(.emptyInstructions)
        )
        XCTAssertEqual(
            CleanupPromptLibrary.validatedSaving(.init(name: "Name", systemImageName: "invalid", instructions: "Text"), into: []),
            .failure(.invalidIcon)
        )
    }
}
