//
//  Phase2NavigationTests.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import XCTest
import SwiftUI
import CoreData
@testable import ScoreSnap

class Phase2NavigationTests: XCTestCase {
    
    var testContext: NSManagedObjectContext!
    var appContext: AppContext!
    
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
    }
    
    override func tearDown() {
        testContext = nil
        appContext = nil
        super.tearDown()
    }
    
    // MARK: - Tab Navigation Tests
    
    func testTabBarConstants() {
        // Test that all required tab constants are defined
        XCTAssertEqual(Constants.TabBar.homeTitle, "Home")
        XCTAssertEqual(Constants.TabBar.gamesTitle, "Games")
        XCTAssertEqual(Constants.TabBar.playersTitle, "Players")
        
        XCTAssertEqual(Constants.TabBar.homeIcon, "house")
        XCTAssertEqual(Constants.TabBar.gamesIcon, "list.bullet")
        XCTAssertEqual(Constants.TabBar.playersIcon, "person.fill")
        XCTAssertEqual(Constants.TabBar.cameraIcon, "camera.fill")
    }
    
    func testFloatingActionButtonConfiguration() {
        // Test FAB sizing and configuration
        XCTAssertEqual(Constants.UI.floatingActionButtonSize, 56)
        XCTAssertGreaterThan(Constants.UI.floatingActionButtonSize, 0)
        
        // Test that FAB shadow configuration exists
        XCTAssertNotNil(Theme.Shadows.fabShadow.color)
        XCTAssertGreaterThan(Theme.Shadows.fabShadow.radius, 0)
    }
    
    // MARK: - Player Segmented Control Tests
    
    @MainActor
    func testPlayerSegmentedControlSwitching() {
        // Create test players
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        let player3 = createTestPlayer(name: "Player 3", displayOrder: 2)
        
        try! testContext.save()
        
        // Test initial state
        XCTAssertNil(appContext.currentPlayer)
        
        // Test switching to first player
        appContext.switchToPlayer(player1)
        XCTAssertEqual(appContext.currentPlayer, player1)
        XCTAssertEqual(appContext.currentPlayer?.name, "Player 1")
        
        // Test switching to second player
        appContext.switchToPlayer(player2)
        XCTAssertEqual(appContext.currentPlayer, player2)
        XCTAssertEqual(appContext.currentPlayer?.name, "Player 2")
        
        // Test switching to third player
        appContext.switchToPlayer(player3)
        XCTAssertEqual(appContext.currentPlayer, player3)
        XCTAssertEqual(appContext.currentPlayer?.name, "Player 3")
        
        // Test switching back to first player
        appContext.switchToPlayer(player1)
        XCTAssertEqual(appContext.currentPlayer, player1)
        XCTAssertEqual(appContext.currentPlayer?.name, "Player 1")
    }
    
    @MainActor
    func testPlayerSegmentedControlWithTeams() {
        // Create players with teams
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let team1A = createTestTeam(name: "Team 1A", player: player1, displayOrder: 0)
        let team1B = createTestTeam(name: "Team 1B", player: player1, displayOrder: 1)
        
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        let team2A = createTestTeam(name: "Team 2A", player: player2, displayOrder: 0)
        
        try! testContext.save()
        
        // Switch to player 1 - should default to first team
        appContext.switchToPlayer(player1)
        XCTAssertEqual(appContext.currentPlayer, player1)
        XCTAssertEqual(appContext.currentTeam, team1A) // First team by display order
        
        // Switch to player 2 - should switch to their first team
        appContext.switchToPlayer(player2)
        XCTAssertEqual(appContext.currentPlayer, player2)
        XCTAssertEqual(appContext.currentTeam, team2A)
        
        // Switch back to player 1 - should default to their first team again
        appContext.switchToPlayer(player1)
        XCTAssertEqual(appContext.currentPlayer, player1)
        XCTAssertEqual(appContext.currentTeam, team1A)
    }
    
    @MainActor
    func testPlayerSegmentedControlDisplayOrder() {
        // Create players with specific display orders
        let player3 = createTestPlayer(name: "Player C", displayOrder: 2)
        let player1 = createTestPlayer(name: "Player A", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player B", displayOrder: 1)
        
        try! testContext.save()
        
        // Test that fetchFirstPlayer respects display order
        let firstPlayer = appContext.fetchFirstPlayer()
        XCTAssertEqual(firstPlayer, player1) // Should be Player A (displayOrder: 0)
        XCTAssertEqual(firstPlayer?.name, "Player A")
    }
    
    // MARK: - Navigation State Tests
    
    @MainActor
    func testNavigationStateConsistency() {
        // Create test data
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team1 = createTestTeam(name: "Team 1", player: player, displayOrder: 0)
        let team2 = createTestTeam(name: "Team 2", player: player, displayOrder: 1)
        
        try! testContext.save()
        
        // Set initial state
        appContext.switchToPlayerAndTeam(player, team1)
        XCTAssertEqual(appContext.currentPlayer, player)
        XCTAssertEqual(appContext.currentTeam, team1)
        
        // Switch teams while keeping same player
        appContext.switchToTeam(team2)
        XCTAssertEqual(appContext.currentPlayer, player) // Player should remain same
        XCTAssertEqual(appContext.currentTeam, team2)
        
        // Test invalid team switch (team doesn't belong to current player)
        let otherPlayer = createTestPlayer(name: "Other Player", displayOrder: 1)
        let otherTeam = createTestTeam(name: "Other Team", player: otherPlayer, displayOrder: 0)
        try! testContext.save()
        
        appContext.switchToTeam(otherTeam)
        // Should not switch because team doesn't belong to current player
        XCTAssertEqual(appContext.currentPlayer, player)
        XCTAssertEqual(appContext.currentTeam, team2) // Should remain unchanged
    }
    
    @MainActor
    func testSetupWorkflowNavigation() {
        // Test empty state navigation
        XCTAssertTrue(appContext.needsSetup)
        XCTAssertNil(appContext.currentPlayer)
        XCTAssertNil(appContext.currentTeam)
        
        // Complete setup
        let player = createTestPlayer(name: "Setup Player", displayOrder: 0)
        let team = createTestTeam(name: "Setup Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        appContext.completeSetup(with: player, and: team)
        
        XCTAssertFalse(appContext.needsSetup)
        XCTAssertEqual(appContext.currentPlayer, player)
        XCTAssertEqual(appContext.currentTeam, team)
    }
    
    // MARK: - Helper Methods
    
    private func createTestPlayer(name: String, displayOrder: Int32) -> Player {
        let player = Player(context: testContext)
        player.id = UUID()
        player.name = name
        player.displayOrder = displayOrder
        player.sport = Constants.Basketball.defaultSport
        player.playerColor = Constants.Defaults.defaultPlayerColor.rawValue
        return player
    }
    
    private func createTestTeam(name: String, player: Player, displayOrder: Int32) -> Team {
        let team = Team(context: testContext)
        team.id = UUID()
        team.name = name
        team.displayOrder = displayOrder
        team.sport = Constants.Basketball.defaultSport
        team.teamColor = Constants.Defaults.defaultTeamColor.rawValue
        team.player = player
        return team
    }
}

 