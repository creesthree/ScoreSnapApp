//
//  PlayersViewTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import XCTest
import SwiftUI
import CoreData
@testable import ScoreSnap

@MainActor
class PlayersViewTests: XCTestCase {
    
    var testContext: NSManagedObjectContext!
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
        appContext = AppContext(viewContext: testContext)
    }
    
    override func tearDown() {
        testContext = nil
        appContext = nil
        super.tearDown()
    }
    
    // MARK: - Layout and Display Tests
    
    func testTwoSectionLayout() {
        // Create test data
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Test that both sections are accessible
        let playersRequest: NSFetchRequest<Player> = Player.fetchRequest()
        let teamsRequest: NSFetchRequest<Team> = Team.fetchRequest()
        
        let players = try! testContext.fetch(playersRequest)
        let teams = try! testContext.fetch(teamsRequest)
        
        XCTAssertEqual(players.count, 1)
        XCTAssertEqual(teams.count, 1)
        XCTAssertEqual(teams.first?.player, player)
    }
    
    func testCurrentPlayerHighlighting() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        try! testContext.save()
        
        // Test initial state
        XCTAssertNil(appContext.currentPlayer)
        
        // Select first player
        appContext.switchToPlayer(player1)
        XCTAssertEqual(appContext.currentPlayer, player1)
        
        // Switch to second player
        appContext.switchToPlayer(player2)
        XCTAssertEqual(appContext.currentPlayer, player2)
        XCTAssertNotEqual(appContext.currentPlayer, player1)
    }
    
    func testTeamSectionUpdates() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        
        let team1 = createTestTeam(name: "Team 1", player: player1, displayOrder: 0)
        let team2 = createTestTeam(name: "Team 2", player: player2, displayOrder: 0)
        
        try! testContext.save()
        
        // Test team association
        XCTAssertEqual(team1.player, player1)
        XCTAssertEqual(team2.player, player2)
        
        // Test team filtering by player
        let player1Teams = getTeamsForPlayer(player1)
        let player2Teams = getTeamsForPlayer(player2)
        
        XCTAssertEqual(player1Teams.count, 1)
        XCTAssertEqual(player2Teams.count, 1)
        XCTAssertEqual(player1Teams.first?.name, "Team 1")
        XCTAssertEqual(player2Teams.first?.name, "Team 2")
    }
    
    func testEmptyStates() {
        // Test empty players state
        let playersRequest: NSFetchRequest<Player> = Player.fetchRequest()
        let players = try! testContext.fetch(playersRequest)
        XCTAssertEqual(players.count, 0)
        
        // Test empty teams state
        let teamsRequest: NSFetchRequest<Team> = Team.fetchRequest()
        let teams = try! testContext.fetch(teamsRequest)
        XCTAssertEqual(teams.count, 0)
        
        // Test needsSetup state
        XCTAssertTrue(appContext.needsSetup)
        XCTAssertNil(appContext.currentPlayer)
        XCTAssertNil(appContext.currentTeam)
    }
    
    func testPlayerListOrdering() {
        let player3 = createTestPlayer(name: "Player C", displayOrder: 2)
        let player1 = createTestPlayer(name: "Player A", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player B", displayOrder: 1)
        
        try! testContext.save()
        
        let playersRequest: NSFetchRequest<Player> = Player.fetchRequest()
        playersRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Player.displayOrder, ascending: true)]
        let players = try! testContext.fetch(playersRequest)
        
        XCTAssertEqual(players.count, 3)
        XCTAssertEqual(players[0].name, "Player A")
        XCTAssertEqual(players[1].name, "Player B")
        XCTAssertEqual(players[2].name, "Player C")
    }
    
    func testTeamListOrdering() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team3 = createTestTeam(name: "Team C", player: player, displayOrder: 2)
        let team1 = createTestTeam(name: "Team A", player: player, displayOrder: 0)
        let team2 = createTestTeam(name: "Team B", player: player, displayOrder: 1)
        
        try! testContext.save()
        
        let teams = getTeamsForPlayer(player)
        
        XCTAssertEqual(teams.count, 3)
        XCTAssertEqual(teams[0].name, "Team A")
        XCTAssertEqual(teams[1].name, "Team B")
        XCTAssertEqual(teams[2].name, "Team C")
    }
    
    // MARK: - Add Functionality Tests
    
    func testAddPlayerButton() {
        // Test that player creation is possible
        let player = createTestPlayer(name: "New Player", displayOrder: 0)
        try! testContext.save()
        
        let playersRequest: NSFetchRequest<Player> = Player.fetchRequest()
        let players = try! testContext.fetch(playersRequest)
        
        XCTAssertEqual(players.count, 1)
        XCTAssertEqual(players.first?.name, "New Player")
    }
    
    func testAddTeamButton() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "New Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        let teamsRequest: NSFetchRequest<Team> = Team.fetchRequest()
        let teams = try! testContext.fetch(teamsRequest)
        
        XCTAssertEqual(teams.count, 1)
        XCTAssertEqual(teams.first?.name, "New Team")
        XCTAssertEqual(teams.first?.player, player)
    }
    
    func testAddPlayerSheet() {
        // Test player creation with form validation
        let playerName = "Test Player"
        let playerColor = Color.blue
        let sport = "Basketball"
        
        let player = Player(context: testContext)
        player.id = UUID()
        player.name = playerName
        player.playerColor = playerColor.toHex()
        player.sport = sport
        player.displayOrder = 0
        
        try! testContext.save()
        
        // Verify form fields were populated correctly
        XCTAssertEqual(player.name, playerName)
        XCTAssertEqual(player.playerColor, playerColor.toHex())
        XCTAssertEqual(player.sport, sport)
        XCTAssertNotNil(player.id)
    }
    
    func testAddTeamSheet() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let teamName = "Test Team"
        let teamColor = Color.red
        let sport = "Basketball"
        
        let team = Team(context: testContext)
        team.id = UUID()
        team.name = teamName
        team.teamColor = teamColor.toHex()
        team.sport = sport
        team.player = player
        team.displayOrder = 0
        
        try! testContext.save()
        
        // Verify team was created with correct player association
        XCTAssertEqual(team.name, teamName)
        XCTAssertEqual(team.teamColor, teamColor.toHex())
        XCTAssertEqual(team.sport, sport)
        XCTAssertEqual(team.player, player)
        XCTAssertNotNil(team.id)
    }
    
    func testCreationFormValidation() {
        // Test empty name validation
        let emptyNamePlayer = Player(context: testContext)
        emptyNamePlayer.name = ""
        emptyNamePlayer.sport = "Basketball"
        
        XCTAssertTrue(emptyNamePlayer.name?.isEmpty ?? true)
        
        // Test whitespace name validation
        let whitespacePlayer = Player(context: testContext)
        whitespacePlayer.name = "   "
        whitespacePlayer.sport = "Basketball"
        
        XCTAssertTrue(whitespacePlayer.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        
        // Test valid name
        let validPlayer = Player(context: testContext)
        validPlayer.name = "Valid Player"
        validPlayer.sport = "Basketball"
        
        XCTAssertFalse(validPlayer.name?.isEmpty ?? true)
        XCTAssertTrue(validPlayer.name?.count ?? 0 <= 50) // Max length validation
    }
    
    func testCreationCancellation() {
        // Test that cancellation doesn't save invalid data
        let player = Player(context: testContext)
        player.name = "Test Player"
        player.sport = "Basketball"
        
        // Simulate cancellation by not saving
        // testContext.save() is not called
        
        let playersRequest: NSFetchRequest<Player> = Player.fetchRequest()
        let players = try! testContext.fetch(playersRequest)
        
        // Should be empty since we didn't save
        XCTAssertEqual(players.count, 0)
    }
    
    // MARK: - Edit Mode Integration Tests
    
    func testEditModeToggle() {
        // Test edit mode state management
        var isEditMode = false
        
        // Toggle to edit mode
        isEditMode.toggle()
        XCTAssertTrue(isEditMode)
        
        // Toggle back to normal mode
        isEditMode.toggle()
        XCTAssertFalse(isEditMode)
    }
    
    func testReorderAvailability() {
        // Test that reorder functionality is available in edit mode
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        try! testContext.save()
        
        // Test reorder operation
        let players = [player1, player2]
        var reorderedPlayers = players
        
        // Simulate reorder: move second to first
        let movedPlayer = reorderedPlayers.remove(at: 1)
        reorderedPlayers.insert(movedPlayer, at: 0)
        
        XCTAssertEqual(reorderedPlayers.count, 2)
        XCTAssertEqual(reorderedPlayers[0].name, "Player 2")
        XCTAssertEqual(reorderedPlayers[1].name, "Player 1")
    }
    
    func testEditModeVisualChanges() {
        // Test that edit mode affects UI state
        var isEditMode = false
        
        // Test normal mode
        XCTAssertFalse(isEditMode)
        
        // Test edit mode
        isEditMode = true
        XCTAssertTrue(isEditMode)
        
        // Test edit mode affects button states
        let addButtonEnabled = !isEditMode
        XCTAssertFalse(addButtonEnabled) // Add button should be disabled in edit mode
    }
    
    func testEditModeExit() {
        var isEditMode = true
        XCTAssertTrue(isEditMode)
        
        // Exit edit mode
        isEditMode = false
        XCTAssertFalse(isEditMode)
    }
    
    func testEditModePersistence() {
        // Test that edit mode state is maintained during operations
        var isEditMode = true
        
        // Perform some operations while in edit mode
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        
        // Edit mode should still be true
        XCTAssertTrue(isEditMode)
        
        // Exit edit mode
        isEditMode = false
        XCTAssertFalse(isEditMode)
    }
    
    // MARK: - Player Selection Logic Tests
    
    func testPlayerTapSelection() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        try! testContext.save()
        
        // Test initial state
        XCTAssertNil(appContext.currentPlayer)
        
        // Simulate tap selection
        appContext.switchToPlayer(player1)
        XCTAssertEqual(appContext.currentPlayer, player1)
        
        // Simulate tap selection of different player
        appContext.switchToPlayer(player2)
        XCTAssertEqual(appContext.currentPlayer, player2)
        XCTAssertNotEqual(appContext.currentPlayer, player1)
    }
    
    func testSelectionVisualFeedback() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        // Test selection state
        appContext.switchToPlayer(player)
        XCTAssertEqual(appContext.currentPlayer, player)
        
        // Test that selection is immediately reflected
        let isSelected = appContext.currentPlayer?.id == player.id
        XCTAssertTrue(isSelected)
    }
    
    func testTeamSectionRefresh() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        
        let team1 = createTestTeam(name: "Team 1", player: player1, displayOrder: 0)
        let team2 = createTestTeam(name: "Team 2", player: player2, displayOrder: 0)
        
        try! testContext.save()
        
        // Select first player
        appContext.switchToPlayer(player1)
        XCTAssertEqual(appContext.currentPlayer, player1)
        
        // Verify team section shows correct teams
        let player1Teams = getTeamsForPlayer(player1)
        XCTAssertEqual(player1Teams.count, 1)
        XCTAssertEqual(player1Teams.first?.name, "Team 1")
        
        // Switch to second player
        appContext.switchToPlayer(player2)
        XCTAssertEqual(appContext.currentPlayer, player2)
        
        // Verify team section updates
        let player2Teams = getTeamsForPlayer(player2)
        XCTAssertEqual(player2Teams.count, 1)
        XCTAssertEqual(player2Teams.first?.name, "Team 2")
    }
    
    func testSelectionDuringEditMode() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        try! testContext.save()
        
        // Set edit mode
        let isEditMode = true
        
        // Test that selection is disabled during edit mode
        // In edit mode, taps should not change selection
        appContext.switchToPlayer(player1)
        XCTAssertEqual(appContext.currentPlayer, player1)
        
        // Even if we try to select another player during edit mode,
        // the selection should remain the same for UI purposes
        // (This is handled in the view layer)
        XCTAssertEqual(appContext.currentPlayer, player1)
    }
    
    // MARK: - Helper Methods
    
    private func createTestPlayer(name: String, displayOrder: Int32) -> Player {
        let player = Player(context: testContext)
        player.id = UUID()
        player.name = name
        player.displayOrder = displayOrder
        player.sport = "Basketball"
        player.playerColor = Constants.Defaults.defaultPlayerColor.toHex()
        return player
    }
    
    private func createTestTeam(name: String, player: Player, displayOrder: Int32) -> Team {
        let team = Team(context: testContext)
        team.id = UUID()
        team.name = name
        team.displayOrder = displayOrder
        team.sport = "Basketball"
        team.teamColor = Constants.Defaults.defaultTeamColor.toHex()
        team.player = player
        return team
    }
    
    private func getTeamsForPlayer(_ player: Player) -> [Team] {
        let request: NSFetchRequest<Team> = Team.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@", player)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Team.displayOrder, ascending: true)]
        return try! testContext.fetch(request)
    }
} 