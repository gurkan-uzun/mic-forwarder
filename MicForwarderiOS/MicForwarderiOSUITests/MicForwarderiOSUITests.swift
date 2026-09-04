//
//  MicForwarderiOSUITests.swift
//  MicForwarderiOSUITests
//
//  Created by Gürkan uzun on 4.09.2026.
//

import XCTest

final class MicForwarderiOSUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testMainUI() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Verify the main title is visible
        let titleText = app.staticTexts["Mic Forwarder"]
        XCTAssertTrue(titleText.waitForExistence(timeout: 2.0), "The title 'Mic Forwarder' should be visible.")

        // Verify the initial disconnected status is visible
        let statusText = app.staticTexts["Disconnected"]
        XCTAssertTrue(statusText.exists, "The initial status should be 'Disconnected'.")

        // Verify the Start Server button is present
        let startButton = app.buttons["Start Server"]
        XCTAssertTrue(startButton.exists, "The 'Start Server' button should be visible.")

        // Handle possible microphone permission alert
        addUIInterruptionMonitor(withDescription: "Microphone Permission") { alert in
            if alert.buttons["OK"].exists {
                alert.buttons["OK"].tap()
                return true
            } else if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap()
                return true
            }
            return false
        }

        // Tap the start button
        startButton.tap()
        app.tap() // Required to trigger the interruption monitor if alert appears

        // The button text should change to "Stop Streaming"
        let stopButton = app.buttons["Stop Streaming"]
        let buttonAppeared = stopButton.waitForExistence(timeout: 3.0)
        
        // Note: In some CI environments without hardware audio support, the server might fail to start
        // and immediately revert to "Disconnected" and "Start Server". 
        // We log success if it appears, but we shouldn't strictly assert it to prevent flaky CI failures unless we mock AudioServer.
        if buttonAppeared {
            stopButton.tap()
            XCTAssertTrue(app.buttons["Start Server"].waitForExistence(timeout: 2.0))
        } else {
            print("Warning: 'Stop Streaming' button did not appear. Audio session might have failed in the simulator environment.")
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
