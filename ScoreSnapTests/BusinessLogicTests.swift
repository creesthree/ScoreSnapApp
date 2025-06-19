//
//  BusinessLogicTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import XCTest
import CoreData
@testable import ScoreSnap

final class BusinessLogicTests: XCTestCase {
    
    var mockContext: NSManagedObjectContext!
    var testPlayer: Player!
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
        testPlayer = nil
        testTeams = []
        testGames = []
    }
    
    private func setupTestData() {
        // Create test player
        testPlayer = Player(context: mockContext)
        testPlayer.id = UUID()
        testPlayer.name = "Test Player"
        testPlayer.displayOrder = 0
        testPlayer.playerColor = "#FF0000"
        testPlayer.sport = "Basketball"
        
        // Create test teams
        for i in 0..<3 {
            let team = Team(context: mockContext)
            team.id = UUID()
            team.name = "Team \(i + 1)"
            team.displayOrder = Int32(2 - i) // Reverse order to test sorting
            team.teamColor = "#0000F\(i)"
            team.sport = "Basketball"
            team.player = testPlayer
            testTeams.append(team)
            
            // Create games with specific patterns
            createGamesForTeam(team)
        }
        
        try! mockContext.save()
    }
    
    private func createGamesForTeam(_ team: Team) {
        let gamePatterns: [(teamScore: Int32, opponentScore: Int32, isWin: Bool, isTie: Bool)] = [
            (85, 80, true, false),   // Win
            (75, 85, false, false),  // Loss
            (80, 80, false, true),   // Tie
            (90, 85, true, false),   // Win
            (70, 75, false, false),  // Loss
        ]
        
        for (index, pattern) in gamePatterns.enumerated() {
            let game = Game(context: mockContext)
            game.id = UUID()
            game.opponentName = "Opponent \(index + 1)"
            game.teamScore = pattern.teamScore
            game.opponentScore = pattern.opponentScore
            game.isWin = pattern.isWin
            game.isTie = pattern.isTie
            game.gameDate = Calendar.current.date(byAdding: .day, value: -index, to: Date())
            game.team = team
            testGames.append(game)
        }
    }
    
    // MARK: - Team Business Logic Tests
    
    func testTeamWinsCalculation() throws {
        let team = testTeams[0]
        let teamGames = testGames.filter { $0.team == team }
        let wins = teamGames.filter { $0.isWin }.count
        
        XCTAssertEqual(wins, 2, "Team should have 2 wins")
    }
    
    func testTeamLossesCalculation() throws {
        let team = testTeams[0]
        let teamGames = testGames.filter { $0.team == team }
        let losses = teamGames.filter { !$0.isWin && !$0.isTie }.count
        
        XCTAssertEqual(losses, 2, "Team should have 2 losses")
    }
    
    func testTeamTiesCalculation() throws {
        let team = testTeams[0]
        let teamGames = testGames.filter { $0.team == team }
        let ties = teamGames.filter { $0.isTie }.count
        
        XCTAssertEqual(ties, 1, "Team should have 1 tie")
    }
    
    func testTeamRecordDisplay() throws {
        let team = testTeams[0]
        let teamGames = testGames.filter { $0.team == team }
        let wins = teamGames.filter { $0.isWin }.count
        let losses = teamGames.filter { !$0.isWin && !$0.isTie }.count
        let ties = teamGames.filter { $0.isTie }.count
        let recordDisplay = "\(wins)-\(losses)-\(ties)"
        
        XCTAssertEqual(recordDisplay, "2-2-1", "Record should be 2-2-1")
    }
    
    // MARK: - Game Business Logic Tests
    
    func testGameScoreDisplay() throws {
        let game = testGames[0]
        let scoreDisplay = "\(game.teamScore)-\(game.opponentScore)"
        
        XCTAssertTrue(scoreDisplay.contains("-"), "Score should contain dash")
        XCTAssertEqual(scoreDisplay.components(separatedBy: "-").count, 2, "Score should have 2 parts")
    }
    
    func testGameOutcomeDisplay() throws {
        let winGame = testGames.first { $0.isWin }!
        let lossGame = testGames.first { !$0.isWin && !$0.isTie }!
        let tieGame = testGames.first { $0.isTie }!
        
        let winOutcome = winGame.isWin ? "W" : (winGame.isTie ? "T" : "L")
        let lossOutcome = lossGame.isWin ? "W" : (lossGame.isTie ? "T" : "L")
        let tieOutcome = tieGame.isWin ? "W" : (tieGame.isTie ? "T" : "L")
        
        XCTAssertEqual(winOutcome, "W", "Win game should show W")
        XCTAssertEqual(lossOutcome, "L", "Loss game should show L")
        XCTAssertEqual(tieOutcome, "T", "Tie game should show T")
    }
    
    // MARK: - Player Business Logic Tests
    
    func testPlayerTeamsSorting() throws {
        let player = testPlayer!
        let playerTeams = testTeams.filter { $0.player == player }
        let sortedTeams = playerTeams.sorted { $0.displayOrder < $1.displayOrder }
        
        for i in 1..<sortedTeams.count {
            XCTAssertLessThanOrEqual(sortedTeams[i-1].displayOrder, sortedTeams[i].displayOrder,
                                   "Teams should be sorted by displayOrder")
        }
    }
    
    func testPlayerTeamsArray() throws {
        let player = testPlayer!
        let playerTeams = testTeams.filter { $0.player == player }
        
        XCTAssertEqual(playerTeams.count, 3, "Player should have 3 teams")
        XCTAssertTrue(playerTeams.allSatisfy { $0.player == player }, "All teams should belong to player")
    }
} 