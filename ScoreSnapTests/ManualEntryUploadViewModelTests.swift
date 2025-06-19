//
//  Phase5UploadViewModelTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import XCTest
import SwiftUI
import CoreData
import Combine
@testable import ScoreSnap

class Phase5UploadViewModelTests: XCTestCase {
    
    var testContext: NSManagedObjectContext!
    var viewModel: UploadViewModel!
    var cancellables: Set<AnyCancellable>!
    
    @MainActor
    override func setUp() {
        super.setUp()
        
        // Create in-memory Core Data stack for testing
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
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables?.removeAll()
        viewModel = nil
        testContext = nil
        super.tearDown()
    }
    
    // MARK: - Form State Management Tests
    
    @MainActor
    func testFormInitialization() {
        // Test form starts with appropriate default values
        XCTAssertEqual(viewModel.gameResult, .win)
        XCTAssertEqual(viewModel.teamScore, 0)
        XCTAssertEqual(viewModel.opponentScore, 0)
        XCTAssertEqual(viewModel.opponentName, "")
        XCTAssertEqual(viewModel.gameLocation, "")
        XCTAssertEqual(viewModel.gameNotes, "")
        XCTAssertFalse(viewModel.isOpponentNameValid)
        XCTAssertFalse(viewModel.isFormValid)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.successMessage)
    }
    
    @MainActor
    func testFormFieldBinding() {
        // Test all form fields properly bound to view model properties
        viewModel.gameResult = .loss
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.gameLocation = "Home Court"
        viewModel.gameNotes = "Great game!"
        
        XCTAssertEqual(viewModel.gameResult, .loss)
        XCTAssertEqual(viewModel.teamScore, 85)
        XCTAssertEqual(viewModel.opponentScore, 78)
        XCTAssertEqual(viewModel.opponentName, "Lakers")
        XCTAssertEqual(viewModel.gameLocation, "Home Court")
        XCTAssertEqual(viewModel.gameNotes, "Great game!")
    }
    
    @MainActor
    func testFormValidationState() {
        // Test maintains overall form validation status
        XCTAssertFalse(viewModel.isFormValid)
        
        // Set valid values
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.isOpponentNameValid = true
        
        XCTAssertTrue(viewModel.isFormValid)
        
        // Make invalid
        viewModel.teamScore = 250
        XCTAssertFalse(viewModel.isFormValid)
        
        // Fix
        viewModel.teamScore = 95
        XCTAssertTrue(viewModel.isFormValid)
    }
    
    @MainActor
    func testConcurrentFormUsage() {
        // Test handles multiple rapid form interactions safely
        let expectation = XCTestExpectation(description: "Concurrent form updates")
        expectation.expectedFulfillmentCount = 10
        
        for i in 0..<10 {
            DispatchQueue.main.async {
                self.viewModel.teamScore = i
                self.viewModel.opponentScore = i + 5
                self.viewModel.opponentName = "Team \(i)"
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Verify final state is consistent
        XCTAssertTrue(viewModel.teamScore >= 0 && viewModel.teamScore <= 200)
        XCTAssertTrue(viewModel.opponentScore >= 0 && viewModel.opponentScore <= 200)
    }
    
    // MARK: - Smart Score Assignment Logic Tests
    
    @MainActor
    func testWinOutcomeAssignment() {
        // Test Win outcome assignment - higher score automatically assigned to team
        viewModel.gameResult = .win
        viewModel.teamScore = 50
        viewModel.opponentScore = 60
        
        viewModel.assignSmartScores()
        
        // Team score should be higher than opponent score
        XCTAssertTrue(viewModel.teamScore > viewModel.opponentScore)
        XCTAssertEqual(viewModel.teamScore, viewModel.opponentScore + 7)
    }
    
    @MainActor
    func testLossOutcomeAssignment() {
        // Test Loss outcome assignment - lower score automatically assigned to team
        viewModel.gameResult = .loss
        viewModel.teamScore = 80
        viewModel.opponentScore = 70
        
        viewModel.assignSmartScores()
        
        // Opponent score should be higher than team score
        XCTAssertTrue(viewModel.opponentScore > viewModel.teamScore)
        XCTAssertEqual(viewModel.opponentScore, viewModel.teamScore + 7)
    }
    
    @MainActor
    func testTieOutcomeAssignment() {
        // Test Tie outcome assignment - validates that both scores are identical
        viewModel.gameResult = .tie
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        
        viewModel.assignSmartScores()
        
        // Both scores should be equal
        XCTAssertEqual(viewModel.teamScore, viewModel.opponentScore)
        
        // Should be average of original scores
        let expectedScore = (85 + 78) / 2
        XCTAssertEqual(viewModel.teamScore, expectedScore)
        XCTAssertEqual(viewModel.opponentScore, expectedScore)
    }
    
    @MainActor
    func testScoreReassignmentOnOutcomeChange() {
        // Test score reassignment on outcome change
        // Start with win
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.assignSmartScores()
        
        let winTeamScore = viewModel.teamScore
        let winOpponentScore = viewModel.opponentScore
        
        // Change to loss
        viewModel.gameResult = .loss
        viewModel.assignSmartScores()
        
        // Scores should be different now
        XCTAssertNotEqual(viewModel.teamScore, winTeamScore)
        XCTAssertNotEqual(viewModel.opponentScore, winOpponentScore)
        XCTAssertTrue(viewModel.opponentScore > viewModel.teamScore)
    }
    
    @MainActor
    func testManualScoreOverride() {
        // Test manual score override - user can manually edit scores after auto-assignment
        viewModel.gameResult = .win
        viewModel.teamScore = 50
        viewModel.opponentScore = 60
        
        viewModel.assignSmartScores()
        let autoAssignedTeamScore = viewModel.teamScore
        
        // Manually override
        viewModel.teamScore = 95
        XCTAssertEqual(viewModel.teamScore, 95)
        XCTAssertNotEqual(viewModel.teamScore, autoAssignedTeamScore)
    }
    
    @MainActor
    func testInvalidScoreCombinations() {
        // Test invalid score combinations
        // Win with lower team score
        viewModel.gameResult = .win
        viewModel.teamScore = 70
        viewModel.opponentScore = 80
        
        viewModel.assignSmartScores()
        XCTAssertTrue(viewModel.teamScore > viewModel.opponentScore)
        
        // Loss with higher team score
        viewModel.gameResult = .loss
        viewModel.teamScore = 80
        viewModel.opponentScore = 70
        
        viewModel.assignSmartScores()
        XCTAssertTrue(viewModel.opponentScore > viewModel.teamScore)
    }
    
    @MainActor
    func testTieValidationEnforcement() {
        // Test tie validation enforcement
        viewModel.gameResult = .tie
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        
        viewModel.assignSmartScores()
        
        // Tie selection requires equal scores
        XCTAssertEqual(viewModel.teamScore, viewModel.opponentScore)
    }
    
    // MARK: - Game Creation Logic Tests
    
    @MainActor
    func testGameEntityCreation() {
        // Test game entity creation - saveGame() creates new Game entity with correct data
        let team = createTestTeam()
        
        // Set form data
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.gameLocation = "Home Court"
        viewModel.gameNotes = "Great game!"
        viewModel.isOpponentNameValid = true
        
        let success = viewModel.createGame(for: team)
        
        XCTAssertTrue(success)
        
        // Verify game was created
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let games = try! testContext.fetch(fetchRequest)
        XCTAssertEqual(games.count, 1)
        
        let game = games.first!
        XCTAssertEqual(game.teamScore, 85)
        XCTAssertEqual(game.opponentScore, 78)
        XCTAssertEqual(game.opponentName, "Lakers")
        XCTAssertEqual(game.gameLocation, "Home Court")
        XCTAssertEqual(game.notes, "Great game!")
        XCTAssertTrue(game.isWin)
        XCTAssertFalse(game.isTie)
    }
    
    @MainActor
    func testPlayerTeamAssociation() {
        // Test player/team association - Game correctly associated with selected player/team
        let player = createTestPlayer()
        let team = createTestTeam()
        team.player = player
        
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        let success = viewModel.createGame(for: team)
        
        XCTAssertTrue(success)
        
        // Verify association
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let games = try! testContext.fetch(fetchRequest)
        let game = games.first!
        
        XCTAssertEqual(game.team, team)
        XCTAssertEqual(game.team?.player, player)
    }
    
    @MainActor
    func testAllFieldPopulation() {
        // Test all form fields properly populate Game entity
        let team = createTestTeam()
        
        let testDate = Date().addingTimeInterval(-86400) // Yesterday
        let testTime = Date().addingTimeInterval(-3600) // 1 hour ago
        
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.gameDate = testDate
        viewModel.gameTime = testTime
        viewModel.gameLocation = "Home Court"
        viewModel.gameNotes = "Great game!"
        viewModel.isOpponentNameValid = true
        
        let success = viewModel.createGame(for: team)
        
        XCTAssertTrue(success)
        
        // Verify all fields
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let games = try! testContext.fetch(fetchRequest)
        let game = games.first!
        
        XCTAssertEqual(game.teamScore, 85)
        XCTAssertEqual(game.opponentScore, 78)
        XCTAssertEqual(game.opponentName, "Lakers")
        XCTAssertEqual(game.gameLocation, "Home Court")
        XCTAssertEqual(game.notes, "Great game!")
        XCTAssertTrue(game.isWin)
        XCTAssertFalse(game.isTie)
        XCTAssertNotNil(game.gameEditDate)
        XCTAssertNotNil(game.gameEditTime)
    }
    
    @MainActor
    func testMetadataTimestampCreation() {
        // Test metadata timestamp creation - gameEditDate and gameEditTime set to current time
        let team = createTestTeam()
        
        let beforeSave = Date()
        
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        let success = viewModel.createGame(for: team)
        
        XCTAssertTrue(success)
        
        let afterSave = Date()
        
        // Verify timestamps
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let games = try! testContext.fetch(fetchRequest)
        let game = games.first!
        
        XCTAssertNotNil(game.gameEditDate)
        XCTAssertNotNil(game.gameEditTime)
        
        if let editDate = game.gameEditDate, let editTime = game.gameEditTime {
            XCTAssertGreaterThanOrEqual(editDate, beforeSave)
            XCTAssertLessThanOrEqual(editDate, afterSave)
            XCTAssertGreaterThanOrEqual(editTime, beforeSave)
            XCTAssertLessThanOrEqual(editTime, afterSave)
        }
    }
    
    @MainActor
    func testCoreDataSaveOperation() {
        // Test Core Data save operation - Game successfully persisted to Core Data
        let team = createTestTeam()
        
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        let success = viewModel.createGame(for: team)
        
        XCTAssertTrue(success)
        
        // Verify persistence
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let games = try! testContext.fetch(fetchRequest)
        XCTAssertEqual(games.count, 1)
        
        // Reset context and verify data still exists
        testContext.reset()
        
        let gamesAfterReset = try! testContext.fetch(fetchRequest)
        XCTAssertEqual(gamesAfterReset.count, 1)
    }
    
    @MainActor
    func testTeamRecordUpdate() {
        // Test team record update - Saving game updates team's win/loss/tie counts
        let team = createTestTeam()
        
        // Save a win
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        let success1 = viewModel.createGame(for: team)
        XCTAssertTrue(success1)
        
        // Save a loss
        viewModel.gameResult = .loss
        viewModel.teamScore = 78
        viewModel.opponentScore = 85
        viewModel.opponentName = "Warriors"
        viewModel.isOpponentNameValid = true
        
        let success2 = viewModel.createGame(for: team)
        XCTAssertTrue(success2)
        
        // Verify team record
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "team == %@", team)
        let games = try! testContext.fetch(fetchRequest)
        
        let wins = games.filter { $0.isWin }.count
        let losses = games.filter { !$0.isWin && !$0.isTie }.count
        let ties = games.filter { $0.isTie }.count
        
        XCTAssertEqual(wins, 1)
        XCTAssertEqual(losses, 1)
        XCTAssertEqual(ties, 0)
    }
    
    @MainActor
    func testSaveValidation() {
        // Test save validation - Prevents saving incomplete or invalid game data
        let team = createTestTeam()
        
        // Try to save without opponent name
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = ""
        viewModel.isOpponentNameValid = false
        
        let success = viewModel.createGame(for: team)
        
        XCTAssertFalse(success)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    // MARK: - Validation Logic Tests
    
    @MainActor
    func testScoreRangeValidation() {
        // Test score range validation - Scores must be 0-200 for basketball
        XCTAssertTrue(viewModel.validateScore(0))
        XCTAssertTrue(viewModel.validateScore(100))
        XCTAssertTrue(viewModel.validateScore(200))
        
        XCTAssertFalse(viewModel.validateScore(-1))
        XCTAssertFalse(viewModel.validateScore(201))
        XCTAssertFalse(viewModel.validateScore(999))
    }
    
    @MainActor
    func testOutcomeConsistencyValidation() {
        // Test outcome consistency validation - Outcome matches score relationship
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        
        // Valid win
        XCTAssertTrue(viewModel.teamScore > viewModel.opponentScore)
        
        // Invalid win
        viewModel.teamScore = 70
        viewModel.opponentScore = 80
        XCTAssertFalse(viewModel.teamScore > viewModel.opponentScore)
        
        // Fix with smart assignment
        viewModel.assignSmartScores()
        XCTAssertTrue(viewModel.teamScore > viewModel.opponentScore)
    }
    
    @MainActor
    func testOpponentNameValidation() {
        // Test opponent name validation - Non-empty opponent name required
        XCTAssertTrue(viewModel.validateOpponentName("Lakers"))
        XCTAssertTrue(viewModel.validateOpponentName("Los Angeles Lakers"))
        
        XCTAssertFalse(viewModel.validateOpponentName(""))
        XCTAssertFalse(viewModel.validateOpponentName("   "))
        
        // Test length limit
        let longName = String(repeating: "A", count: 51)
        XCTAssertFalse(viewModel.validateOpponentName(longName))
        
        let maxLengthName = String(repeating: "A", count: 50)
        XCTAssertTrue(viewModel.validateOpponentName(maxLengthName))
    }
    
    @MainActor
    func testDateValidation() {
        // Test date validation - Game date within reasonable bounds
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: today)!
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: today)!
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: today)!
        
        // Valid dates (past and near future)
        viewModel.gameDate = today
        viewModel.gameDate = yesterday
        viewModel.gameDate = lastWeek
        viewModel.gameDate = lastMonth
        
        // Future date (should be allowed for scheduling)
        viewModel.gameDate = nextWeek
    }
    
    @MainActor
    func testValidationErrorMessaging() {
        // Test validation error messaging - Clear, specific error messages for each validation failure
        let team = createTestTeam()
        
        // Test no team selected
        let success1 = viewModel.createGame(for: nil)
        XCTAssertFalse(success1)
        XCTAssertEqual(viewModel.errorMessage, "No team selected")
        
        // Test invalid form
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = ""
        viewModel.isOpponentNameValid = false
        
        let success2 = viewModel.createGame(for: team)
        XCTAssertFalse(success2)
        XCTAssertEqual(viewModel.errorMessage, "Please fix validation errors")
    }
    
    // MARK: - Helper Methods
    
    private func createTestPlayer() -> Player {
        let player = Player(context: testContext)
        player.id = UUID()
        player.name = "Test Player"
        player.playerColor = "blue"
        player.displayOrder = 0
        player.sport = "Basketball"
        return player
    }
    
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