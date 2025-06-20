//
//  PlayerDetailViewsTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import XCTest
import SwiftUI
import CoreData
@testable import ScoreSnap

@MainActor
class PlayerDetailViewsTests: XCTestCase {
    
    var testContext: NSManagedObjectContext!
    var viewModel: PlayersViewModel!
    
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
    }
    
    override func tearDown() {
        testContext = nil
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Player Detail Form Tests
    
    func testFormFieldPopulation() {
        // Test that existing player data populates form correctly
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        player.playerColor = Constants.Defaults.defaultPlayerColor.rawValue
        player.sport = "Basketball"
        try! testContext.save()
        
        // Verify form fields would be populated correctly
        XCTAssertEqual(player.name, "Test Player")
        XCTAssertEqual(player.playerColor, Constants.Defaults.defaultPlayerColor.rawValue)
        XCTAssertEqual(player.sport, "Basketball")
        XCTAssertNotNil(player.id)
    }
    
    func testNameEditing() {
        let player = createTestPlayer(name: "Original Name", displayOrder: 0)
        try! testContext.save()
        
        // Test name modification
        let newName = "Updated Name"
        viewModel.updatePlayer(player, name: newName, color: Constants.Defaults.defaultPlayerColor, sport: "Basketball")
        
        XCTAssertEqual(player.name, newName)
        
        // Test name trimming
        let nameWithWhitespace = "  Trimmed Name  "
        viewModel.updatePlayer(player, name: nameWithWhitespace, color: Constants.Defaults.defaultPlayerColor, sport: "Basketball")
        
        XCTAssertEqual(player.name, "Trimmed Name")
    }
    
    func testColorPickerIntegration() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        // Test color selection
        let selectedColor = TeamColor.red
        viewModel.updatePlayer(player, name: "Test Player", color: selectedColor, sport: "Basketball")
        
        XCTAssertEqual(player.playerColor, selectedColor.rawValue)
        
        // Test color retrieval
        let retrievedColor = viewModel.getPlayerColor(player)
        XCTAssertNotNil(retrievedColor)
    }
    
    func testFormValidation() {
        // Test empty name validation
        XCTAssertFalse(viewModel.validatePlayerName(""))
        XCTAssertFalse(viewModel.validatePlayerName("   "))
        
        // Test valid name validation
        XCTAssertTrue(viewModel.validatePlayerName("Valid Name"))
        XCTAssertTrue(viewModel.validatePlayerName("A"))
        
        // Test name length validation
        let longName = String(repeating: "A", count: 51)
        XCTAssertFalse(viewModel.validatePlayerName(longName))
        
        let maxLengthName = String(repeating: "A", count: 50)
        XCTAssertTrue(viewModel.validatePlayerName(maxLengthName))
    }
    
    func testSaveFunctionality() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        // Test save with changes
        let newName = "Updated Player"
        let newColor = TeamColor.green
        
        viewModel.updatePlayer(player, name: newName, color: newColor, sport: "Basketball")
        
        // Verify changes were saved
        XCTAssertEqual(player.name, newName)
        XCTAssertEqual(player.playerColor, newColor.rawValue)
        
        // Verify persistence
        let playersRequest: NSFetchRequest<Player> = Player.fetchRequest()
        let players = try! testContext.fetch(playersRequest)
        XCTAssertEqual(players.count, 1)
        XCTAssertEqual(players.first?.name, newName)
    }
    
    func testCancelFunctionality() {
        let originalName = "Original Name"
        let player = createTestPlayer(name: originalName, displayOrder: 0)
        try! testContext.save()
        
        // Simulate form changes without saving
        let tempName = "Temporary Name"
        player.name = tempName
        
        // Verify temporary change
        XCTAssertEqual(player.name, tempName)
        
        // Simulate cancellation by reverting changes
        player.name = originalName
        
        // Verify original state restored
        XCTAssertEqual(player.name, originalName)
    }
    
    // MARK: - Team Detail Form Tests
    
    func testTeamFormFieldPopulation() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        team.teamColor = Constants.Defaults.defaultTeamColor.rawValue
        team.sport = "Basketball"
        try! testContext.save()
        
        // Verify form fields would be populated correctly
        XCTAssertEqual(team.name, "Test Team")
        XCTAssertEqual(team.teamColor, Constants.Defaults.defaultTeamColor.rawValue)
        XCTAssertEqual(team.sport, "Basketball")
        XCTAssertEqual(team.player, player)
        XCTAssertNotNil(team.id)
    }
    
    func testTeamNameEditing() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Original Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Test name modification
        let newName = "Updated Team"
        viewModel.updateTeam(team, name: newName, color: Constants.Defaults.defaultTeamColor, sport: "Basketball")
        
        XCTAssertEqual(team.name, newName)
        
        // Test name trimming
        let nameWithWhitespace = "  Trimmed Team  "
        viewModel.updateTeam(team, name: nameWithWhitespace, color: Constants.Defaults.defaultTeamColor, sport: "Basketball")
        
        XCTAssertEqual(team.name, "Trimmed Team")
    }
    
    func testTeamColorPickerIntegration() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Test color selection
        let selectedColor = TeamColor.blue
        viewModel.updateTeam(team, name: "Test Team", color: selectedColor, sport: "Basketball")
        
        XCTAssertEqual(team.teamColor, selectedColor.rawValue)
        
        // Test color retrieval
        let retrievedColor = viewModel.getTeamColor(team)
        XCTAssertNotNil(retrievedColor)
    }
    
    func testPlayerAssociationDisplay() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Verify player association
        XCTAssertEqual(team.player, player)
        XCTAssertEqual(team.player?.name, "Test Player")
        
        // Test team belongs to correct player
        let playerTeams = viewModel.teamsForPlayer(player)
        XCTAssertEqual(playerTeams.count, 1)
        XCTAssertEqual(playerTeams.first?.name, "Test Team")
    }
    
    func testTeamFormValidation() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        // Test empty name validation
        XCTAssertFalse(viewModel.validateTeamName(""))
        XCTAssertFalse(viewModel.validateTeamName("   "))
        
        // Test valid name validation
        XCTAssertTrue(viewModel.validateTeamName("Valid Team"))
        XCTAssertTrue(viewModel.validateTeamName("A"))
        
        // Test name length validation
        let longName = String(repeating: "A", count: 51)
        XCTAssertFalse(viewModel.validateTeamName(longName))
        
        let maxLengthName = String(repeating: "A", count: 50)
        XCTAssertTrue(viewModel.validateTeamName(maxLengthName))
        
        // Test color format validation
        let validColor = TeamColor.red
        XCTAssertNotNil(validColor.rawValue)
        XCTAssertTrue(validColor.rawValue.hasPrefix("#"))
    }
    
    func testTeamSaveCancelFunctionality() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Original Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Test save with changes
        let newName = "Updated Team"
        let newColor = TeamColor.orange
        
        viewModel.updateTeam(team, name: newName, color: newColor, sport: "Basketball")
        
        // Verify changes were saved
        XCTAssertEqual(team.name, newName)
        XCTAssertEqual(team.teamColor, newColor.rawValue)
        
        // Test cancellation simulation
        let tempName = "Temporary Team"
        team.name = tempName
        
        // Verify temporary change
        XCTAssertEqual(team.name, tempName)
        
        // Simulate cancellation by reverting
        team.name = newName
        
        // Verify original saved state restored
        XCTAssertEqual(team.name, newName)
    }
    
    // MARK: - Delete Confirmation Tests
    
    func testDeleteButtonAvailability() {
        // Test that delete button is only available for existing entities
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Verify entities exist
        XCTAssertNotNil(player.id)
        XCTAssertNotNil(team.id)
        
        // Test that delete operations are available
        XCTAssertNoThrow(viewModel.deletePlayer(player))
        XCTAssertNoThrow(viewModel.deleteTeam(team))
    }
    
    func testDeleteConfirmationDialog() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Test that confirmation would be required before deletion
        // This is handled in the view layer, but we can test the deletion logic
        
        // Verify entities exist before deletion
        XCTAssertEqual(viewModel.players.count, 1)
        XCTAssertEqual(viewModel.teams.count, 1)
        
        // Test deletion
        viewModel.deletePlayer(player)
        
        // Verify deletion occurred
        XCTAssertEqual(viewModel.players.count, 0)
        XCTAssertEqual(viewModel.teams.count, 0) // Should cascade delete
    }
    
    func testDeleteActionExecution() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        let game = createTestGame(team: team)
        try! testContext.save()
        
        // Verify initial state
        XCTAssertEqual(viewModel.players.count, 1)
        XCTAssertEqual(viewModel.teams.count, 1)
        
        // Test player deletion with cascade
        viewModel.deletePlayer(player)
        
        // Verify cascade deletion
        XCTAssertEqual(viewModel.players.count, 0)
        XCTAssertEqual(viewModel.teams.count, 0)
        
        // Verify game was also deleted
        let gamesRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let games = try! testContext.fetch(gamesRequest)
        XCTAssertEqual(games.count, 0)
    }
    
    func testDeleteCancellation() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        // Verify entity exists
        XCTAssertEqual(viewModel.players.count, 1)
        
        // Simulate cancellation by not calling delete
        // viewModel.deletePlayer(player) is not called
        
        // Verify entity still exists
        XCTAssertEqual(viewModel.players.count, 1)
        XCTAssertEqual(viewModel.players.first?.name, "Test Player")
    }
    
    func testCascadeDeleteWarning() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        let game = createTestGame(team: team)
        try! testContext.save()
        
        // Verify cascade relationships
        XCTAssertEqual(player.teams?.count, 1)
        XCTAssertEqual(team.games?.count, 1)
        
        // Test that deletion would cascade
        viewModel.deletePlayer(player)
        
        // Verify everything was deleted
        XCTAssertEqual(viewModel.players.count, 0)
        XCTAssertEqual(viewModel.teams.count, 0)
        
        let gamesRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let games = try! testContext.fetch(gamesRequest)
        XCTAssertEqual(games.count, 0)
    }
    
    // MARK: - Duplicate Name Validation Tests
    
    func testDuplicatePlayerNameValidation() {
        let player1 = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        // Test duplicate name validation
        XCTAssertFalse(viewModel.isPlayerNameUnique("Test Player", excluding: nil))
        XCTAssertTrue(viewModel.isPlayerNameUnique("Test Player", excluding: player1)) // Same player
        XCTAssertTrue(viewModel.isPlayerNameUnique("Different Player", excluding: nil))
        
        // Test case insensitive validation
        XCTAssertFalse(viewModel.isPlayerNameUnique("test player", excluding: nil))
        XCTAssertFalse(viewModel.isPlayerNameUnique("TEST PLAYER", excluding: nil))
    }
    
    func testDuplicateTeamNameValidation() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team1 = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Test duplicate name validation within same player
        XCTAssertFalse(viewModel.isTeamNameUnique("Test Team", for: player, excluding: nil))
        XCTAssertTrue(viewModel.isTeamNameUnique("Test Team", for: player, excluding: team1)) // Same team
        XCTAssertTrue(viewModel.isTeamNameUnique("Different Team", for: player, excluding: nil))
        
        // Test case insensitive validation
        XCTAssertFalse(viewModel.isTeamNameUnique("test team", for: player, excluding: nil))
        XCTAssertFalse(viewModel.isTeamNameUnique("TEST TEAM", for: player, excluding: nil))
    }
    
    // MARK: - Color Management Tests
    
    func testColorFormatConversion() {
        // Test color to hex conversion
        let colors: [TeamColor] = [.red, .blue, .green, .yellow, .purple, .orange]
        
        for color in colors {
            let hex = color.rawValue
            XCTAssertTrue(hex.hasPrefix("#"))
            XCTAssertEqual(hex.count, 7) // #RRGGBB format
            
            // Test hex to color conversion
            let convertedColor = TeamColor(rawValue: hex)
            XCTAssertNotNil(convertedColor)
        }
    }
    
    func testDefaultColorAssignment() {
        // Test that new entities get appropriate default colors
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        
        XCTAssertNotNil(player.playerColor)
        XCTAssertNotNil(team.teamColor)
        
        // Test color retrieval
        let playerColor = viewModel.getPlayerColor(player)
        let teamColor = viewModel.getTeamColor(team)
        
        XCTAssertNotNil(playerColor)
        XCTAssertNotNil(teamColor)
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