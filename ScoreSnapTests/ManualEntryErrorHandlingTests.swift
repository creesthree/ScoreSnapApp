//
//  Phase5ErrorHandlingTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import XCTest
import SwiftUI
import CoreData
@testable import ScoreSnap

class Phase5ErrorHandlingTests: XCTestCase {
    
    var testContext: NSManagedObjectContext!
    var viewModel: UploadViewModel!
    
    @MainActor
    override func setUp() {
        super.setUp()
        
        let container = NSPersistentContainer(name: "ScoreSnap")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load test store: \(error)")
            }
        }
        
        testContext = container.viewContext
        viewModel = UploadViewModel(viewContext: testContext)
    }
    
    override func tearDown() {
        viewModel = nil
        testContext = nil
        super.tearDown()
    }
    
    // MARK: - User Input Errors Tests
    
    @MainActor
    func testInvalidScoreInputHandling() {
        // Test invalid score input handling
        viewModel.teamScore = -5
        XCTAssertFalse(viewModel.validateScore(viewModel.teamScore))
        
        viewModel.teamScore = 250
        XCTAssertFalse(viewModel.validateScore(viewModel.teamScore))
        
        viewModel.teamScore = 85
        XCTAssertTrue(viewModel.validateScore(viewModel.teamScore))
    }
    
    @MainActor
    func testEmptyRequiredFieldHandling() {
        // Test empty required field handling
        let team = createTestTeam()
        
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = ""
        viewModel.isOpponentNameValid = false
        
        let success = viewModel.createGame(for: team)
        XCTAssertFalse(success)
        XCTAssertEqual(viewModel.errorMessage, "Please fix validation errors")
    }
    
    @MainActor
    func testFormStateCorruptionRecovery() {
        // Test form state corruption recovery
        let team = createTestTeam()
        
        viewModel.gameResult = .win
        viewModel.teamScore = 70
        viewModel.opponentScore = 80
        
        viewModel.assignSmartScores()
        XCTAssertTrue(viewModel.teamScore > viewModel.opponentScore)
        
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        let success = viewModel.createGame(for: team)
        XCTAssertTrue(success)
    }
    
    // MARK: - System Errors Tests
    
    @MainActor
    func testCoreDataSaveFailures() {
        // Test Core Data save failures
        let team = createTestTeam()
        
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        testContext.delete(team)
        try! testContext.save()
        
        let success = viewModel.createGame(for: team)
        XCTAssertFalse(success)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    @MainActor
    func testConcurrentAccessConflicts() {
        // Test concurrent access conflicts
        let team = createTestTeam()
        
        let expectation = XCTestExpectation(description: "Concurrent saves")
        expectation.expectedFulfillmentCount = 5
        
        for i in 0..<5 {
            DispatchQueue.main.async {
                let viewModel = UploadViewModel(viewContext: self.testContext)
                viewModel.gameResult = .win
                viewModel.teamScore = 85 + i
                viewModel.opponentScore = 78 + i
                viewModel.opponentName = "Team \(i)"
                viewModel.isOpponentNameValid = true
                
                let success = viewModel.createGame(for: team)
                XCTAssertTrue(success)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let games = try! testContext.fetch(fetchRequest)
        XCTAssertEqual(games.count, 5)
    }
    
    // MARK: - Recovery Mechanisms Tests
    
    @MainActor
    func testErrorMessageClarity() {
        // Test error message clarity
        let team = createTestTeam()
        
        let success1 = viewModel.createGame(for: nil)
        XCTAssertFalse(success1)
        XCTAssertEqual(viewModel.errorMessage, "No team selected")
        
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = ""
        viewModel.isOpponentNameValid = false
        
        let success2 = viewModel.createGame(for: team)
        XCTAssertFalse(success2)
        XCTAssertEqual(viewModel.errorMessage, "Please fix validation errors")
    }
    
    @MainActor
    func testErrorRecoveryWorkflows() {
        // Test error recovery workflows
        let team = createTestTeam()
        
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = ""
        viewModel.isOpponentNameValid = false
        
        let success1 = viewModel.createGame(for: team)
        XCTAssertFalse(success1)
        
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        let success2 = viewModel.createGame(for: team)
        XCTAssertTrue(success2)
    }
    
    @MainActor
    func testDataPreservationOnErrors() {
        // Test data preservation on errors
        let team = createTestTeam()
        
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.gameLocation = "Home Court"
        viewModel.gameNotes = "Great game!"
        viewModel.isOpponentNameValid = true
        
        testContext.delete(team)
        try! testContext.save()
        
        let success = viewModel.createGame(for: team)
        XCTAssertFalse(success)
        
        XCTAssertEqual(viewModel.gameResult, .win)
        XCTAssertEqual(viewModel.teamScore, 85)
        XCTAssertEqual(viewModel.opponentScore, 78)
        XCTAssertEqual(viewModel.opponentName, "Lakers")
        XCTAssertEqual(viewModel.gameLocation, "Home Court")
        XCTAssertEqual(viewModel.gameNotes, "Great game!")
        XCTAssertTrue(viewModel.isOpponentNameValid)
    }
    
    // MARK: - Helper Methods
    
    private func createTestTeam() -> Team {
        let team = Team(context: testContext)
        team.id = UUID()
        team.name = "Test Team"
        team.teamColor = "red"
        team.displayOrder = 0
        team.sport = "Basketball"
        return team
    }
} 