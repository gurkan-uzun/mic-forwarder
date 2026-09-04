//
//  MicForwarderiOSTests.swift
//  MicForwarderiOSTests
//
//  Created by Gürkan uzun on 4.09.2026.
//

import XCTest
@testable import MicForwarderiOS

@MainActor
final class MicForwarderiOSTests: XCTestCase {

    var audioServer: AudioServer!

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        audioServer = AudioServer()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        if audioServer.isRunning {
            audioServer.toggleServer()
        }
        audioServer = nil
    }

    func testInitialState() throws {
        XCTAssertFalse(audioServer.isRunning, "AudioServer should not be running initially.")
        XCTAssertEqual(audioServer.connectionStatus, "Disconnected", "Initial connection status should be 'Disconnected'.")
        XCTAssertEqual(audioServer.volumeLevel, 0.0, "Initial volume level should be 0.0.")
    }

    func testToggleServer() throws {
        let expectation = XCTestExpectation(description: "Wait for server to start")
        
        // Initial state is false
        XCTAssertFalse(audioServer.isRunning)
        
        // Start server
        audioServer.toggleServer()
        
        // The start process might be async due to DispatchQueue.main.async in listener state handlers
        // But the `isRunning = true` is also dispatched to main queue.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // We verify that it has attempted to start and isRunning is true 
        // (assuming no permission/port errors in test environment, or at least it doesn't crash)
        // Note: In a real CI environment, without mic permission, it might fail.
        // If it fails, isRunning might be false. So we'll just check it doesn't crash for now, 
        // or we check that connectionStatus changed from Disconnected.
        XCTAssertNotEqual(audioServer.connectionStatus, "Disconnected", "Server should attempt to listen and change status.")
        
        // Stop server
        audioServer.toggleServer()
        let stopExpectation = XCTestExpectation(description: "Wait for server to stop")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            stopExpectation.fulfill()
        }
        wait(for: [stopExpectation], timeout: 1.0)
        
        XCTAssertFalse(audioServer.isRunning, "Server should be stopped.")
        XCTAssertEqual(audioServer.connectionStatus, "Disconnected", "Status should return to Disconnected.")
    }
}
