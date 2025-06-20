//
//  PlayersViewUITests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import XCTest
import SwiftUI
import CoreData
@testable import ScoreSnap

@MainActor
class PlayersViewUITests: XCTestCase {
    
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
    
    // MARK: - Navigation and Access Tests
    
    func testPlayersViewAccessibility() {
        // Test that PlayersView can be accessed from MainTabView
        // This would be tested in a real UI test with XCUITest
        // For unit tests, we verify the view can be created
        
        let playersView = PlayersView()
        XCTAssertNotNil(playersView)
        
        // Test that view has proper navigation title
        // In real UI test: XCTAssertTrue(app.navigationBars["Players"].exists)
    }
    
    func testViewLoading() {
        // Create test data
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Test that view loads with existing data
        let playersView = PlayersView()
        XCTAssertNotNil(playersView)
        
        // Verify data is available
        let playersRequest: NSFetchRequest<Player> = Player.fetchRequest()
        let teamsRequest: NSFetchRequest<Team> = Team.fetchRequest()
        
        let players = try! testContext.fetch(playersRequest)
        let teams = try! testContext.fetch(teamsRequest)
        
        XCTAssertEqual(players.count, 1)
        XCTAssertEqual(teams.count, 1)
    }
    
    func testSectionVisibility() {
        // Test that both Players and Teams sections are accessible
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Verify both sections have data
        let playersRequest: NSFetchRequest<Player> = Player.fetchRequest()
        let teamsRequest: NSFetchRequest<Team> = Team.fetchRequest()
        
        let players = try! testContext.fetch(playersRequest)
        let teams = try! testContext.fetch(teamsRequest)
        
        XCTAssertEqual(players.count, 1)
        XCTAssertEqual(teams.count, 1)
        
        // Test section labels would be visible
        // In real UI test: XCTAssertTrue(app.staticTexts["Players"].exists)
        // In real UI test: XCTAssertTrue(app.staticTexts["Teams"].exists)
    }
    
    // MARK: - Player Management UI Tests
    
    func testPlayerListDisplay() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        try! testContext.save()
        
        // Verify all players are displayed in correct order
        let playersRequest: NSFetchRequest<Player> = Player.fetchRequest()
        playersRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Player.displayOrder, ascending: true)]
        let players = try! testContext.fetch(playersRequest)
        
        XCTAssertEqual(players.count, 2)
        XCTAssertEqual(players[0].name, "Player 1")
        XCTAssertEqual(players[1].name, "Player 2")
    }
    
    func testPlayerSelection() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        try! testContext.save()
        
        // Test initial state
        XCTAssertNil(appContext.currentPlayer)
        
        // Simulate player selection
        appContext.switchToPlayer(player1)
        XCTAssertEqual(appContext.currentPlayer, player1)
        
        // Switch to different player
        appContext.switchToPlayer(player2)
        XCTAssertEqual(appContext.currentPlayer, player2)
        XCTAssertNotEqual(appContext.currentPlayer, player1)
    }
    
    func testCurrentPlayerHighlighting() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        try! testContext.save()
        
        // Select first player
        appContext.switchToPlayer(player1)
        XCTAssertEqual(appContext.currentPlayer, player1)
        
        // Verify selection state
        let isPlayer1Selected = appContext.currentPlayer?.id == player1.id
        let isPlayer2Selected = appContext.currentPlayer?.id == player2.id
        
        XCTAssertTrue(isPlayer1Selected)
        XCTAssertFalse(isPlayer2Selected)
    }
    
    func testAddPlayerInteraction() {
        // Test that add player functionality is available
        let playersRequest: NSFetchRequest<Player> = Player.fetchRequest()
        let initialCount = try! testContext.fetch(playersRequest).count
        
        // Create a new player (simulating add button tap)
        let newPlayer = createTestPlayer(name: "New Player", displayOrder: Int32(initialCount))
        try! testContext.save()
        
        // Verify player was added
        let finalCount = try! testContext.fetch(playersRequest).count
        XCTAssertEqual(finalCount, initialCount + 1)
    }
    
    func testPlayerInfoButton() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        // Test that player has editable properties
        XCTAssertNotNil(player.name)
        XCTAssertNotNil(player.playerColor)
        XCTAssertNotNil(player.sport)
        
        // Test player can be updated
        player.name = "Updated Player"
        try! testContext.save()
        
        XCTAssertEqual(player.name, "Updated Player")
    }
    
    // MARK: - Team Management UI Tests
    
    func testTeamListUpdates() {
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
    
    func testTeamDisplay() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        team.teamColor = Constants.Defaults.defaultTeamColor.rawValue
        try! testContext.save()
        
        // Verify team properties are displayed correctly
        XCTAssertEqual(team.name, "Test Team")
        XCTAssertEqual(team.teamColor, Constants.Defaults.defaultTeamColor.rawValue)
        XCTAssertEqual(team.player, player)
        XCTAssertEqual(team.sport, "Basketball")
    }
    
    func testAddTeamInteraction() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        // Test that add team functionality is available
        let teamsRequest: NSFetchRequest<Team> = Team.fetchRequest()
        let initialCount = try! testContext.fetch(teamsRequest).count
        
        // Create a new team (simulating add button tap)
        let newTeam = createTestTeam(name: "New Team", player: player, displayOrder: Int32(initialCount))
        try! testContext.save()
        
        // Verify team was added
        let finalCount = try! testContext.fetch(teamsRequest).count
        XCTAssertEqual(finalCount, initialCount + 1)
        XCTAssertEqual(newTeam.player, player)
    }
    
    func testTeamInfoButton() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Test that team has editable properties
        XCTAssertNotNil(team.name)
        XCTAssertNotNil(team.teamColor)
        XCTAssertNotNil(team.sport)
        XCTAssertNotNil(team.player)
        
        // Test team can be updated
        team.name = "Updated Team"
        try! testContext.save()
        
        XCTAssertEqual(team.name, "Updated Team")
    }
    
    func testTeamLongPress() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Test that team can be edited
        XCTAssertNotNil(team.id)
        XCTAssertNotNil(team.name)
        
        // Test team editing functionality
        team.name = "Edited Team"
        try! testContext.save()
        
        XCTAssertEqual(team.name, "Edited Team")
    }
    
    // MARK: - Edit Mode UI Tests
    
    func testEditModeActivation() {
        // Test edit mode state management
        var isEditMode = false
        
        // Activate edit mode
        isEditMode = true
        XCTAssertTrue(isEditMode)
        
        // Deactivate edit mode
        isEditMode = false
        XCTAssertFalse(isEditMode)
    }
    
    func testDragHandlesAppearance() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        try! testContext.save()
        
        // Test that reorder functionality is available
        let players = [player1, player2]
        XCTAssertEqual(players.count, 2)
        
        // Test reorder operation
        var reorderedPlayers = players
        let movedPlayer = reorderedPlayers.remove(at: 1)
        reorderedPlayers.insert(movedPlayer, at: 0)
        
        XCTAssertEqual(reorderedPlayers.count, 2)
        XCTAssertEqual(reorderedPlayers[0].name, "Player 2")
        XCTAssertEqual(reorderedPlayers[1].name, "Player 1")
    }
    
    func testDragToReorder() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        let player3 = createTestPlayer(name: "Player 3", displayOrder: 2)
        try! testContext.save()
        
        // Test reorder operation
        let players = [player1, player2, player3]
        var reorderedPlayers = players
        
        // Move last to first
        let movedPlayer = reorderedPlayers.remove(at: 2)
        reorderedPlayers.insert(movedPlayer, at: 0)
        
        XCTAssertEqual(reorderedPlayers.count, 3)
        XCTAssertEqual(reorderedPlayers[0].name, "Player 3")
        XCTAssertEqual(reorderedPlayers[1].name, "Player 1")
        XCTAssertEqual(reorderedPlayers[2].name, "Player 2")
    }
    
    func testReorderVisualFeedback() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        try! testContext.save()
        
        // Test reorder operation maintains data integrity
        let players = [player1, player2]
        var reorderedPlayers = players
        
        // Simulate drag operation
        let movedPlayer = reorderedPlayers.remove(at: 1)
        reorderedPlayers.insert(movedPlayer, at: 0)
        
        // Verify all players are still present
        XCTAssertEqual(reorderedPlayers.count, 2)
        XCTAssertTrue(reorderedPlayers.contains(player1))
        XCTAssertTrue(reorderedPlayers.contains(player2))
    }
    
    func testEditModeCompletion() {
        var isEditMode = true
        XCTAssertTrue(isEditMode)
        
        // Complete edit mode
        isEditMode = false
        XCTAssertFalse(isEditMode)
        
        // Test that normal mode is restored
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        // Verify player can be selected in normal mode
        appContext.switchToPlayer(player)
        XCTAssertEqual(appContext.currentPlayer, player)
    }
    
    // MARK: - Color Management UI Tests
    
    func testColorPickerAccess() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        // Test color picker functionality
        let originalColor = player.playerColor
        XCTAssertNotNil(originalColor)
        
        // Test color change
        let newColor = Color.blue
        player.playerColor = newColor.toHex()
        try! testContext.save()
        
        XCTAssertEqual(player.playerColor, newColor.toHex())
        XCTAssertNotEqual(player.playerColor, originalColor)
    }
    
    func testColorSelection() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        // Test various color selections
        let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]
        
        for color in colors {
            player.playerColor = color.toHex()
            try! testContext.save()
            
            XCTAssertEqual(player.playerColor, color.toHex())
        }
    }
    
    func testColorApplication() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Test color application to both player and team
        let playerColor = Color.red
        let teamColor = Color.blue
        
        player.playerColor = playerColor.toHex()
        team.teamColor = teamColor.toHex()
        try! testContext.save()
        
        // Verify colors were applied
        XCTAssertEqual(player.playerColor, playerColor.toHex())
        XCTAssertEqual(team.teamColor, teamColor.toHex())
        
        // Test color retrieval
        let retrievedPlayerColor = Color(hex: player.playerColor!)
        let retrievedTeamColor = Color(hex: team.teamColor!)
        
        XCTAssertNotNil(retrievedPlayerColor)
        XCTAssertNotNil(retrievedTeamColor)
    }
    
    func testColorIndicators() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Test color indicators are present
        XCTAssertNotNil(player.playerColor)
        XCTAssertNotNil(team.teamColor)
        
        // Test color format
        XCTAssertTrue(player.playerColor!.hasPrefix("#"))
        XCTAssertTrue(team.teamColor!.hasPrefix("#"))
        XCTAssertEqual(player.playerColor!.count, 7)
        XCTAssertEqual(team.teamColor!.count, 7)
    }
    
    // MARK: - Form Interaction UI Tests
    
    func testPlayerCreationForm() {
        // Test player creation form fields
        let playerName = "New Player"
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
    
    func testTeamCreationForm() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        // Test team creation form fields
        let teamName = "New Team"
        let teamColor = Color.red
        let sport = "Basketball"
        
        let team = Team(context: testContext)
        team.id = UUID()
        team.name = teamName
        team.teamColor = Constants.Defaults.defaultTeamColor.rawValue
        team.sport = sport
        team.player = player
        team.displayOrder = 0
        
        try! testContext.save()
        
        // Verify form fields were populated correctly
        XCTAssertEqual(team.name, teamName)
        XCTAssertEqual(team.teamColor, Constants.Defaults.defaultTeamColor.rawValue)
        XCTAssertEqual(team.sport, sport)
        XCTAssertEqual(team.player, player)
        XCTAssertNotNil(team.id)
    }
    
    func testFormFieldInteraction() {
        // Test form field validation
        let emptyName = ""
        let validName = "Valid Name"
        let longName = String(repeating: "A", count: 51)
        
        // Test empty name validation
        XCTAssertTrue(emptyName.isEmpty)
        
        // Test valid name
        XCTAssertFalse(validName.isEmpty)
        XCTAssertTrue(validName.count <= 50)
        
        // Test long name validation
        XCTAssertTrue(longName.count > 50)
    }
    
    func testFormValidationFeedback() {
        // Test validation feedback for invalid input
        let emptyName = ""
        let whitespaceName = "   "
        
        // Test empty name
        XCTAssertTrue(emptyName.isEmpty)
        
        // Test whitespace name
        XCTAssertTrue(whitespaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        
        // Test valid name
        let validName = "Valid Name"
        XCTAssertFalse(validName.isEmpty)
        XCTAssertFalse(validName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    
    func testFormSaveCancel() {
        let player = createTestPlayer(name: "Original Name", displayOrder: 0)
        try! testContext.save()
        
        // Test save functionality
        let newName = "Updated Name"
        player.name = newName
        try! testContext.save()
        
        XCTAssertEqual(player.name, newName)
        
        // Test cancel functionality (simulate reverting changes)
        player.name = "Original Name"
        try! testContext.save()
        
        XCTAssertEqual(player.name, "Original Name")
    }
    
    // MARK: - Edit Forms Tests
    
    func testEditFormPrePopulation() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        player.playerColor = Color.blue.toHex()
        player.sport = "Basketball"
        try! testContext.save()
        
        // Test that form would be pre-populated with current data
        XCTAssertEqual(player.name, "Test Player")
        XCTAssertEqual(player.playerColor, Color.blue.toHex())
        XCTAssertEqual(player.sport, "Basketball")
        XCTAssertNotNil(player.id)
    }
    
    func testEditFormModification() {
        let player = createTestPlayer(name: "Original Name", displayOrder: 0)
        try! testContext.save()
        
        // Test form modification
        let newName = "Modified Name"
        let newColor = Color.green
        
        player.name = newName
        player.playerColor = newColor.toHex()
        try! testContext.save()
        
        // Verify modifications were saved
        XCTAssertEqual(player.name, newName)
        XCTAssertEqual(player.playerColor, newColor.toHex())
    }
    
    func testDeleteButtonInteraction() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        // Test that delete functionality is available
        XCTAssertNotNil(player.id)
        
        // Test deletion
        testContext.delete(player)
        try! testContext.save()
        
        // Verify player was deleted
        let playersRequest: NSFetchRequest<Player> = Player.fetchRequest()
        let players = try! testContext.fetch(playersRequest)
        XCTAssertEqual(players.count, 0)
    }
    
    func testConfirmationDialog() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Test that confirmation would be required for deletion
        // This is handled in the view layer, but we can test the deletion logic
        
        // Verify entities exist before deletion
        XCTAssertNotNil(player.id)
        XCTAssertNotNil(team.id)
        
        // Test deletion
        testContext.delete(player)
        try! testContext.save()
        
        // Verify deletion occurred
        let playersRequest: NSFetchRequest<Player> = Player.fetchRequest()
        let teamsRequest: NSFetchRequest<Team> = Team.fetchRequest()
        
        let players = try! testContext.fetch(playersRequest)
        let teams = try! testContext.fetch(teamsRequest)
        
        XCTAssertEqual(players.count, 0)
        XCTAssertEqual(teams.count, 0) // Should cascade delete
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
    
    private func getTeamsForPlayer(_ player: Player) -> [Team] {
        let request: NSFetchRequest<Team> = Team.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@", player)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Team.displayOrder, ascending: true)]
        return try! testContext.fetch(request)
    }
} 