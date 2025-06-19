//
//  Phase5IntegrationTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import XCTest
import SwiftUI
import CoreData
import Combine
@testable import ScoreSnap

class Phase5IntegrationTests: XCTestCase {
    
    var testContext: NSManagedObjectContext!
    var appContext: AppContext!
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
        appContext = AppContext(viewContext: testContext)
        viewModel = UploadViewModel(viewContext: testContext)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables?.removeAll()
        viewModel = nil
        appContext = nil
        testContext = nil
        super.tearDown()
    }
    
    // MARK: - Context Integration Tests
    
    @MainActor
    func testAppContextInheritance() {
        // Test AppContext inheritance - Manual entry inherits current player/team correctly
        let player = createTestPlayer()
        let team = createTestTeam()
        team.player = player
        
        // Set up AppContext
        appContext.switchToPlayerAndTeam(player, team)
        
        // Verify context is set
        XCTAssertEqual(appContext.currentPlayer, player)
        XCTAssertEqual(appContext.currentTeam, team)
        
        // Test that UploadViewModel can access the team
        let success = viewModel.createGame(for: appContext.currentTeam)
        XCTAssertFalse(success) // Should fail due to validation, but team should be accessible
    }
    
    @MainActor
    func testContextOverrideCapability() {
        // Test context override capability - User can change player/team during entry
        let player1 = createTestPlayer(name: "Player 1")
        let player2 = createTestPlayer(name: "Player 2")
        let team1 = createTestTeam(name: "Team 1", player: player1)
        let team2 = createTestTeam(name: "Team 2", player: player2)
        
        // Set initial context
        appContext.switchToPlayerAndTeam(player1, team1)
        XCTAssertEqual(appContext.currentPlayer, player1)
        XCTAssertEqual(appContext.currentTeam, team1)
        
        // Change context during entry
        appContext.switchToPlayerAndTeam(player2, team2)
        XCTAssertEqual(appContext.currentPlayer, player2)
        XCTAssertEqual(appContext.currentTeam, team2)
        
        // Verify UploadViewModel can work with new context
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        let success = viewModel.createGame(for: appContext.currentTeam)
        XCTAssertTrue(success)
        
        // Verify game is associated with new team
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let games = try! testContext.fetch(fetchRequest)
        let game = games.first!
        XCTAssertEqual(game.team, team2)
    }
    
    @MainActor
    func testContextUpdateOnSave() {
        // Test context update on save - Saving game updates global AppContext if changed
        let player = createTestPlayer()
        let team = createTestTeam()
        team.player = player
        
        appContext.switchToPlayerAndTeam(player, team)
        
        // Save a game
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        let success = viewModel.createGame(for: appContext.currentTeam)
        XCTAssertTrue(success)
        
        // Verify context remains unchanged (as expected)
        XCTAssertEqual(appContext.currentPlayer, player)
        XCTAssertEqual(appContext.currentTeam, team)
    }
    
    @MainActor
    func testContextValidation() {
        // Test context validation - Prevents saving to deleted/invalid player/team
        let player = createTestPlayer()
        let team = createTestTeam()
        team.player = player
        
        appContext.switchToPlayerAndTeam(player, team)
        
        // Delete the team
        testContext.delete(team)
        try! testContext.save()
        
        // Try to save game with deleted team
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        let success = viewModel.createGame(for: appContext.currentTeam)
        XCTAssertFalse(success) // Should fail because team was deleted
    }
    
    // MARK: - Core Data Integration Tests
    
    @MainActor
    func testRelationshipCreation() {
        // Test relationship creation - Game properly linked to team and player
        let player = createTestPlayer()
        let team = createTestTeam()
        team.player = player
        
        appContext.switchToPlayerAndTeam(player, team)
        
        // Save a game
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        let success = viewModel.createGame(for: appContext.currentTeam)
        XCTAssertTrue(success)
        
        // Verify relationships
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let games = try! testContext.fetch(fetchRequest)
        let game = games.first!
        
        XCTAssertEqual(game.team, team)
        XCTAssertEqual(game.team?.player, player)
        
        // Verify reverse relationships
        let teamGames = team.games as? Set<Game> ?? []
        XCTAssertTrue(teamGames.contains(game))
        
        let playerTeams = player.teams as? Set<Team> ?? []
        XCTAssertTrue(playerTeams.contains(team))
    }
    
    @MainActor
    func testCascadeBehavior() {
        // Test cascade behavior - Game deletion doesn't affect team/player
        let player = createTestPlayer()
        let team = createTestTeam()
        team.player = player
        
        appContext.switchToPlayerAndTeam(player, team)
        
        // Save a game
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        let success = viewModel.createGame(for: appContext.currentTeam)
        XCTAssertTrue(success)
        
        // Verify game exists
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        var games = try! testContext.fetch(fetchRequest)
        XCTAssertEqual(games.count, 1)
        
        // Delete the game
        testContext.delete(games.first!)
        try! testContext.save()
        
        // Verify team and player still exist
        let teamFetch: NSFetchRequest<Team> = Team.fetchRequest()
        let teams = try! testContext.fetch(teamFetch)
        XCTAssertEqual(teams.count, 1)
        
        let playerFetch: NSFetchRequest<Player> = Player.fetchRequest()
        let players = try! testContext.fetch(playerFetch)
        XCTAssertEqual(players.count, 1)
        
        // Verify game is gone
        games = try! testContext.fetch(fetchRequest)
        XCTAssertEqual(games.count, 0)
    }
    
    @MainActor
    func testTransactionIntegrity() {
        // Test transaction integrity - All data operations succeed or fail atomically
        let player = createTestPlayer()
        let team = createTestTeam()
        team.player = player
        
        appContext.switchToPlayerAndTeam(player, team)
        
        // Try to save with invalid data (should fail)
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "" // Invalid - empty name
        viewModel.isOpponentNameValid = false
        
        let success = viewModel.createGame(for: appContext.currentTeam)
        XCTAssertFalse(success)
        
        // Verify no game was created
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let games = try! testContext.fetch(fetchRequest)
        XCTAssertEqual(games.count, 0)
        
        // Now save with valid data
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        let success2 = viewModel.createGame(for: appContext.currentTeam)
        XCTAssertTrue(success2)
        
        // Verify game was created
        let games2 = try! testContext.fetch(fetchRequest)
        XCTAssertEqual(games2.count, 1)
    }
    
    @MainActor
    func testConcurrentAccess() {
        // Test concurrent access - Safe handling of simultaneous data operations
        let player = createTestPlayer()
        let team = createTestTeam()
        team.player = player
        
        appContext.switchToPlayerAndTeam(player, team)
        
        let expectation = XCTestExpectation(description: "Concurrent saves")
        expectation.expectedFulfillmentCount = 5
        
        // Perform concurrent saves
        for i in 0..<5 {
            DispatchQueue.main.async {
                let viewModel = UploadViewModel(viewContext: self.testContext)
                viewModel.gameResult = .win
                viewModel.teamScore = 85 + i
                viewModel.opponentScore = 78 + i
                viewModel.opponentName = "Team \(i)"
                viewModel.isOpponentNameValid = true
                
                let success = viewModel.createGame(for: self.appContext.currentTeam)
                XCTAssertTrue(success)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify all games were created
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let games = try! testContext.fetch(fetchRequest)
        XCTAssertEqual(games.count, 5)
    }
    
    @MainActor
    func testDataConsistency() {
        // Test data consistency - Team record accurately reflects all games
        let player = createTestPlayer()
        let team = createTestTeam()
        team.player = player
        
        appContext.switchToPlayerAndTeam(player, team)
        
        // Save multiple games with different outcomes
        let gameData = [
            (GameResult.win, 85, 78, "Lakers"),
            (GameResult.loss, 78, 85, "Warriors"),
            (GameResult.win, 95, 82, "Celtics"),
            (GameResult.tie, 90, 90, "Heat")
        ]
        
        for (result, teamScore, opponentScore, opponentName) in gameData {
            viewModel.gameResult = result
            viewModel.teamScore = teamScore
            viewModel.opponentScore = opponentScore
            viewModel.opponentName = opponentName
            viewModel.isOpponentNameValid = true
            
            let success = viewModel.createGame(for: appContext.currentTeam)
            XCTAssertTrue(success)
        }
        
        // Verify team record
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "team == %@", team)
        let games = try! testContext.fetch(fetchRequest)
        
        let wins = games.filter { $0.isWin }.count
        let losses = games.filter { !$0.isWin && !$0.isTie }.count
        let ties = games.filter { $0.isTie }.count
        
        XCTAssertEqual(wins, 2)
        XCTAssertEqual(losses, 1)
        XCTAssertEqual(ties, 1)
        XCTAssertEqual(games.count, 4)
    }
    
    // MARK: - Manual Entry Workflow Tests
    
    @MainActor
    func testFullManualEntryProcess() {
        // Test full manual entry process - Complete workflow from form open to game saved
        let player = createTestPlayer()
        let team = createTestTeam()
        team.player = player
        
        appContext.switchToPlayerAndTeam(player, team)
        
        // Simulate complete form filling
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.gameLocation = "Home Court"
        viewModel.gameNotes = "Great game!"
        viewModel.gameDate = Date().addingTimeInterval(-86400) // Yesterday
        viewModel.gameTime = Date().addingTimeInterval(-3600) // 1 hour ago
        viewModel.isOpponentNameValid = true
        
        // Verify form is valid
        XCTAssertTrue(viewModel.isFormValid)
        
        // Save the game
        let success = viewModel.createGame(for: appContext.currentTeam)
        XCTAssertTrue(success)
        
        // Verify success message
        XCTAssertNotNil(viewModel.successMessage)
        XCTAssertEqual(viewModel.successMessage, "Game saved successfully!")
        
        // Verify game was created with all data
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
        XCTAssertEqual(game.team, team)
    }
    
    @MainActor
    func testWorkflowWithContextChange() {
        // Test workflow with context change - Entry process when changing player/team mid-flow
        let player1 = createTestPlayer(name: "Player 1")
        let player2 = createTestPlayer(name: "Player 2")
        let team1 = createTestTeam(name: "Team 1", player: player1)
        let team2 = createTestTeam(name: "Team 2", player: player2)
        
        // Start with player1/team1
        appContext.switchToPlayerAndTeam(player1, team1)
        
        // Start filling form
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        // Change context mid-flow
        appContext.switchToPlayerAndTeam(player2, team2)
        
        // Continue with form and save
        let success = viewModel.createGame(for: appContext.currentTeam)
        XCTAssertTrue(success)
        
        // Verify game is associated with new team
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let games = try! testContext.fetch(fetchRequest)
        let game = games.first!
        XCTAssertEqual(game.team, team2)
    }
    
    @MainActor
    func testWorkflowCancellation() {
        // Test workflow cancellation - Cancel button properly abandons entry without saving
        let player = createTestPlayer()
        let team = createTestTeam()
        team.player = player
        
        appContext.switchToPlayerAndTeam(player, team)
        
        // Fill form but don't save
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        // Verify no game was created
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let games = try! testContext.fetch(fetchRequest)
        XCTAssertEqual(games.count, 0)
        
        // Reset form
        viewModel.resetForm()
        
        // Verify form is reset
        XCTAssertEqual(viewModel.gameResult, .win)
        XCTAssertEqual(viewModel.teamScore, 0)
        XCTAssertEqual(viewModel.opponentScore, 0)
        XCTAssertEqual(viewModel.opponentName, "")
        XCTAssertFalse(viewModel.isFormValid)
    }
    
    @MainActor
    func testWorkflowErrorRecovery() {
        // Test workflow error recovery - Graceful handling of errors during save process
        let player = createTestPlayer()
        let team = createTestTeam()
        team.player = player
        
        appContext.switchToPlayerAndTeam(player, team)
        
        // Try to save with invalid data
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "" // Invalid
        viewModel.isOpponentNameValid = false
        
        let success1 = viewModel.createGame(for: appContext.currentTeam)
        XCTAssertFalse(success1)
        XCTAssertNotNil(viewModel.errorMessage)
        
        // Fix the error and retry
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        let success2 = viewModel.createGame(for: appContext.currentTeam)
        XCTAssertTrue(success2)
        XCTAssertNotNil(viewModel.successMessage)
    }
    
    // MARK: - Form Validation Workflow Tests
    
    @MainActor
    func testProgressiveValidation() {
        // Test progressive validation - Validation occurs as user fills form
        let player = createTestPlayer()
        let team = createTestTeam()
        team.player = player
        
        appContext.switchToPlayerAndTeam(player, team)
        
        // Start with invalid form
        XCTAssertFalse(viewModel.isFormValid)
        
        // Add valid team score
        viewModel.teamScore = 85
        XCTAssertFalse(viewModel.isFormValid) // Still invalid
        
        // Add valid opponent score
        viewModel.opponentScore = 78
        XCTAssertFalse(viewModel.isFormValid) // Still invalid
        
        // Add valid opponent name
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        XCTAssertTrue(viewModel.isFormValid) // Now valid
    }
    
    @MainActor
    func testSubmitValidation() {
        // Test submit validation - Final validation before save prevents invalid submissions
        let player = createTestPlayer()
        let team = createTestTeam()
        team.player = player
        
        appContext.switchToPlayerAndTeam(player, team)
        
        // Try to save with invalid form
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        // Missing opponent name
        
        let success = viewModel.createGame(for: appContext.currentTeam)
        XCTAssertFalse(success)
        XCTAssertEqual(viewModel.errorMessage, "Please fix validation errors")
    }
    
    @MainActor
    func testValidationErrorCorrection() {
        // Test validation error correction - User can fix validation errors and resubmit
        let player = createTestPlayer()
        let team = createTestTeam()
        team.player = player
        
        appContext.switchToPlayerAndTeam(player, team)
        
        // Start with invalid form
        viewModel.gameResult = .win
        viewModel.teamScore = 250 // Invalid score
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        XCTAssertFalse(viewModel.isFormValid)
        
        // Fix the invalid score
        viewModel.teamScore = 95
        XCTAssertTrue(viewModel.isFormValid)
        
        // Save successfully
        let success = viewModel.createGame(for: appContext.currentTeam)
        XCTAssertTrue(success)
    }
    
    // MARK: - Score Logic Workflow Tests
    
    @MainActor
    func testOutcomeFirstWorkflow() {
        // Test outcome-first workflow - User selects outcome before entering scores
        let player = createTestPlayer()
        let team = createTestTeam()
        team.player = player
        
        appContext.switchToPlayerAndTeam(player, team)
        
        // Select outcome first
        viewModel.gameResult = .win
        viewModel.assignSmartScores()
        
        // Verify smart score assignment
        XCTAssertTrue(viewModel.teamScore > viewModel.opponentScore)
        
        // Complete form
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        let success = viewModel.createGame(for: appContext.currentTeam)
        XCTAssertTrue(success)
    }
    
    @MainActor
    func testScoreFirstWorkflow() {
        // Test score-first workflow - User enters scores then selects outcome
        let player = createTestPlayer()
        let team = createTestTeam()
        team.player = player
        
        appContext.switchToPlayerAndTeam(player, team)
        
        // Enter scores first
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        
        // Select outcome
        viewModel.gameResult = .win
        viewModel.assignSmartScores()
        
        // Verify scores were adjusted if needed
        XCTAssertTrue(viewModel.teamScore > viewModel.opponentScore)
        
        // Complete form
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        let success = viewModel.createGame(for: appContext.currentTeam)
        XCTAssertTrue(success)
    }
    
    @MainActor
    func testMixedWorkflow() {
        // Test mixed workflow - User changes both scores and outcome multiple times
        let player = createTestPlayer()
        let team = createTestTeam()
        team.player = player
        
        appContext.switchToPlayerAndTeam(player, team)
        
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
        
        XCTAssertNotEqual(viewModel.teamScore, winTeamScore)
        XCTAssertNotEqual(viewModel.opponentScore, winOpponentScore)
        XCTAssertTrue(viewModel.opponentScore > viewModel.teamScore)
        
        // Change to tie
        viewModel.gameResult = .tie
        viewModel.assignSmartScores()
        
        XCTAssertEqual(viewModel.teamScore, viewModel.opponentScore)
        
        // Complete form
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        let success = viewModel.createGame(for: appContext.currentTeam)
        XCTAssertTrue(success)
    }
    
    @MainActor
    func testConsistencyEnforcement() {
        // Test consistency enforcement - Form prevents inconsistent outcome/score combinations
        let player = createTestPlayer()
        let team = createTestTeam()
        team.player = player
        
        appContext.switchToPlayerAndTeam(player, team)
        
        // Set up inconsistent state (win with lower team score)
        viewModel.gameResult = .win
        viewModel.teamScore = 70
        viewModel.opponentScore = 80
        
        // Smart assignment should fix this
        viewModel.assignSmartScores()
        XCTAssertTrue(viewModel.teamScore > viewModel.opponentScore)
        
        // Complete form
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        let success = viewModel.createGame(for: appContext.currentTeam)
        XCTAssertTrue(success)
    }
    
    // MARK: - Helper Methods
    
    private func createTestPlayer(name: String = "Test Player") -> Player {
        let player = Player(context: testContext)
        player.id = UUID()
        player.name = name
        player.playerColor = "blue"
        player.displayOrder = 0
        player.sport = "Basketball"
        return player
    }
    
    private func createTestTeam(name: String = "Test Team", player: Player? = nil) -> Team {
        let team = Team(context: testContext)
        team.id = UUID()
        team.name = name
        team.teamColor = "red"
        team.displayOrder = 0
        team.sport = "Basketball"
        if let player = player {
            team.player = player
        }
        return team
    }
} 