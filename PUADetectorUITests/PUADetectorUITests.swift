import XCTest

final class PUADetectorUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testMainScreenAndSettingsCoreEntriesAreReachable() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-UITestSkipSplash")
        app.launchArguments.append("-UITestResetDefaults")
        app.launchArguments.append(contentsOf: [
            "-UITestManualText",
            "i'll kill myself look what you made me do"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["PUA DETECTOR"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["開始偵測"].exists)
        XCTAssertTrue(app.buttons["緊急停止"].exists)

        tapWhenReady(app.buttons["settingsButton"], app: app)

        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["偵測"].exists)
        XCTAssertTrue(app.staticTexts["分類"].exists)

        swipeUntilVisible(app.staticTexts["提醒"], app: app)
        XCTAssertTrue(app.staticTexts["提醒"].exists)

        swipeUntilVisible(app.staticTexts["設定備份"], app: app)
        XCTAssertTrue(app.buttons["exportSettingsButton"].exists)
        XCTAssertTrue(app.buttons["importSettingsButton"].exists)

        swipeUntilVisible(app.staticTexts["安全"], app: app)
        XCTAssertTrue(app.buttons["restorePrivacyDefaultsButton"].exists)
        XCTAssertTrue(app.buttons["safetyResourcesButton"].exists)

        app.buttons["settingsDoneButton"].tap()
        XCTAssertTrue(app.staticTexts["PUA DETECTOR"].waitForExistence(timeout: 3))
    }

    func testManualTextEvaluationUpdatesMainRiskSignals() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-UITestSkipSplash")
        app.launchArguments.append("-UITestResetDefaults")
        app.launchArguments.append(contentsOf: [
            "-UITestManualText",
            "i'll kill myself look what you made me do"
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["PUA DETECTOR"].waitForExistence(timeout: 5))
        tapWhenReady(app.buttons["settingsButton"], app: app)

        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 3))
        swipeUntilVisible(app.staticTexts["文字測試"], app: app)

        XCTAssertTrue(app.textFields["manualTextEditor"].waitForExistence(timeout: 3))

        tapWhenReady(app.buttons["manualTestButton"], app: app)

        tapWhenReady(app.buttons["settingsDoneButton"], app: app)

        let riskState = app.staticTexts["riskSummaryText"]
        XCTAssertTrue(riskState.waitForExistence(timeout: 3))
        XCTAssertTrue(riskState.valueText.contains("高風險"))
        XCTAssertTrue(riskState.valueText.contains("威脅"))
        XCTAssertTrue(riskState.valueText.contains("threat"))
        XCTAssertTrue(app.staticTexts["categoryChip_threat"].exists)
    }

    private func swipeUntilVisible(_ element: XCUIElement, app: XCUIApplication, maxSwipes: Int = 6) {
        for _ in 0..<maxSwipes where !element.exists {
            app.swipeUp()
        }
    }

    private func tapWhenReady(_ element: XCUIElement, app: XCUIApplication, timeout: TimeInterval = 5) {
        app.activate()
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        let predicate = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed)
        element.tap()
    }
}

private extension XCUIElement {
    var valueText: String {
        (value as? String) ?? ""
    }
}
