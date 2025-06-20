//
//  PlayersViewModelTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import XCTest
import SwiftUI
import CoreData
@testable import ScoreSnap

@MainActor
class PlayersViewModelTests: XCTestCase {
    
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
    
    // MARK: - Player CRUD Operations Tests
    
    func testPlayerCreation() {
        // Test player creation with correct properties
        let playerName = "Test Player"
        let playerColor = TeamColor.red
        let sport = "Basketball"
        
        viewModel.createPlayer(name: playerName, color: playerColor, sport: sport)
        
        XCTAssertEqual(viewModel.players.count, 1)
        let createdPlayer = viewModel.players.first
        XCTAssertNotNil(createdPlayer)
        XCTAssertEqual(createdPlayer?.name, playerName)
        XCTAssertEqual(createdPlayer?.playerColor, playerColor.rawValue)
        XCTAssertEqual(createdPlayer?.sport, sport)
        XCTAssertEqual(createdPlayer?.displayOrder, 0)
        XCTAssertNotNil(createdPlayer?.id)
    }
    
    func testPlayerCreationValidation() {
        // Test empty name rejection
        viewModel.createPlayer(name: "", color: .red, sport: "Basketball")
        XCTAssertEqual(viewModel.players.count, 0)
        
        // Test whitespace-only name rejection
        viewModel.createPlayer(name: "   ", color: .red, sport: "Basketball")
        XCTAssertEqual(viewModel.players.count, 0)
        
        // Test duplicate name rejection
        viewModel.createPlayer(name: "Player 1", color: .red, sport: "Basketball")
        viewModel.createPlayer(name: "Player 1", color: .blue, sport: "Basketball")
        XCTAssertEqual(viewModel.players.count, 1) // Only first player should be created
    }
    
    func testPlayerDeletion() {
        // Create player with team and game
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        let game = createTestGame(team: team)
        
        try! testContext.save()
        
        // Verify initial state
        XCTAssertEqual(viewModel.players.count, 1)
        XCTAssertEqual(viewModel.teams.count, 1)
        
        // Delete player
        viewModel.deletePlayer(player)
        
        // Verify cascade deletion
        XCTAssertEqual(viewModel.players.count, 0)
        XCTAssertEqual(viewModel.teams.count, 0)
        
        // Verify game was also deleted
        let gameRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let remainingGames = try! testContext.fetch(gameRequest)
        XCTAssertEqual(remainingGames.count, 0)
    }
    
    func testPlayerDeletionValidation() {
        // Create single player
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        // Should allow deletion of single player (no "last remaining" restriction in this implementation)
        viewModel.deletePlayer(player)
        XCTAssertEqual(viewModel.players.count, 0)
    }
    
    func testPlayerEditing() {
        // Create player
        let player = createTestPlayer(name: "Original Name", displayOrder: 0)
        try! testContext.save()
        
        // Edit player
        let newName = "Updated Name"
        let newColor = TeamColor.blue
        let newSport = "Basketball"
        
        viewModel.updatePlayer(player, name: newName, color: newColor, sport: newSport)
        
        // Verify changes
        XCTAssertEqual(player.name, newName)
        XCTAssertEqual(player.playerColor, newColor.rawValue)
        XCTAssertEqual(player.sport, newSport)
    }
    
    func testPlayerLoading() {
        // Create players with different display orders
        let player3 = createTestPlayer(name: "Player C", displayOrder: 2)
        let player1 = createTestPlayer(name: "Player A", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player B", displayOrder: 1)
        
        try! testContext.save()
        
        // Reload data
        viewModel.loadData()
        
        // Verify correct order
        XCTAssertEqual(viewModel.players.count, 3)
        XCTAssertEqual(viewModel.players[0].name, "Player A")
        XCTAssertEqual(viewModel.players[1].name, "Player B")
        XCTAssertEqual(viewModel.players[2].name, "Player C")
    }
    
    func testPlayerCountTracking() {
        XCTAssertEqual(viewModel.players.count, 0)
        
        viewModel.createPlayer(name: "Player 1", color: .red, sport: "Basketball")
        XCTAssertEqual(viewModel.players.count, 1)
        
        viewModel.createPlayer(name: "Player 2", color: .blue, sport: "Basketball")
        XCTAssertEqual(viewModel.players.count, 2)
        
        // Delete one player
        viewModel.deletePlayer(viewModel.players.first!)
        XCTAssertEqual(viewModel.players.count, 1)
    }
    
    // MARK: - Team CRUD Operations Tests
    
    func testTeamCreation() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        let teamName = "Test Team"
        let teamColor = TeamColor.green
        let sport = "Basketball"
        
        viewModel.createTeam(name: teamName, color: teamColor, player: player, sport: sport)
        
        XCTAssertEqual(viewModel.teams.count, 1)
        let createdTeam = viewModel.teams.first
        XCTAssertNotNil(createdTeam)
        XCTAssertEqual(createdTeam?.name, teamName)
        XCTAssertEqual(createdTeam?.teamColor, teamColor.rawValue)
        XCTAssertEqual(createdTeam?.sport, sport)
        XCTAssertEqual(createdTeam?.player, player)
        XCTAssertEqual(createdTeam?.displayOrder, 0)
        XCTAssertNotNil(createdTeam?.id)
    }
    
    func testTeamCreationValidation() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        // Test empty name rejection
        viewModel.createTeam(name: "", color: .blue, player: player, sport: "Basketball")
        XCTAssertEqual(viewModel.teams.count, 0)
        
        // Test duplicate name rejection within same player
        viewModel.createTeam(name: "Team 1", color: .blue, player: player, sport: "Basketball")
        viewModel.createTeam(name: "Team 1", color: .red, player: player, sport: "Basketball")
        XCTAssertEqual(viewModel.teams.count, 1) // Only first team should be created
    }
    
    func testTeamDeletion() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        let game = createTestGame(team: team)
        
        try! testContext.save()
        
        // Verify initial state
        XCTAssertEqual(viewModel.teams.count, 1)
        
        // Delete team
        viewModel.deleteTeam(team)
        
        // Verify cascade deletion
        XCTAssertEqual(viewModel.teams.count, 0)
        
        // Verify game was also deleted
        let gameRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let remainingGames = try! testContext.fetch(gameRequest)
        XCTAssertEqual(remainingGames.count, 0)
    }
    
    func testTeamDeletionValidation() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Should allow deletion of single team
        viewModel.deleteTeam(team)
        XCTAssertEqual(viewModel.teams.count, 0)
    }
    
    func testTeamEditing() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Original Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        let newName = "Updated Team"
        let newColor = TeamColor.purple
        let newSport = "Basketball"
        
        viewModel.updateTeam(team, name: newName, color: newColor, sport: newSport)
        
        XCTAssertEqual(team.name, newName)
        XCTAssertEqual(team.teamColor, newColor.rawValue)
        XCTAssertEqual(team.sport, newSport)
    }
    
    func testTeamLoadingForPlayer() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        
        let team1B = createTestTeam(name: "Team 1B", player: player1, displayOrder: 1)
        let team1A = createTestTeam(name: "Team 1A", player: player1, displayOrder: 0)
        let team2A = createTestTeam(name: "Team 2A", player: player2, displayOrder: 0)
        
        try! testContext.save()
        
        viewModel.loadData()
        
        let player1Teams = viewModel.teamsForPlayer(player1)
        XCTAssertEqual(player1Teams.count, 2)
        XCTAssertEqual(player1Teams[0].name, "Team 1A") // Should be first by displayOrder
        XCTAssertEqual(player1Teams[1].name, "Team 1B")
        
        let player2Teams = viewModel.teamsForPlayer(player2)
        XCTAssertEqual(player2Teams.count, 1)
        XCTAssertEqual(player2Teams[0].name, "Team 2A")
    }
    
    func testTeamPlayerAssociation() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        
        let team1 = createTestTeam(name: "Team 1", player: player1, displayOrder: 0)
        let team2 = createTestTeam(name: "Team 2", player: player2, displayOrder: 0)
        
        try! testContext.save()
        
        viewModel.loadData()
        
        XCTAssertEqual(team1.player, player1)
        XCTAssertEqual(team2.player, player2)
        XCTAssertNotEqual(team1.player, player2)
        XCTAssertNotEqual(team2.player, player1)
    }
    
    // MARK: - Reordering Logic Tests
    
    func testPlayerReordering() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        let player3 = createTestPlayer(name: "Player 3", displayOrder: 2)
        
        try! testContext.save()
        viewModel.loadData()
        
        // Move player 3 to first position
        viewModel.movePlayer(from: IndexSet(integer: 2), to: 0)
        
        XCTAssertEqual(viewModel.players[0].name, "Player 3")
        XCTAssertEqual(viewModel.players[1].name, "Player 1")
        XCTAssertEqual(viewModel.players[2].name, "Player 2")
        
        // Verify displayOrder values
        XCTAssertEqual(viewModel.players[0].displayOrder, 0)
        XCTAssertEqual(viewModel.players[1].displayOrder, 1)
        XCTAssertEqual(viewModel.players[2].displayOrder, 2)
    }
    
    func testPlayerReorderPersistence() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        
        try! testContext.save()
        viewModel.loadData()
        
        // Reorder players
        viewModel.movePlayer(from: IndexSet(integer: 1), to: 0)
        
        // Create new viewModel to simulate reload
        let newViewModel = PlayersViewModel(viewContext: testContext)
        
        XCTAssertEqual(newViewModel.players[0].name, "Player 2")
        XCTAssertEqual(newViewModel.players[1].name, "Player 1")
    }
    
    func testPlayerReorderEdgeCases() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        let player3 = createTestPlayer(name: "Player 3", displayOrder: 2)
        
        try! testContext.save()
        viewModel.loadData()
        
        // Move first to last
        viewModel.movePlayer(from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(viewModel.players[2].name, "Player 1")
        
        // Move last to first
        viewModel.movePlayer(from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(viewModel.players[0].name, "Player 1")
    }
    
    func testTeamReordering() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team1 = createTestTeam(name: "Team 1", player: player, displayOrder: 0)
        let team2 = createTestTeam(name: "Team 2", player: player, displayOrder: 1)
        let team3 = createTestTeam(name: "Team 3", player: player, displayOrder: 2)
        
        try! testContext.save()
        viewModel.loadData()
        
        // Move team 3 to first position
        viewModel.moveTeam(from: IndexSet(integer: 2), to: 0, for: player)
        
        let playerTeams = viewModel.teamsForPlayer(player)
        XCTAssertEqual(playerTeams[0].name, "Team 3")
        XCTAssertEqual(playerTeams[1].name, "Team 1")
        XCTAssertEqual(playerTeams[2].name, "Team 2")
    }
    
    func testTeamReorderPersistence() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team1 = createTestTeam(name: "Team 1", player: player, displayOrder: 0)
        let team2 = createTestTeam(name: "Team 2", player: player, displayOrder: 1)
        
        try! testContext.save()
        viewModel.loadData()
        
        // Reorder teams
        viewModel.moveTeam(from: IndexSet(integer: 1), to: 0, for: player)
        
        // Create new viewModel to simulate reload
        let newViewModel = PlayersViewModel(viewContext: testContext)
        let playerTeams = newViewModel.teamsForPlayer(player)
        
        XCTAssertEqual(playerTeams[0].name, "Team 2")
        XCTAssertEqual(playerTeams[1].name, "Team 1")
    }
    
    func testCrossPlayerTeamIsolation() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        
        let team1A = createTestTeam(name: "Team 1A", player: player1, displayOrder: 0)
        let team1B = createTestTeam(name: "Team 1B", player: player1, displayOrder: 1)
        let team2A = createTestTeam(name: "Team 2A", player: player2, displayOrder: 0)
        let team2B = createTestTeam(name: "Team 2B", player: player2, displayOrder: 1)
        
        try! testContext.save()
        viewModel.loadData()
        
        // Reorder teams for player 1
        viewModel.moveTeam(from: IndexSet(integer: 1), to: 0, for: player1)
        
        let player1Teams = viewModel.teamsForPlayer(player1)
        let player2Teams = viewModel.teamsForPlayer(player2)
        
        // Player 1 teams should be reordered
        XCTAssertEqual(player1Teams[0].name, "Team 1B")
        XCTAssertEqual(player1Teams[1].name, "Team 1A")
        
        // Player 2 teams should remain unchanged
        XCTAssertEqual(player2Teams[0].name, "Team 2A")
        XCTAssertEqual(player2Teams[1].name, "Team 2B")
    }
    
    // MARK: - Selection Management Tests
    
    func testPlayerSelection() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        try! testContext.save()
        
        // Test initial state
        XCTAssertNil(appContext.currentPlayer)
        
        // Select player
        appContext.switchToPlayer(player1)
        XCTAssertEqual(appContext.currentPlayer, player1)
        
        // Switch to different player
        appContext.switchToPlayer(player2)
        XCTAssertEqual(appContext.currentPlayer, player2)
    }
    
    func testTeamCascadeOnPlayerSelection() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team1 = createTestTeam(name: "Team 1", player: player, displayOrder: 0)
        let team2 = createTestTeam(name: "Team 2", player: player, displayOrder: 1)
        try! testContext.save()
        
        // First set the player
        appContext.switchToPlayer(player)
        XCTAssertEqual(appContext.currentPlayer, player)
        XCTAssertEqual(appContext.currentTeam, team1) // Should default to first team
        
        // Set current team to second team
        appContext.switchToTeam(team2)
        XCTAssertEqual(appContext.currentTeam, team2)
        
        // Switch to same player (should NOT reset to first team)
        appContext.switchToPlayer(player)
        XCTAssertEqual(appContext.currentTeam, team2) // Should remain the same team
    }
    
    func testAppContextIntegration() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Test player selection updates AppContext
        appContext.switchToPlayer(player)
        XCTAssertEqual(appContext.currentPlayer, player)
        XCTAssertEqual(appContext.currentTeam, team) // Should default to first team
        
        // Test team selection updates AppContext
        appContext.switchToTeam(team)
        XCTAssertEqual(appContext.currentTeam, team)
    }
    
    func testSelectionPersistence() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Set selection
        appContext.switchToPlayerAndTeam(player, team)
        
        // Create new AppContext to simulate app restart
        let newAppContext = AppContext(viewContext: testContext)
        
        XCTAssertEqual(newAppContext.currentPlayer?.id, player.id)
        XCTAssertEqual(newAppContext.currentTeam?.id, team.id)
    }
    
    func testInvalidSelectionHandling() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Set selection
        appContext.switchToPlayerAndTeam(player, team)
        
        // Delete the entities
        testContext.delete(player)
        testContext.delete(team)
        try! testContext.save()
        
        // Create new AppContext - should handle missing entities gracefully
        let newAppContext = AppContext(viewContext: testContext)
        XCTAssertNil(newAppContext.currentPlayer)
        XCTAssertNil(newAppContext.currentTeam)
    }
    
    // MARK: - Color Management Tests
    
    func testTeamColorAssignment() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let teamColor = TeamColor.red
        
        viewModel.updatePlayer(player, name: "Test Player", color: teamColor, sport: "Basketball")
        
        XCTAssertEqual(player.playerColor, teamColor.rawValue)
    }
    
    func testTeamColorValidation() {
        // Test valid TeamColor values
        for teamColor in TeamColor.allCases {
            XCTAssertNotNil(TeamColor(rawValue: teamColor.rawValue))
            XCTAssertEqual(TeamColor(rawValue: teamColor.rawValue), teamColor)
        }
        
        // Test invalid TeamColor values
        let invalidColors = ["invalid", "RED", "Blue123", ""]
        for invalidColor in invalidColors {
            XCTAssertNil(TeamColor(rawValue: invalidColor))
        }
    }
    
    func testDefaultTeamColorAssignment() {
        // Create multiple players to test default colors
        viewModel.createPlayer(name: "Player 1", color: Constants.Defaults.defaultPlayerColor, sport: "Basketball")
        viewModel.createPlayer(name: "Player 2", color: Constants.Defaults.defaultPlayerColor, sport: "Basketball")
        
        XCTAssertEqual(viewModel.players.count, 2)
        XCTAssertNotNil(viewModel.players[0].playerColor)
        XCTAssertNotNil(viewModel.players[1].playerColor)
        XCTAssertEqual(viewModel.players[0].playerColor, Constants.Defaults.defaultPlayerColor.rawValue)
        XCTAssertEqual(viewModel.players[1].playerColor, Constants.Defaults.defaultPlayerColor.rawValue)
    }
    
    func testTeamColorPersistence() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let originalColor = TeamColor.blue
        player.playerColor = originalColor.rawValue
        
        try! testContext.save()
        
        // Create new viewModel to simulate reload
        let newViewModel = PlayersViewModel(viewContext: testContext)
        
        let loadedPlayer = newViewModel.players.first
        XCTAssertNotNil(loadedPlayer)
        XCTAssertEqual(loadedPlayer?.playerColor, originalColor.rawValue)
        
        // Test color conversion back to SwiftUI Color
        let loadedColor = newViewModel.getPlayerColor(loadedPlayer!)
        XCTAssertEqual(loadedColor, originalColor.color)
    }
    
    func testTeamColorPickerIntegration() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let newColor = TeamColor.green
        
        // Simulate color picker selection
        viewModel.updatePlayer(player, name: "Test Player", color: newColor, sport: "Basketball")
        
        // Verify color was updated
        XCTAssertEqual(player.playerColor, newColor.rawValue)
        
        // Test color retrieval
        let retrievedColor = viewModel.getPlayerColor(player)
        XCTAssertEqual(retrievedColor, newColor.color)
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
    
    private func createTestGame(team: Team) -> Game {
        let game = Game(context: testContext)
        game.id = UUID()
        game.gameDate = Date()
        game.gameTime = Date()
        game.gameLocation = "Test Location"
        game.teamScore = 100
        game.opponentScore = 90
        game.isWin = true
        game.isTie = false
        game.opponentName = "Test Opponent"
        game.notes = "Test game"
        game.gameEditDate = Date()
        game.gameEditTime = Date()
        game.team = team
        return game
    }
} 