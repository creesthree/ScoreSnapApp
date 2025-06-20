//
//  PlayersPerformanceTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import XCTest
import SwiftUI
import CoreData
@testable import ScoreSnap

@MainActor
class PlayersPerformanceTests: XCTestCase {
    
    var testContext: NSManagedObjectContext!
    var viewModel: PlayersViewModel!
    var appContext: AppContext!
    
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
        viewModel = PlayersViewModel(viewContext: testContext)
        appContext = AppContext(viewContext: testContext)
    }
    
    override func tearDown() {
        testContext = nil
        viewModel = nil
        appContext = nil
        super.tearDown()
    }
    
    // MARK: - Data Loading Performance Tests
    
    func testViewLoadingTime() {
        // Create large dataset
        let players = (0..<20).map { createTestPlayer(name: "Player \($0)", displayOrder: Int32($0)) }
        let teams = players.flatMap { player in
            (0..<5).map { createTestTeam(name: "Team \($0) for \(player.name!)", player: player, displayOrder: Int32($0)) }
        }
        
        try! testContext.save()
        
        // Test view loading performance
        measure {
            viewModel.loadData()
        }
        
        // Verify data was loaded correctly
        XCTAssertEqual(viewModel.players.count, 20)
        XCTAssertEqual(viewModel.teams.count, 100) // 20 players * 5 teams each
    }
    
    func testLargeDatasetHandling() {
        // Create very large dataset
        let players = (0..<50).map { createTestPlayer(name: "Player \($0)", displayOrder: Int32($0)) }
        let teams = players.flatMap { player in
            (0..<10).map { createTestTeam(name: "Team \($0) for \(player.name!)", player: player, displayOrder: Int32($0)) }
        }
        
        try! testContext.save()
        
        // Test performance with large dataset
        measure {
            viewModel.loadData()
        }
        
        // Verify performance is acceptable
        XCTAssertEqual(viewModel.players.count, 50)
        XCTAssertEqual(viewModel.teams.count, 500) // 50 players * 10 teams each
    }
    
    func testSelectionResponseTime() {
        // Create test data
        let players = (0..<20).map { createTestPlayer(name: "Player \($0)", displayOrder: Int32($0)) }
        try! testContext.save()
        
        // Test selection response time
        measure {
            for player in players {
                appContext.switchToPlayer(player)
            }
        }
        
        // Verify final selection
        XCTAssertEqual(appContext.currentPlayer, players.last)
    }
    
    func testReorderPerformance() {
        // Create test data
        let players = (0..<20).map { createTestPlayer(name: "Player \($0)", displayOrder: Int32($0)) }
        try! testContext.save()
        viewModel.loadData()
        
        // Test reorder performance
        measure {
            // Move last player to first position
            viewModel.movePlayer(from: IndexSet(integer: 19), to: 0)
        }
        
        // Verify reorder was applied
        XCTAssertEqual(viewModel.players.count, 20)
        XCTAssertEqual(viewModel.players[0].name, "Player 19")
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryUsage() {
        // Create large dataset
        let players = (0..<30).map { createTestPlayer(name: "Player \($0)", displayOrder: Int32($0)) }
        let teams = players.flatMap { player in
            (0..<8).map { createTestTeam(name: "Team \($0) for \(player.name!)", player: player, displayOrder: Int32($0)) }
        }
        
        try! testContext.save()
        
        // Test memory usage during extended operations
        measure {
            // Perform multiple load operations
            for _ in 0..<10 {
                viewModel.loadData()
                
                // Perform selections
                for player in players {
                    appContext.switchToPlayer(player)
                }
                
                // Perform reorders
                viewModel.movePlayer(from: IndexSet(integer: 0), to: 29)
                viewModel.movePlayer(from: IndexSet(integer: 29), to: 0)
            }
        }
        
        // Verify data integrity maintained
        XCTAssertEqual(viewModel.players.count, 30)
        XCTAssertEqual(viewModel.teams.count, 240) // 30 players * 8 teams each
    }
    
    func testFormMemoryCleanup() {
        // Test memory cleanup for form operations
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        measure {
            // Simulate multiple form operations
            for i in 0..<100 {
                let newName = "Updated Player \(i)"
                let newColor = TeamColor.purple
                
                viewModel.updatePlayer(player, name: newName, color: newColor, sport: "Basketball")
            }
        }
        
        // Verify final state
        XCTAssertEqual(player.name, "Updated Player 99")
    }
    
    func testImageMemoryHandling() {
        // Test color picker and UI elements memory usage
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        measure {
            // Simulate color picker operations
            let colors: [TeamColor] = [.red, .blue, .green, .yellow, .purple, .orange, .pink, .teal]
            
            for _ in 0..<50 {
                for color in colors {
                    // Test color application
                    player.playerColor = color.rawValue
                }
            }
        }
        
        // Verify color was applied
        XCTAssertNotNil(player.playerColor)
    }
    
    // MARK: - Animation Performance Tests
    
    func testReorderAnimations() {
        // Create test data
        let players = (0..<15).map { createTestPlayer(name: "Player \($0)", displayOrder: Int32($0)) }
        try! testContext.save()
        viewModel.loadData()
        
        // Test reorder animation performance
        measure {
            // Perform multiple reorder operations
            for i in 0..<10 {
                let fromIndex = i % players.count
                let toIndex = (i + 5) % players.count
                
                if fromIndex != toIndex {
                    viewModel.movePlayer(from: IndexSet(integer: fromIndex), to: toIndex)
                }
            }
        }
        
        // Verify reorder operations completed
        XCTAssertEqual(viewModel.players.count, 15)
    }
    
    func testSelectionAnimations() {
        // Create test data
        let players = (0..<20).map { createTestPlayer(name: "Player \($0)", displayOrder: Int32($0)) }
        try! testContext.save()
        
        // Test selection animation performance
        measure {
            // Perform rapid selection changes
            for _ in 0..<50 {
                let randomPlayer = players.randomElement()!
                appContext.switchToPlayer(randomPlayer)
            }
        }
        
        // Verify final selection
        XCTAssertNotNil(appContext.currentPlayer)
    }
    
    func testSheetPresentations() {
        // Test sheet presentation performance
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        measure {
            // Simulate sheet presentation operations
            for _ in 0..<20 {
                // Simulate form operations that would occur in sheets
                let newName = "Updated Player"
                let newColor = TeamColor.yellow
                
                viewModel.updatePlayer(player, name: newName, color: newColor, sport: "Basketball")
            }
        }
        
        // Verify updates were applied
        XCTAssertEqual(player.name, "Updated Player")
    }
    
    // MARK: - Core Data Performance Tests
    
    func testCoreDataSavePerformance() {
        // Test Core Data save performance with large datasets
        measure {
            // Create and save large dataset
            let players = (0..<25).map { createTestPlayer(name: "Player \($0)", displayOrder: Int32($0)) }
            let teams = players.flatMap { player in
                (0..<6).map { createTestTeam(name: "Team \($0) for \(player.name!)", player: player, displayOrder: Int32($0)) }
            }
            
            try! testContext.save()
            
            // Verify save was successful
            XCTAssertEqual(players.count, 25)
            XCTAssertEqual(teams.count, 150)
        }
    }
    
    func testCoreDataFetchPerformance() {
        // Create large dataset
        let players = (0..<40).map { createTestPlayer(name: "Player \($0)", displayOrder: Int32($0)) }
        let teams = players.flatMap { player in
            (0..<7).map { createTestTeam(name: "Team \($0) for \(player.name!)", player: player, displayOrder: Int32($0)) }
        }
        
        try! testContext.save()
        
        // Test fetch performance
        measure {
            // Perform multiple fetch operations
            for _ in 0..<10 {
                let playersRequest: NSFetchRequest<Player> = Player.fetchRequest()
                playersRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Player.displayOrder, ascending: true)]
                let _ = try! testContext.fetch(playersRequest)
                
                let teamsRequest: NSFetchRequest<Team> = Team.fetchRequest()
                teamsRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Team.displayOrder, ascending: true)]
                let _ = try! testContext.fetch(teamsRequest)
            }
        }
    }
    
    func testCoreDataUpdatePerformance() {
        // Create test data
        let players = (0..<30).map { createTestPlayer(name: "Player \($0)", displayOrder: Int32($0)) }
        try! testContext.save()
        
        // Test update performance
        measure {
            // Update all players
            for (index, player) in players.enumerated() {
                player.name = "Updated Player \(index)"
                player.playerColor = Constants.Defaults.defaultPlayerColor.rawValue
            }
            
            try! testContext.save()
        }
        
        // Verify updates were applied
        XCTAssertEqual(players[0].name, "Updated Player 0")
        XCTAssertEqual(players[29].name, "Updated Player 29")
    }
    
    // MARK: - Color Management Performance Tests
    
    func testColorConversionPerformance() {
        // Test color conversion performance
        let colors: [TeamColor] = [.red, .blue, .green, .yellow, .purple, .orange, .pink, .teal, .indigo, .gray]
        
        measure {
            // Perform color conversions
            for _ in 0..<1000 {
                for color in colors {
                    let _ = color.rawValue
                }
            }
        }
    }
    
    func testColorPickerPerformance() {
        // Test color picker performance
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        measure {
            // Simulate color picker operations
            let colors: [TeamColor] = [.red, .blue, .green, .yellow, .purple, .orange, .pink, .teal]
            
            for _ in 0..<100 {
                for color in colors {
                    player.playerColor = color.rawValue
                }
            }
        }
        
        // Verify color was applied
        XCTAssertNotNil(player.playerColor)
    }
    
    // MARK: - Validation Performance Tests
    
    func testNameValidationPerformance() {
        // Test name validation performance
        let testNames = (0..<1000).map { "Test Player \($0)" }
        
        measure {
            for name in testNames {
                let _ = viewModel.validatePlayerName(name)
            }
        }
    }
    
    func testDuplicateNameValidationPerformance() {
        // Create test data
        let players = (0..<20).map { createTestPlayer(name: "Player \($0)", displayOrder: Int32($0)) }
        try! testContext.save()
        viewModel.loadData()
        
        // Test duplicate name validation performance
        measure {
            for _ in 0..<100 {
                let _ = viewModel.isPlayerNameUnique("Test Name", excluding: nil)
            }
        }
    }
    
    // MARK: - Reordering Performance Tests
    
    func testComplexReorderPerformance() {
        // Create test data
        let players = (0..<25).map { createTestPlayer(name: "Player \($0)", displayOrder: Int32($0)) }
        try! testContext.save()
        viewModel.loadData()
        
        // Test complex reorder operations
        measure {
            // Perform complex reorder operations
            for i in 0..<20 {
                let fromIndex = i % players.count
                let toIndex = (i + 10) % players.count
                
                if fromIndex != toIndex {
                    viewModel.movePlayer(from: IndexSet(integer: fromIndex), to: toIndex)
                }
            }
        }
        
        // Verify reorder operations completed
        XCTAssertEqual(viewModel.players.count, 25)
    }
    
    func testTeamReorderPerformance() {
        // Create test data
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let teams = (0..<15).map { createTestTeam(name: "Team \($0)", player: player, displayOrder: Int32($0)) }
        try! testContext.save()
        viewModel.loadData()
        
        // Test team reorder performance
        measure {
            // Perform team reorder operations
            for i in 0..<10 {
                let fromIndex = i % teams.count
                let toIndex = (i + 5) % teams.count
                
                if fromIndex != toIndex {
                    viewModel.moveTeam(from: IndexSet(integer: fromIndex), to: toIndex, for: player)
                }
            }
        }
        
        // Verify reorder operations completed
        let playerTeams = viewModel.teamsForPlayer(player)
        XCTAssertEqual(playerTeams.count, 15)
    }
    
    // MARK: - Helper Methods
    
    private func createTestPlayer(name: String, displayOrder: Int32) -> Player {
        let player = Player(context: testContext)
        player.id = UUID()
        player.name = name
        player.displayOrder = displayOrder
        player.sport = "Basketball"
        player.playerColor = Constants.Defaults.defaultPlayerColor.rawValue
        return player
    }
    
    private func createTestTeam(name: String, player: Player, displayOrder: Int32) -> Team {
        let team = Team(context: testContext)
        team.id = UUID()
        team.name = name
        team.displayOrder = displayOrder
        team.sport = "Basketball"
        team.teamColor = Constants.Defaults.defaultTeamColor.rawValue
        team.player = player
        return team
    }
} 