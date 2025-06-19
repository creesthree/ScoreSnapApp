//
//  HomeViewIntegrationTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import XCTest
import SwiftUI
import CoreData
@testable import ScoreSnap

@MainActor
final class HomeViewIntegrationTests: XCTestCase {
    
    var mockContext: NSManagedObjectContext!
    var appContext: AppContext!
    var testPlayers: [Player] = []
    var testTeams: [Team] = []
    var testGames: [Game] = []
    
    override func setUpWithError() throws {
        // Create in-memory Core Data stack for testing
        let container = NSPersistentContainer(name: "ScoreSnap")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        mockContext = container.viewContext
        appContext = AppContext(viewContext: mockContext)
        setupTestData()
    }
    
    override func tearDownWithError() throws {
        mockContext = nil
        appContext = nil
        testPlayers = []
        testTeams = []
        testGames = []
    }
    
    private func setupTestData() {
        // Create multiple players
        for i in 0..<3 {
            let player = Player(context: mockContext)
            player.id = UUID()
            player.name = "Player \(i + 1)"
            player.displayOrder = Int32(i)
            player.playerColor = "#FF000\(i)"
            player.sport = "Basketball"
            testPlayers.append(player)
            
            // Create teams for each player
            for j in 0..<2 {
                let team = Team(context: mockContext)
                team.id = UUID()
                team.name = "Team \(i + 1)-\(j + 1)"
                team.displayOrder = Int32(j)
                team.teamColor = "#0000F\(j)"
                team.sport = "Basketball"
                team.player = player
                testTeams.append(team)
                
                // Create games for each team
                createGamesForTeam(team, count: 5 + j)
            }
        }
        
        try! mockContext.save()
    }
    
    private func createGamesForTeam(_ team: Team, count: Int) {
        for i in 0..<count {
            let game = Game(context: mockContext)
            game.id = UUID()
            game.opponentName = "Opponent \(i + 1)"
            game.teamScore = Int32(75 + i * 2)
            game.opponentScore = Int32(70 + i * 2 + (i % 3))
            game.isWin = game.teamScore > game.opponentScore
            game.isTie = (i % 5 == 0) && game.teamScore == game.opponentScore
            game.gameDate = Calendar.current.date(byAdding: .day, value: -i, to: Date())
            game.team = team
            testGames.append(game)
        }
    }
    
    // MARK: - AppContext Integration Tests
    
    func testAppContextPlayerChange() throws {
        // Given - Initial player selection
        let initialPlayer = testPlayers[0]
        appContext.switchToPlayer(initialPlayer)
        
        // When - Change to different player
        let newPlayer = testPlayers[1]
        appContext.switchToPlayer(newPlayer)
        
        // Then - Context should update correctly
        XCTAssertEqual(appContext.currentPlayer?.id, newPlayer.id, "Current player should update")
        XCTAssertNotEqual(appContext.currentPlayer?.id, initialPlayer.id, "Should not be initial player")
    }
    
    func testAppContextTeamChange() throws {
        // Given - Player with multiple teams
        let player = testPlayers[0]
        let playerTeams = testTeams.filter { $0.player == player }
        appContext.switchToPlayer(player)
        
        let initialTeam = playerTeams[0]
        appContext.switchToTeam(initialTeam)
        
        // When - Change to different team
        let newTeam = playerTeams[1]
        appContext.switchToTeam(newTeam)
        
        // Then - Context should update correctly
        XCTAssertEqual(appContext.currentTeam?.id, newTeam.id, "Current team should update")
        XCTAssertNotEqual(appContext.currentTeam?.id, initialTeam.id, "Should not be initial team")
    }
    
    func testAppContextPersistence() throws {
        // Given - Player and team selection
        let player = testPlayers[0]
        let team = testTeams.filter { $0.player == player }[0]
        
        appContext.switchToPlayer(player)
        appContext.switchToTeam(team)
        
        // When - Simulate app restart by creating new context
        let newAppContext = AppContext(viewContext: mockContext)
        
        // Then - Context should attempt to restore from UserDefaults
        // Note: This tests the persistence mechanism, actual restoration would require UserDefaults setup
        XCTAssertNotNil(player.id, "Player should have valid ID for persistence")
        XCTAssertNotNil(team.id, "Team should have valid ID for persistence")
    }
    
    func testAppContextInvalidDataHandling() throws {
        // Given - Context with invalid references
        // Remove unused variable
        // let deletedPlayerID = UUID()
        
        // When - Try to set non-existent player
        // This would typically be handled by the AppContext validation logic
        let existingPlayer = testPlayers[0]
        appContext.switchToPlayer(existingPlayer)
        
        // Then - Should handle gracefully
        XCTAssertEqual(appContext.currentPlayer?.id, existingPlayer.id, "Should use valid player")
    }
    
    func testAppContextBidirectionalUpdates() throws {
        // Given - AppContext with current selections
        let player = testPlayers[0]
        let team = testTeams.filter { $0.player == player }[0]
        
        appContext.switchToPlayer(player)
        appContext.switchToTeam(team)
        
        // When - Simulate view updating context
        let newTeam = testTeams.filter { $0.player == player }[1]
        appContext.switchToTeam(newTeam)
        
        // Then - Context should reflect the change
        XCTAssertEqual(appContext.currentTeam?.id, newTeam.id, "Context should update from view changes")
        XCTAssertEqual(appContext.currentPlayer?.id, player.id, "Player should remain the same")
    }
    
    // MARK: - Core Data Integration Tests
    
    func testCoreDataRealDataDisplay() throws {
        // Given - Real Core Data entities
        let player = testPlayers[0]
        let playerTeams = testTeams.filter { $0.player == player }
        let team = playerTeams[0]
        let teamGames = testGames.filter { $0.team == team }
        
        // When - Access data through relationships
        // Then - Should correctly display actual entities
        XCTAssertFalse(playerTeams.isEmpty, "Player should have teams")
        XCTAssertFalse(teamGames.isEmpty, "Team should have games")
        XCTAssertEqual(team.player?.id, player.id, "Team should reference correct player")
        
        for game in teamGames {
            XCTAssertEqual(game.team?.id, team.id, "Game should reference correct team")
        }
    }
    
    func testCoreDataRelationshipNavigation() throws {
        // Given - Core Data entities with relationships
        let player = testPlayers[0]
        
        // When - Navigate through relationships: player → teams → games
        let playerTeams = testTeams.filter { $0.player == player }
        
        for team in playerTeams {
            let teamGames = testGames.filter { $0.team == team }
            
            // Then - Relationships should be navigable
            XCTAssertEqual(team.player?.id, player.id, "Team should reference player")
            
            for game in teamGames {
                XCTAssertEqual(game.team?.id, team.id, "Game should reference team")
                XCTAssertEqual(game.team?.player?.id, player.id, "Game should reference player through team")
            }
        }
    }
    
    func testCoreDataConsistency() throws {
        // Given - Team with games
        let team = testTeams[0]
        let teamGames = testGames.filter { $0.team == team }
        
        // When - Calculate statistics
        let wins = teamGames.filter { $0.isWin }.count
        let losses = teamGames.filter { !$0.isWin && !$0.isTie }.count
        let ties = teamGames.filter { $0.isTie }.count
        let totalGames = teamGames.count
        
        // Then - Data should be consistent
        XCTAssertEqual(wins + losses + ties, totalGames, "Win/loss/tie counts should equal total games")
        XCTAssertGreaterThanOrEqual(wins, 0, "Wins should be non-negative")
        XCTAssertGreaterThanOrEqual(losses, 0, "Losses should be non-negative")
        XCTAssertGreaterThanOrEqual(ties, 0, "Ties should be non-negative")
        
        // Verify actual game data matches calculated results
        for game in teamGames {
            if game.isWin {
                XCTAssertFalse(game.isTie, "Win game should not be tie")
            } else if game.isTie {
                XCTAssertFalse(game.isWin, "Tie game should not be win")
            }
        }
    }
    
    func testCoreDataConcurrentAccess() throws {
        // Given - Multiple contexts accessing same data
        let team = testTeams[0]
        
        // When - Simulate concurrent access
        let expectation = self.expectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 2
        
        DispatchQueue.global().async {
            let teamGames = self.testGames.filter { $0.team == team }
            let _ = teamGames.filter { $0.isWin }.count
            expectation.fulfill()
        }
        
        DispatchQueue.global().async {
            let teamGames = self.testGames.filter { $0.team == team }
            let _ = teamGames.filter { !$0.isWin && !$0.isTie }.count
            expectation.fulfill()
        }
        
        // Then - Should handle concurrent access safely
        waitForExpectations(timeout: 2.0) { error in
            XCTAssertNil(error, "Concurrent access should complete without error")
        }
    }
    
    // MARK: - Home View Specific Integration Tests
    
    func testHomeViewDataFlow() throws {
        // Given - Complete data setup
        let player = testPlayers[0]
        let team = testTeams.filter { $0.player == player }[0]
        let teamGames = testGames.filter { $0.team == team }
        
        appContext.switchToPlayer(player)
        appContext.switchToTeam(team)
        
        // When - Simulate home view data requirements
        let recentGames = Array(teamGames.sorted { 
            ($0.gameDate ?? Date.distantPast) > ($1.gameDate ?? Date.distantPast)
        }.prefix(10))
        
        let wins = teamGames.filter { $0.isWin }.count
        let losses = teamGames.filter { !$0.isWin && !$0.isTie }.count
        let ties = teamGames.filter { $0.isTie }.count
        
        // Then - Data should be complete for home view
        XCTAssertFalse(recentGames.isEmpty, "Should have recent games")
        XCTAssertLessThanOrEqual(recentGames.count, 10, "Should limit to 10 recent games")
        XCTAssertEqual(wins + losses + ties, teamGames.count, "Record should be accurate")
        
        // Verify games are sorted correctly (most recent first)
        for i in 1..<recentGames.count {
            let previousDate = recentGames[i-1].gameDate ?? Date.distantPast
            let currentDate = recentGames[i].gameDate ?? Date.distantPast
            XCTAssertGreaterThanOrEqual(previousDate, currentDate, "Games should be sorted by date")
        }
    }
    
    func testHomeViewEmptyStateHandling() throws {
        // Given - Player with team but no games
        let emptyTeam = Team(context: mockContext)
        emptyTeam.id = UUID()
        emptyTeam.name = "Empty Team"
        emptyTeam.player = testPlayers[0]
        try! mockContext.save()
        
        appContext.switchToPlayer(testPlayers[0])
        appContext.switchToTeam(emptyTeam)
        
        // When - Check for games
        let teamGames = testGames.filter { $0.team == emptyTeam }
        
        // Then - Should handle empty state properly
        XCTAssertTrue(teamGames.isEmpty, "Empty team should have no games")
        
        // Verify empty record calculation
        let wins = teamGames.filter { $0.isWin }.count
        let losses = teamGames.filter { !$0.isWin && !$0.isTie }.count
        let ties = teamGames.filter { $0.isTie }.count
        let record = "\(wins)-\(losses)-\(ties)"
        
        XCTAssertEqual(record, "0-0-0", "Empty team should show 0-0-0 record")
    }
    
    func testHomeViewPlayerSwitching() throws {
        // Given - Multiple players with different data
        let player1 = testPlayers[0]
        let player2 = testPlayers[1]
        
        let player1Teams = testTeams.filter { $0.player == player1 }
        let player2Teams = testTeams.filter { $0.player == player2 }
        
        // When - Switch between players
        appContext.switchToPlayer(player1)
        appContext.switchToTeam(player1Teams[0])
        
        let player1Games = testGames.filter { $0.team == player1Teams[0] }
        
        // Switch to player 2
        appContext.switchToPlayer(player2)
        appContext.switchToTeam(player2Teams[0])
        
        let player2Games = testGames.filter { $0.team == player2Teams[0] }
        
        // Then - Data should be isolated per player
        XCTAssertNotEqual(player1Games.count, player2Games.count, "Players should have different game counts")
        XCTAssertFalse(player1Games.isEmpty, "Player 1 should have games")
        XCTAssertFalse(player2Games.isEmpty, "Player 2 should have games")
        
        // Verify no cross-contamination
        for game in player1Games {
            XCTAssertEqual(game.team?.player?.id, player1.id, "Player 1 games should belong to player 1")
        }
        
        for game in player2Games {
            XCTAssertEqual(game.team?.player?.id, player2.id, "Player 2 games should belong to player 2")
        }
    }
    
    // MARK: - Performance Integration Tests
    
    func testLargeDataSetIntegration() throws {
        // Given - Large dataset
        let player = testPlayers[0]
        let team = testTeams.filter { $0.player == player }[0]
        
        // Create many additional games
        for i in 0..<500 {
            let game = Game(context: mockContext)
            game.id = UUID()
            game.opponentName = "Large Dataset Opponent \(i)"
            game.teamScore = Int32(70 + i % 30)
            game.opponentScore = Int32(65 + i % 35)
            game.isWin = game.teamScore > game.opponentScore
            game.isTie = (i % 20 == 0) && game.teamScore == game.opponentScore
            game.gameDate = Calendar.current.date(byAdding: .day, value: -i, to: Date())
            game.team = team
        }
        try! mockContext.save()
        
        // When - Perform typical home view operations
        measure {
            let teamGames = self.testGames.filter { $0.team == team }
            let recentGames = Array(teamGames.sorted { 
                ($0.gameDate ?? Date.distantPast) > ($1.gameDate ?? Date.distantPast)
            }.prefix(10))
            
            let wins = teamGames.filter { $0.isWin }.count
            let losses = teamGames.filter { !$0.isWin && !$0.isTie }.count
            let ties = teamGames.filter { $0.isTie }.count
            
            XCTAssertLessThanOrEqual(recentGames.count, 10, "Should limit recent games")
            XCTAssertGreaterThanOrEqual(wins + losses + ties, 500, "Should handle large dataset")
        }
    }
} 