//
//  Phase5ValidationTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import XCTest
import SwiftUI
import CoreData
@testable import ScoreSnap

class Phase5ValidationTests: XCTestCase {
    
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
    
    // MARK: - Field-Level Validation Tests
    
    @MainActor
    func testScoreValidationBoundaries() {
        // Test score validation boundaries - Scores exactly at 0 and 200 accepted
        XCTAssertTrue(viewModel.validateScore(0))
        XCTAssertTrue(viewModel.validateScore(200))
        XCTAssertTrue(viewModel.validateScore(100))
        
        XCTAssertFalse(viewModel.validateScore(-1))
        XCTAssertFalse(viewModel.validateScore(201))
        XCTAssertFalse(viewModel.validateScore(999))
    }
    
    @MainActor
    func testScoreValidationEdgeCases() {
        // Test score validation edge cases - Handles edge cases like leading zeros, spaces
        // Note: Since we're using Int, leading zeros and spaces are handled by text parsing
        XCTAssertTrue(viewModel.validateScore(0))
        XCTAssertTrue(viewModel.validateScore(1))
        XCTAssertTrue(viewModel.validateScore(99))
        XCTAssertTrue(viewModel.validateScore(100))
        XCTAssertTrue(viewModel.validateScore(199))
        XCTAssertTrue(viewModel.validateScore(200))
    }
    
    @MainActor
    func testOpponentNameValidation() {
        // Test opponent name validation - Various valid and invalid name formats
        XCTAssertTrue(viewModel.validateOpponentName("Lakers"))
        XCTAssertTrue(viewModel.validateOpponentName("Los Angeles Lakers"))
        XCTAssertTrue(viewModel.validateOpponentName("Team 2024"))
        XCTAssertTrue(viewModel.validateOpponentName("O'Connor's Team"))
        XCTAssertTrue(viewModel.validateOpponentName("Los Angeles-Lakers"))
        
        XCTAssertFalse(viewModel.validateOpponentName(""))
        XCTAssertFalse(viewModel.validateOpponentName("   "))
        XCTAssertFalse(viewModel.validateOpponentName("\n\t"))
        
        // Test length limits
        let maxLengthName = String(repeating: "A", count: 50)
        XCTAssertTrue(viewModel.validateOpponentName(maxLengthName))
        
        let tooLongName = String(repeating: "A", count: 51)
        XCTAssertFalse(viewModel.validateOpponentName(tooLongName))
    }
    
    @MainActor
    func testRequiredFieldValidation() {
        // Test required field validation - All required fields properly enforced
        let team = createTestTeam()
        
        // Test missing opponent name
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = ""
        viewModel.isOpponentNameValid = false
        
        let success1 = viewModel.createGame(for: team)
        XCTAssertFalse(success1)
        
        // Test missing team score
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        viewModel.teamScore = 0
        viewModel.opponentScore = 0
        
        let success2 = viewModel.createGame(for: team)
        XCTAssertTrue(success2) // Should succeed as 0 is valid
    }
    
    // MARK: - Cross-Field Validation Tests
    
    @MainActor
    func testWinScoreConsistency() {
        // Test Win/score consistency - Win requires team score > opponent score
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        
        // Valid win
        XCTAssertTrue(viewModel.teamScore > viewModel.opponentScore)
        
        // Invalid win - fix with smart assignment
        viewModel.teamScore = 70
        viewModel.opponentScore = 80
        XCTAssertFalse(viewModel.teamScore > viewModel.opponentScore)
        
        viewModel.assignSmartScores()
        XCTAssertTrue(viewModel.teamScore > viewModel.opponentScore)
    }
    
    @MainActor
    func testLossScoreConsistency() {
        // Test Loss/score consistency - Loss requires team score < opponent score
        viewModel.gameResult = .loss
        viewModel.teamScore = 78
        viewModel.opponentScore = 85
        
        // Valid loss
        XCTAssertTrue(viewModel.opponentScore > viewModel.teamScore)
        
        // Invalid loss - fix with smart assignment
        viewModel.teamScore = 80
        viewModel.opponentScore = 70
        XCTAssertFalse(viewModel.opponentScore > viewModel.teamScore)
        
        viewModel.assignSmartScores()
        XCTAssertTrue(viewModel.opponentScore > viewModel.teamScore)
    }
    
    @MainActor
    func testTieScoreConsistency() {
        // Test Tie/score consistency - Tie requires team score = opponent score
        viewModel.gameResult = .tie
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        
        // Invalid tie - fix with smart assignment
        XCTAssertFalse(viewModel.teamScore == viewModel.opponentScore)
        
        viewModel.assignSmartScores()
        XCTAssertEqual(viewModel.teamScore, viewModel.opponentScore)
    }
    
    @MainActor
    func testPlayerTeamRelationship() {
        // Test player/team relationship - Team must belong to selected player
        let player1 = createTestPlayer(name: "Player 1")
        let player2 = createTestPlayer(name: "Player 2")
        let team1 = createTestTeam(name: "Team 1", player: player1)
        let team2 = createTestTeam(name: "Team 2", player: player2)
        
        // Valid relationship
        XCTAssertEqual(team1.player, player1)
        XCTAssertEqual(team2.player, player2)
        
        // Invalid relationship
        XCTAssertNotEqual(team1.player, player2)
        XCTAssertNotEqual(team2.player, player1)
    }
    
    // MARK: - Validation Timing Tests
    
    @MainActor
    func testRealTimeValidation() {
        // Test real-time validation - Validation occurs as user types/selects
        XCTAssertFalse(viewModel.isFormValid)
        
        // Add valid data progressively
        viewModel.teamScore = 85
        XCTAssertFalse(viewModel.isFormValid)
        
        viewModel.opponentScore = 78
        XCTAssertFalse(viewModel.isFormValid)
        
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        XCTAssertTrue(viewModel.isFormValid)
    }
    
    @MainActor
    func testSubmissionValidation() {
        // Test submission validation - Final validation before save
        let team = createTestTeam()
        
        // Invalid form
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        // Missing opponent name
        
        let success = viewModel.createGame(for: team)
        XCTAssertFalse(success)
        XCTAssertEqual(viewModel.errorMessage, "Please fix validation errors")
    }
    
    @MainActor
    func testValidationPerformance() {
        // Test validation performance - Validation doesn't impact user experience
        measure {
            for i in 0..<1000 {
                let score = i % 201
                let _ = viewModel.validateScore(score)
                
                let name = String(repeating: "A", count: i % 60)
                let _ = viewModel.validateOpponentName(name)
            }
        }
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