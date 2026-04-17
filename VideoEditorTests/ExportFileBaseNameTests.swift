//
// ExportFileBaseNameTests
// VideoEditorTests
//

import XCTest
@testable import VideoEditor

final class ExportFileBaseNameTests: XCTestCase {

    func testSanitizedFromWhitespaceOnlyReturnsExport() {
        XCTAssertEqual(ExportFileBaseName.sanitized(from: "   \n\t  "), "Export")
    }

    func testSanitizedReplacesInvalidPathCharactersWithHyphen() {
        XCTAssertEqual(ExportFileBaseName.sanitized(from: "a/b:c"), "a-b-c")
        XCTAssertEqual(ExportFileBaseName.sanitized(from: "x?y*z"), "x-y-z")
    }

    func testSanitizedWhenOnlyInvalidCharactersReturnsExport() {
        XCTAssertEqual(ExportFileBaseName.sanitized(from: "///"), "Export")
    }

    func testSanitizedTruncatesToEightyCharacters() {
        let long = String(repeating: "A", count: 120)
        XCTAssertEqual(ExportFileBaseName.sanitized(from: long).count, 80)
    }

    func testMovieExportConfigurationDefaultMatchesProjectFileType() {
        var settings = ExportSettings.default
        settings.fileType = .mp4
        let project = EditingProject(name: "P", tracks: [], exportSettings: settings)
        XCTAssertEqual(MovieExportConfiguration.default(matching: project).fileType, .mp4)
    }
}
