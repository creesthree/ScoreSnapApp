//
//  HomeViewModelTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import XCTest
import CoreData
@testable import ScoreSnap

@MainActor
final class HomeViewModelTests: XCTestCase {
    
    var viewModel: HomeViewModel!
    var mockContext: NSManagedObjectContext!
    var testPlayer: Player!
    var testTeam: Team!
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
        viewModel = HomeViewModel(viewContext: mockContext)
        
        // Create test data
        setupTestData()
    }
    
    override func tearDownWithError() throws {
        viewModel = nil
        mockContext = nil
        testPlayer = nil
        testTeam = nil
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
        
        // Create test team
        testTeam = Team(context: mockContext)
        testTeam.id = UUID()
        testTeam.name = "Test Team"
        testTeam.displayOrder = 0
        testTeam.teamColor = "#0000FF"
        testTeam.sport = "Basketball"
        testTeam.player = testPlayer
        
        // Create test games (15 games to test limit)
        for i in 0..<15 {
            let game = Game(context: mockContext)
            game.id = UUID()
            game.opponentName = "Opponent \(i)"
            game.teamScore = Int32(80 + i)
            game.opponentScore = Int32(75 + (i % 3))
            game.isWin = (i % 3 == 0) // Every 3rd game is a win
            game.isTie = (i % 5 == 0 && i % 3 != 0) // Some ties
            game.gameDate = Calendar.current.date(byAdding: .day, value: -i, to: Date())
            game.gameEditDate = Date()
            game.gameEditTime = Date()
            game.team = testTeam
            testGames.append(game)
        }
        
        try! mockContext.save()
    }
    
    // MARK: - Data Management Tests
    
    func testRecentGamesFetching() throws {
        // When
        viewModel.fetchRecentGames(for: testTeam, limit: 12)
        
        // Then
        XCTAssertEqual(viewModel.recentGames.count, 12, "Should fetch exactly 12 most recent games")
        XCTAssertFalse(viewModel.isLoading, "Loading should be false after fetch")
        XCTAssertNil(viewModel.errorMessage, "Should have no error message")
    }
    
    func testGamesSorting() throws {
        // When
        viewModel.fetchRecentGames(for: testTeam)
        
        // Then
        let games = viewModel.recentGames
        for i in 1..<games.count {
            let previousDate = games[i-1].gameDate ?? Date.distantPast
            let currentDate = games[i].gameDate ?? Date.distantPast
            XCTAssertGreaterThanOrEqual(previousDate, currentDate, "Games should be sorted by date (most recent first)")
        }
    }
    
    func testEmptyGamesHandling() throws {
        // Given - Create team with no games
        let emptyTeam = Team(context: mockContext)
        emptyTeam.id = UUID()
        emptyTeam.name = "Empty Team"
        emptyTeam.player = testPlayer
        try! mockContext.save()
        
        // When
        viewModel.fetchRecentGames(for: emptyTeam)
        
        // Then
        XCTAssertTrue(viewModel.recentGames.isEmpty, "Should handle team with no games gracefully")
        XCTAssertFalse(viewModel.isLoading, "Loading should be false")
        XCTAssertNil(viewModel.errorMessage, "Should have no error message")
    }
    
    func testGamesFiltering() throws {
        // Given - Create another team with different games
        let otherTeam = Team(context: mockContext)
        otherTeam.id = UUID()
        otherTeam.name = "Other Team"
        otherTeam.player = testPlayer
        
        let otherGame = Game(context: mockContext)
        otherGame.id = UUID()
        otherGame.opponentName = "Other Opponent"
        otherGame.team = otherTeam
        try! mockContext.save()
        
        // When
        viewModel.fetchRecentGames(for: testTeam)
        
        // Then
        for game in viewModel.recentGames {
            XCTAssertEqual(game.team, testTeam, "Should only show games for the selected team")
        }
    }
    
    func testCoreDataRelationshipLoading() throws {
        // When
        viewModel.fetchRecentGames(for: testTeam)
        
        // Then
        for game in viewModel.recentGames {
            XCTAssertNotNil(game.team, "Game should have team relationship loaded")
            XCTAssertEqual(game.team?.id, testTeam.id, "Game should be related to correct team")
        }
    }
    
    // MARK: - State Management Tests
    
    func testLoadingStates() throws {
        // Given
        XCTAssertFalse(viewModel.isLoading, "Should start with loading false")
        
        // When - Simulate loading
        viewModel.fetchRecentGames(for: testTeam)
        
        // Then
        XCTAssertFalse(viewModel.isLoading, "Loading should be false after synchronous fetch")
    }
    
    func testErrorHandling() throws {
        // When - Pass nil team to trigger error path
        viewModel.fetchRecentGames(for: nil)
        
        // Then
        XCTAssertTrue(viewModel.recentGames.isEmpty, "Should have empty games on error")
        XCTAssertFalse(viewModel.isLoading, "Loading should be false on error")
    }
    
    // MARK: - Game Operations Tests
    
    func testGameDeletion() throws {
        // Given
        viewModel.fetchRecentGames(for: testTeam)
        let initialCount = viewModel.recentGames.count
        let gameToDelete = viewModel.recentGames.first!
        
        // When
        viewModel.deleteGame(gameToDelete)
        
        // Then
        XCTAssertEqual(viewModel.recentGames.count, initialCount - 1, "Should remove game from array")
        XCTAssertFalse(viewModel.recentGames.contains(gameToDelete), "Deleted game should not be in array")
    }
    
    func testTeamRecordCalculation() throws {
        // When
        let record = viewModel.getTeamRecord(for: testTeam)
        
        // Then
        XCTAssertEqual(record.totalGames, testGames.count, "Should count all games")
        XCTAssertGreaterThan(record.wins, 0, "Should have some wins")
        XCTAssertEqual(record.wins + record.losses + record.ties, record.totalGames, "Wins + losses + ties should equal total")
    }
    
    func testDataRefresh() throws {
        // Given
        viewModel.fetchRecentGames(for: testTeam)
        let initialCount = viewModel.recentGames.count
        
        // When - Add new game and refresh
        let newGame = Game(context: mockContext)
        newGame.id = UUID()
        newGame.opponentName = "New Opponent"
        newGame.gameDate = Date()
        newGame.team = testTeam
        try! mockContext.save()
        
        viewModel.refreshData(for: testTeam)
        
        // Then
        XCTAssertEqual(viewModel.recentGames.count, min(initialCount + 1, 10), "Should include new game in refresh")
    }
    
    func testRecentStreak() throws {
        // When
        let streak = viewModel.getRecentStreak(for: testTeam, limit: 5)
        
        // Then
        XCTAssertGreaterThanOrEqual(streak.count, 0, "Streak count should be >= 0")
        XCTAssertTrue([.win, .loss, .tie, .none].contains(streak.type), "Streak type should be valid")
    }
    
    // MARK: - Performance Tests
    
    func testFetchPerformance() throws {
        measure {
            viewModel.fetchRecentGames(for: testTeam, limit: 10)
        }
    }
    
    func testRecordCalculationPerformance() throws {
        measure {
            _ = viewModel.getTeamRecord(for: testTeam)
        }
    }
} 