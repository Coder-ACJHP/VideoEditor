//
// VideoEditorUITests
// VideoEditorUITests
//  Created by Coder ACJHP on 27.03.2026.

//  Flow: Landing → Create project → Gallery → pick 3 photos → wait for project cell → open editor.
//
//  Prerequisites (Simulator):
//  1. Photo library must contain at least 3 images. Example:
//       xcrun simctl addmedia booted "/path/to/1.jpg" "/path/to/2.jpg" "/path/to/3.jpg"
//  2. Grant Photos access when prompted (test handles common “Allow full access” alerts),
//     or pre-authorize the app in Settings.
//

import XCTest

final class VideoEditorUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = [
            "-uitesting-reset-state",
            "-uitesting-picker-limit-3",
        ]

        addUIInterruptionMonitor(withDescription: "Photo library permission") { alert in
            let labels = [
                "Allow Access to All Photos",
                "Allow Full Access",
                "Select More Photos…",
                "Allow",
                "OK",
            ]
            for title in labels {
                let button = alert.buttons[title]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testCreateProjectWithThreePhotosFromGalleryAndOpenEditor() throws {
        app.launch()

        let createButton = app.buttons["landing.createProject"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 10))
        createButton.tap()

        let gallery = app.sheets.buttons["Gallery"]
        if gallery.waitForExistence(timeout: 5) {
            gallery.tap()
        } else {
            let looseGallery = app.buttons["Gallery"]
            XCTAssertTrue(looseGallery.waitForExistence(timeout: 3))
            looseGallery.tap()
        }

        // Permission or picker may appear first; resolve alerts then find a grid with ≥3 cells.
        guard let grid = waitForPickerGridWithAtLeastCells(3, timeout: 25) else {
            throw XCTSkip(
                "No photo grid with 3+ items. Add images to the booted simulator, e.g. " +
                "xcrun simctl addmedia booted ~/Pictures/a.jpg ~/Pictures/b.jpg ~/Pictures/c.jpg"
            )
        }

        for index in 0..<3 {
            let cell = grid.cells.element(boundBy: index)
            XCTAssertTrue(cell.waitForExistence(timeout: 5), "Picker cell \(index) missing")
            cell.tap()
        }

        tapPickerConfirmationButton()

        let projectList = app.collectionViews["landing.projectList"]
        XCTAssertTrue(projectList.waitForExistence(timeout: 60), "Project list did not appear after import")

        let firstProjectCell = projectList.cells.firstMatch
        XCTAssertTrue(firstProjectCell.waitForExistence(timeout: 5), "No project cell after import")
        firstProjectCell.coordinate(withNormalizedOffset: CGVector(dx: 0.38, dy: 0.28)).tap()

        let editorRoot = app.otherElements["editor.root"]
        XCTAssertTrue(editorRoot.waitForExistence(timeout: 15), "Editor screen did not appear")

        XCTAssertTrue(app.buttons["Close editor"].waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    /// Polls for a collection view that looks like the picker grid (several image cells).
    private func waitForPickerGridWithAtLeastCells(_ minCount: Int, timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            dismissPhotoPermissionAlertIfPresent()

            let grids = app.collectionViews
            let n = min(grids.count, 12)
            for i in 0..<n {
                let cv = grids.element(boundBy: i)
                guard cv.exists else { continue }
                if cv.cells.count >= minCount {
                    return cv
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return nil
    }

    private func dismissPhotoPermissionAlertIfPresent() {
        let alert = app.alerts.firstMatch
        guard alert.waitForExistence(timeout: 0.5) else { return }
        let labels = [
            "Allow Access to All Photos",
            "Allow Full Access",
            "Select More Photos…",
            "Allow",
            "OK",
        ]
        for title in labels {
            let button = alert.buttons[title]
            if button.exists {
                button.tap()
                return
            }
        }
    }

    private func tapPickerConfirmationButton() {
        let addPred = NSPredicate(format: "label CONTAINS[c] %@", "Add")
        let candidates: [XCUIElement] = [
            app.buttons["Add"],
            app.navigationBars.buttons["Add"],
            app.toolbars.buttons["Add"],
            app.buttons.matching(addPred).firstMatch,
        ]
        for button in candidates {
            if button.waitForExistence(timeout: 2), button.isHittable {
                button.tap()
                return
            }
        }
        let done = app.buttons["Done"]
        if done.waitForExistence(timeout: 2), done.isHittable {
            done.tap()
            return
        }
        XCTFail("Could not find PHPicker Add/Done button")
    }
}
