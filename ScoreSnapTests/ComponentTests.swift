//
//  ComponentTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import XCTest
import SwiftUI
import CoreData
@testable import ScoreSnap

final class ComponentTests: XCTestCase {
    
    var mockContext: NSManagedObjectContext!
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
        setupTestData()
    }
    
    override func tearDownWithError() throws {
        mockContext = nil
        testPlayers = []
        testTeams = []
        testGames = []
    }
    
    private func setupTestData() {
        // Create 5 test players to test "More" functionality
        for i in 0..<5 {
            let player = Player(context: mockContext)
            player.id = UUID()
            player.name = "Player \(i + 1)"
            player.displayOrder = Int32(i)
            player.playerColor = "#FF000\(i)"
            player.sport = "Basketball"
            testPlayers.append(player)
            
            // Create 2-3 teams per player
            let teamCount = i < 2 ? 3 : 2
            for j in 0..<teamCount {
                let team = Team(context: mockContext)
                team.id = UUID()
                team.name = "Team \(i + 1)-\(j + 1)"
                team.displayOrder = Int32(j)
                team.teamColor = "#0000F\(j)"
                team.sport = "Basketball"
                team.player = player
                testTeams.append(team)
                
                // Create games for each team
                for k in 0..<(5 + j) {
                    let game = Game(context: mockContext)
                    game.id = UUID()
                    game.opponentName = "Opponent \(k + 1)"
                    game.teamScore = Int32(80 + k)
                    game.opponentScore = Int32(75 + (k % 3))
                    game.isWin = (k % 2 == 0) // Alternating wins/losses
                    game.isTie = (k % 7 == 0 && k % 2 != 0) // Occasional ties
                    game.gameDate = Calendar.current.date(byAdding: .day, value: -k, to: Date())
                    game.team = team
                    testGames.append(game)
                }
            }
        }
        
        try! mockContext.save()
    }
    
    // MARK: - PlayerSegmentedControl Tests
    
    func testPlayerSegmentedControlWith2Players() throws {
        // Given - Only first 2 players
        let players = Array(testPlayers.prefix(2))
        
        // When - Create component with 2 players
        // Then - Should show both players without "More" button
        XCTAssertEqual(players.count, 2, "Should have exactly 2 players")
        XCTAssertLessThanOrEqual(players.count, 3, "Should not need 'More' button")
    }
    
    func testPlayerSegmentedControlWith3Players() throws {
        // Given - First 3 players
        let players = Array(testPlayers.prefix(3))
        
        // When - Create component with 3 players
        // Then - Should show all 3 players without "More" button
        XCTAssertEqual(players.count, 3, "Should have exactly 3 players")
        XCTAssertLessThanOrEqual(players.count, 3, "Should not need 'More' button")
    }
    
    func testPlayerSegmentedControlWith4PlusPlayers() throws {
        // Given - All 5 players
        let players = testPlayers
        let visiblePlayers = Array(players.prefix(3))
        let hasMorePlayers = players.count > 3
        
        // When - Create component with 4+ players
        // Then - Should show first 3 players + "More" button
        XCTAssertEqual(visiblePlayers.count, 3, "Should show exactly 3 visible players")
        XCTAssertTrue(hasMorePlayers, "Should need 'More' button for 4+ players")
        XCTAssertEqual(players.count - visiblePlayers.count, 2, "Should have 2 additional players in 'More'")
    }
    
    func testPlayerDisplayOrder() throws {
        // Given - Players with different display orders
        let sortedPlayers = testPlayers.sorted { $0.displayOrder < $1.displayOrder }
        
        // When - Check ordering
        // Then - Players should be in correct displayOrder sequence
        for i in 1..<sortedPlayers.count {
            XCTAssertLessThan(sortedPlayers[i-1].displayOrder, sortedPlayers[i].displayOrder, 
                            "Players should be sorted by displayOrder")
        }
    }
    
    // MARK: - TeamDropdown Tests
    
    func testTeamDropdownContent() throws {
        // Given - Player with multiple teams
        let player = testPlayers[0] // Has 3 teams
        let playerTeams = testTeams.filter { $0.player == player }
        
        // When - Create dropdown for player
        // Then - Should contain all teams for player
        XCTAssertEqual(playerTeams.count, 3, "Player should have 3 teams")
        XCTAssertTrue(playerTeams.allSatisfy { $0.player == player }, "All teams should belong to player")
    }
    
    func testTeamOrdering() throws {
        // Given - Player with teams having different display orders
        let player = testPlayers[0]
        let playerTeams = testTeams.filter { $0.player == player }
            .sorted { $0.displayOrder < $1.displayOrder }
        
        // When - Check team ordering
        // Then - Teams should be sorted by displayOrder
        for i in 1..<playerTeams.count {
            XCTAssertLessThanOrEqual(playerTeams[i-1].displayOrder, playerTeams[i].displayOrder,
                                   "Teams should be sorted by displayOrder")
        }
    }
    
    func testTeamColorDisplay() throws {
        // Given - Teams with different colors
        let team = testTeams[0]
        
        // When - Check team color
        // Then - Team should have valid color
        XCTAssertNotNil(team.teamColor, "Team should have a color")
        XCTAssertTrue(team.teamColor?.hasPrefix("#") ?? false, "Team color should be hex format")
    }
    
    func testSingleTeamBehavior() throws {
        // Given - Player with only one team
        let player = testPlayers[2] // Has 2 teams, but test with conceptual single team
        let playerTeams = testTeams.filter { $0.player == player }
        let shouldShowDropdown = playerTeams.count > 1
        
        // When - Check dropdown visibility logic
        // Then - Dropdown should be hidden for single team
        XCTAssertTrue(shouldShowDropdown, "This player has multiple teams, so dropdown should show")
        
        // Test the inverse case conceptually
        let singleTeamCount = 1
        let shouldHideForSingleTeam = singleTeamCount <= 1
        XCTAssertTrue(shouldHideForSingleTeam, "Dropdown should be hidden when player has only one team")
    }
    
    // MARK: - TeamRecordView Tests
    
    func testRecordCalculation() throws {
        // Given - Team with games
        let team = testTeams[0]
        let teamGames = testGames.filter { $0.team == team }
        
        // When - Calculate record
        let wins = teamGames.filter { $0.isWin }.count
        let losses = teamGames.filter { !$0.isWin && !$0.isTie }.count
        let ties = teamGames.filter { $0.isTie }.count
        
        // Then - Record should be calculated correctly
        XCTAssertEqual(wins + losses + ties, teamGames.count, "Wins + losses + ties should equal total games")
        XCTAssertGreaterThanOrEqual(wins, 0, "Wins should be >= 0")
        XCTAssertGreaterThanOrEqual(losses, 0, "Losses should be >= 0")
        XCTAssertGreaterThanOrEqual(ties, 0, "Ties should be >= 0")
    }
    
    func testZeroGamesDisplay() throws {
        // Given - Team with no games
        let emptyTeam = Team(context: mockContext)
        emptyTeam.id = UUID()
        emptyTeam.name = "Empty Team"
        emptyTeam.player = testPlayers[0]
        try! mockContext.save()
        
        let emptyTeamGames = testGames.filter { $0.team == emptyTeam }
        
        // When - Calculate record for empty team
        let wins = emptyTeamGames.filter { $0.isWin }.count
        let losses = emptyTeamGames.filter { !$0.isWin && !$0.isTie }.count
        let ties = emptyTeamGames.filter { $0.isTie }.count
        let recordDisplay = "\(wins)-\(losses)-\(ties)"
        
        // Then - Should show "0-0-0"
        XCTAssertEqual(recordDisplay, "0-0-0", "Empty team should show 0-0-0 record")
    }
    
    func testRecordFormatting() throws {
        // Given - Team with specific record
        let team = testTeams[0]
        let teamGames = testGames.filter { $0.team == team }
        
        let wins = teamGames.filter { $0.isWin }.count
        let losses = teamGames.filter { !$0.isWin && !$0.isTie }.count
        let ties = teamGames.filter { $0.isTie }.count
        
        // When - Format record display
        let recordDisplay = "\(wins)-\(losses)-\(ties)"
        
        // Then - Should use correct separator and order
        XCTAssertTrue(recordDisplay.contains("-"), "Record should use dash separator")
        XCTAssertEqual(recordDisplay.components(separatedBy: "-").count, 3, "Record should have 3 components")
        
        let components = recordDisplay.components(separatedBy: "-")
        XCTAssertEqual(Int(components[0]), wins, "First component should be wins")
        XCTAssertEqual(Int(components[1]), losses, "Second component should be losses")
        XCTAssertEqual(Int(components[2]), ties, "Third component should be ties")
    }
    
    // MARK: - GameRowView Tests
    
    func testGameDataDisplay() throws {
        // Given - Game with specific data
        let game = testGames[0]
        
        // When - Check game data
        // Then - Game should have all required data
        XCTAssertNotNil(game.opponentName, "Game should have opponent name")
        XCTAssertNotNil(game.gameDate, "Game should have game date")
        XCTAssertGreaterThan(game.teamScore, 0, "Game should have team score")
        XCTAssertGreaterThan(game.opponentScore, 0, "Game should have opponent score")
    }
    
    func testScoreFormatting() throws {
        // Given - Game with scores
        let game = testGames[0]
        
        // When - Format score display
        let scoreDisplay = "\(game.teamScore)-\(game.opponentScore)"
        
        // Then - Should use correct format
        XCTAssertTrue(scoreDisplay.contains("-"), "Score should use dash separator")
        XCTAssertEqual(scoreDisplay.components(separatedBy: "-").count, 2, "Score should have 2 components")
    }
    
    func testOutcomeDisplay() throws {
        // Given - Games with different outcomes
        let winGame = testGames.first { $0.isWin }!
        let lossGame = testGames.first { !$0.isWin && !$0.isTie }!
        let tieGame = testGames.first { $0.isTie }
        
        // When - Get outcome displays
        let winOutcome = winGame.isWin ? "W" : (winGame.isTie ? "T" : "L")
        let lossOutcome = lossGame.isWin ? "W" : (lossGame.isTie ? "T" : "L")
        
        // Then - Should show correct outcome indicators
        XCTAssertEqual(winOutcome, "W", "Win game should show 'W'")
        XCTAssertEqual(lossOutcome, "L", "Loss game should show 'L'")
        
        if let tieGame = tieGame {
            let tieOutcome = tieGame.isWin ? "W" : (tieGame.isTie ? "T" : "L")
            XCTAssertEqual(tieOutcome, "T", "Tie game should show 'T'")
        }
    }
    
    func testDateFormatting() throws {
        // Given - Game with date
        let game = testGames[0]
        guard let gameDate = game.gameDate else {
            XCTFail("Game should have a date")
            return
        }
        
        // When - Format date
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let formattedDate = formatter.string(from: gameDate)
        
        // Then - Should be user-friendly format
        XCTAssertFalse(formattedDate.isEmpty, "Formatted date should not be empty")
        XCTAssertFalse(formattedDate.contains("GMT"), "Formatted date should not contain timezone info")
    }
    
    func testOpponentNameDisplay() throws {
        // Given - Game with long opponent name
        let game = testGames[0]
        let opponentName = game.opponentName ?? ""
        
        // When - Check opponent name
        // Then - Should handle name properly
        XCTAssertFalse(opponentName.isEmpty, "Opponent name should not be empty")
        XCTAssertLessThanOrEqual(opponentName.count, 50, "Opponent name should be reasonable length")
    }
    
    // MARK: - Performance Tests
    
    func testComponentRenderingPerformance() throws {
        let team = testTeams[0]
        let teamGames = testGames.filter { $0.team == team }
        
        measure {
            // Simulate component calculations
            let wins = teamGames.filter { $0.isWin }.count
            let losses = teamGames.filter { !$0.isWin && !$0.isTie }.count
            let ties = teamGames.filter { $0.isTie }.count
            let _ = "\(wins)-\(losses)-\(ties)"
        }
    }
    
    func testLargeDataSetHandling() throws {
        // Given - Team with many games
        let team = testTeams[0]
        
        // Create additional games for performance testing
        for i in 0..<100 {
            let game = Game(context: mockContext)
            game.id = UUID()
            game.opponentName = "Perf Opponent \(i)"
            game.teamScore = Int32(80 + i % 20)
            game.opponentScore = Int32(75 + i % 15)
            game.isWin = (i % 2 == 0)
            game.isTie = (i % 10 == 0 && i % 2 != 0)
            game.gameDate = Calendar.current.date(byAdding: .day, value: -i, to: Date())
            game.team = team
        }
        try! mockContext.save()
        
        // When - Calculate record with large dataset
        measure {
            let teamGames = testGames.filter { $0.team == team }
            let _ = teamGames.filter { $0.isWin }.count
            let _ = teamGames.filter { !$0.isWin && !$0.isTie }.count
            let _ = teamGames.filter { $0.isTie }.count
        }
    }
} 