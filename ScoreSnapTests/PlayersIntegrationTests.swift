//
//  PlayersIntegrationTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import XCTest
import SwiftUI
import CoreData
import Combine
@testable import ScoreSnap

@MainActor
class PlayersIntegrationTests: XCTestCase {
    
    var testContext: NSManagedObjectContext!
    var appContext: AppContext!
    var viewModel: PlayersViewModel!
    var cancellables: Set<AnyCancellable>!
    
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
        viewModel = PlayersViewModel(viewContext: testContext)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables?.removeAll()
        testContext = nil
        appContext = nil
        viewModel = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - AppContext Integration Tests
    
    func testPlayerSelectionPropagation() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        try! testContext.save()
        
        // Test initial state
        XCTAssertNil(appContext.currentPlayer)
        
        // Select player in PlayersView (simulated)
        appContext.switchToPlayer(player1)
        XCTAssertEqual(appContext.currentPlayer, player1)
        
        // Verify AppContext was updated
        XCTAssertEqual(appContext.currentPlayer?.id, player1.id)
        XCTAssertEqual(appContext.currentPlayer?.name, "Player 1")
        
        // Switch to different player
        appContext.switchToPlayer(player2)
        XCTAssertEqual(appContext.currentPlayer, player2)
        XCTAssertNotEqual(appContext.currentPlayer, player1)
    }
    
    func testTeamSelectionPropagation() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team1 = createTestTeam(name: "Team 1", player: player, displayOrder: 0)
        let team2 = createTestTeam(name: "Team 2", player: player, displayOrder: 1)
        try! testContext.save()
        
        // Set initial player selection
        appContext.switchToPlayer(player)
        XCTAssertEqual(appContext.currentPlayer, player)
        XCTAssertEqual(appContext.currentTeam, team1) // Should default to first team
        
        // Switch team selection
        appContext.switchToTeam(team2)
        XCTAssertEqual(appContext.currentTeam, team2)
        XCTAssertEqual(appContext.currentPlayer, player) // Player should remain same
        
        // Verify AppContext was updated
        XCTAssertEqual(appContext.currentTeam?.id, team2.id)
        XCTAssertEqual(appContext.currentTeam?.name, "Team 2")
    }
    
    func testContextBidirectionalSync() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        let team1 = createTestTeam(name: "Team 1", player: player1, displayOrder: 0)
        let team2 = createTestTeam(name: "Team 2", player: player2, displayOrder: 0)
        try! testContext.save()
        
        // Set initial context
        appContext.switchToPlayerAndTeam(player1, team1)
        XCTAssertEqual(appContext.currentPlayer, player1)
        XCTAssertEqual(appContext.currentTeam, team1)
        
        // Simulate change from another view
        appContext.switchToPlayerAndTeam(player2, team2)
        XCTAssertEqual(appContext.currentPlayer, player2)
        XCTAssertEqual(appContext.currentTeam, team2)
        
        // Verify PlayersView would reflect the change
        // (In real app, PlayersView would observe AppContext changes)
        XCTAssertEqual(appContext.currentPlayer?.id, player2.id)
        XCTAssertEqual(appContext.currentTeam?.id, team2.id)
    }
    
    func testContextPersistence() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Set context
        appContext.switchToPlayerAndTeam(player, team)
        
        // Wait for persistence
        let expectation = XCTestExpectation(description: "Context persisted")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Create new AppContext to simulate app restart
        let newAppContext = AppContext(viewContext: testContext)
        
        // Verify context was restored
        XCTAssertEqual(newAppContext.currentPlayer?.id, player.id)
        XCTAssertEqual(newAppContext.currentTeam?.id, team.id)
    }
    
    func testInvalidContextRecovery() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Set context
        appContext.switchToPlayerAndTeam(player, team)
        
        // Delete the entities
        testContext.delete(player)
        testContext.delete(team)
        try! testContext.save()
        
        // Create new AppContext - should handle missing entities gracefully
        let newAppContext = AppContext(viewContext: testContext)
        
        XCTAssertNil(newAppContext.currentPlayer)
        XCTAssertNil(newAppContext.currentTeam)
        XCTAssertTrue(newAppContext.needsSetup)
    }
    
    // MARK: - Cross-View Coordination Tests
    
    func testHomeViewUpdates() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        let game = createTestGame(team: team)
        try! testContext.save()
        
        // Set context
        appContext.switchToPlayerAndTeam(player, team)
        
        // Verify HomeView would show correct data
        XCTAssertEqual(appContext.currentPlayer?.name, "Test Player")
        XCTAssertEqual(appContext.currentTeam?.name, "Test Team")
        
        // Verify team has games
        let teamGames = getGamesForTeam(team)
        XCTAssertEqual(teamGames.count, 1)
        XCTAssertEqual(teamGames.first?.team, team)
    }
    
    func testContextConflictResolution() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        _ = createTestTeam(name: "Team 1", player: player1, displayOrder: 0)
        _ = createTestTeam(name: "Team 2", player: player2, displayOrder: 0)
        try! testContext.save()
        
        // Simulate concurrent context changes
        let group = DispatchGroup()
        
        // Change 1: Switch to player 1
        group.enter()
        DispatchQueue.main.async {
            self.appContext.switchToPlayer(player1)
            group.leave()
        }
        
        // Change 2: Switch to player 2
        group.enter()
        DispatchQueue.main.async {
            self.appContext.switchToPlayer(player2)
            group.leave()
        }
        
        // Wait for both changes
        let expectation = XCTestExpectation(description: "Concurrent changes completed")
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify final state is consistent
        let finalPlayer = appContext.currentPlayer
        XCTAssertNotNil(finalPlayer)
        XCTAssertTrue(finalPlayer == player1 || finalPlayer == player2)
    }
    
    func testContextValidation() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        let team1 = createTestTeam(name: "Team 1", player: player1, displayOrder: 0)
        let team2 = createTestTeam(name: "Team 2", player: player2, displayOrder: 0)
        try! testContext.save()
        
        // Test invalid team selection (team doesn't belong to current player)
        appContext.switchToPlayer(player1)
        XCTAssertEqual(appContext.currentPlayer, player1)
        XCTAssertEqual(appContext.currentTeam, team1) // Should default to first team
        
        // Try to select team that doesn't belong to current player
        appContext.switchToTeam(team2)
        
        // Should not switch because team doesn't belong to current player
        XCTAssertEqual(appContext.currentPlayer, player1)
        XCTAssertEqual(appContext.currentTeam, team1) // Should remain unchanged
    }
    
    // MARK: - Core Data Integration Tests
    
    func testPlayerPersistence() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        player.playerColor = Color.blue.toHex()
        player.sport = "Basketball"
        try! testContext.save()
        
        // Verify player was saved
        let playersRequest: NSFetchRequest<Player> = Player.fetchRequest()
        let players = try! testContext.fetch(playersRequest)
        XCTAssertEqual(players.count, 1)
        XCTAssertEqual(players.first?.name, "Test Player")
        XCTAssertEqual(players.first?.playerColor, Color.blue.toHex())
        
        // Create new viewModel to simulate app restart
        let newViewModel = PlayersViewModel(viewContext: testContext)
        
        // Verify player was loaded
        XCTAssertEqual(newViewModel.players.count, 1)
        XCTAssertEqual(newViewModel.players.first?.name, "Test Player")
    }
    
    func testTeamPersistence() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        team.teamColor = Color.red.toHex()
        team.sport = "Basketball"
        try! testContext.save()
        
        // Verify team was saved with player association
        let teamsRequest: NSFetchRequest<Team> = Team.fetchRequest()
        let teams = try! testContext.fetch(teamsRequest)
        XCTAssertEqual(teams.count, 1)
        XCTAssertEqual(teams.first?.name, "Test Team")
        XCTAssertEqual(teams.first?.player, player)
        
        // Create new viewModel to simulate app restart
        let newViewModel = PlayersViewModel(viewContext: testContext)
        
        // Verify team was loaded
        XCTAssertEqual(newViewModel.teams.count, 1)
        XCTAssertEqual(newViewModel.teams.first?.name, "Test Team")
        
        // Verify player association maintained
        let playerTeams = newViewModel.teamsForPlayer(player)
        XCTAssertEqual(playerTeams.count, 1)
        XCTAssertEqual(playerTeams.first?.name, "Test Team")
    }
    
    func testReorderPersistence() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        let player3 = createTestPlayer(name: "Player 3", displayOrder: 2)
        try! testContext.save()
        
        // Reorder players
        viewModel.movePlayer(from: IndexSet(integer: 2), to: 0)
        
        // Verify reorder was applied
        XCTAssertEqual(viewModel.players[0].name, "Player 3")
        XCTAssertEqual(viewModel.players[1].name, "Player 1")
        XCTAssertEqual(viewModel.players[2].name, "Player 2")
        
        // Create new viewModel to simulate app restart
        let newViewModel = PlayersViewModel(viewContext: testContext)
        
        // Verify reorder persisted
        XCTAssertEqual(newViewModel.players[0].name, "Player 3")
        XCTAssertEqual(newViewModel.players[1].name, "Player 1")
        XCTAssertEqual(newViewModel.players[2].name, "Player 2")
    }
    
    func testColorPersistence() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        
        // Set custom colors
        let playerColor = Color.purple
        let teamColor = Color.orange
        
        player.playerColor = playerColor.toHex()
        team.teamColor = teamColor.toHex()
        
        try! testContext.save()
        
        // Create new viewModel to simulate app restart
        let newViewModel = PlayersViewModel(viewContext: testContext)
        
        // Verify colors persisted
        let loadedPlayer = newViewModel.players.first
        let loadedTeam = newViewModel.teams.first
        
        XCTAssertEqual(loadedPlayer?.playerColor, playerColor.toHex())
        XCTAssertEqual(loadedTeam?.teamColor, teamColor.toHex())
        
        // Test color retrieval
        let retrievedPlayerColor = newViewModel.getPlayerColor(loadedPlayer!)
        let retrievedTeamColor = newViewModel.getTeamColor(loadedTeam!)
        
        XCTAssertNotNil(retrievedPlayerColor)
        XCTAssertNotNil(retrievedTeamColor)
    }
    
    func testRelationshipIntegrity() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        _ = createTestGame(team: team)
        try! testContext.save()
        
        // Verify relationships
        XCTAssertEqual(player.teams?.count, 1)
        XCTAssertEqual(team.games?.count, 1)
        XCTAssertEqual(team.player, player)
        
        // Create new viewModel to simulate app restart
        let newViewModel = PlayersViewModel(viewContext: testContext)
        
        // Verify relationships maintained
        let loadedPlayer = newViewModel.players.first
        let loadedTeam = newViewModel.teams.first
        
        XCTAssertNotNil(loadedPlayer)
        XCTAssertNotNil(loadedTeam)
        XCTAssertEqual(loadedTeam?.player, loadedPlayer)
    }
    
    // MARK: - Cascade Operations Tests
    
    func testPlayerCascadeDelete() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        _ = createTestGame(team: team)
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
        let gamesRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let games = try! testContext.fetch(gamesRequest)
        XCTAssertEqual(games.count, 0)
    }
    
    func testTeamCascadeDelete() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        _ = createTestGame(team: team)
        try! testContext.save()
        
        // Verify initial state
        XCTAssertEqual(viewModel.teams.count, 1)
        
        // Delete team
        viewModel.deleteTeam(team)
        
        // Verify cascade deletion
        XCTAssertEqual(viewModel.teams.count, 0)
        
        // Verify game was also deleted
        let gamesRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let games = try! testContext.fetch(gamesRequest)
        XCTAssertEqual(games.count, 0)
        
        // Verify player still exists
        XCTAssertEqual(viewModel.players.count, 1)
    }
    
    func testCascadeTransactionIntegrity() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        _ = createTestGame(team: team)
        try! testContext.save()
        
        // Verify initial state
        XCTAssertEqual(viewModel.players.count, 1)
        XCTAssertEqual(viewModel.teams.count, 1)
        
        // Test cascade delete transaction
        viewModel.deletePlayer(player)
        
        // Verify all related entities were deleted
        XCTAssertEqual(viewModel.players.count, 0)
        XCTAssertEqual(viewModel.teams.count, 0)
        
        let gamesRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let games = try! testContext.fetch(gamesRequest)
        XCTAssertEqual(games.count, 0)
        
        // Verify no orphaned entities
        let allTeamsRequest: NSFetchRequest<Team> = Team.fetchRequest()
        let allTeams = try! testContext.fetch(allTeamsRequest)
        XCTAssertEqual(allTeams.count, 0)
        
        let allGamesRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let allGames = try! testContext.fetch(allGamesRequest)
        XCTAssertEqual(allGames.count, 0)
    }
    
    func testCascadePerformance() {
        // Create large dataset for performance testing
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let teams = (0..<10).map { createTestTeam(name: "Team \($0)", player: player, displayOrder: Int32($0)) }
        _ = teams.flatMap { team in
            (0..<10).map { _ in createTestGame(team: team) }
        }
        
        try! testContext.save()
        
        // Verify initial state
        XCTAssertEqual(viewModel.players.count, 1)
        XCTAssertEqual(viewModel.teams.count, 10)
        
        // Test cascade delete performance
        measure {
            viewModel.deletePlayer(player)
        }
        
        // Verify all entities were deleted
        XCTAssertEqual(viewModel.players.count, 0)
        XCTAssertEqual(viewModel.teams.count, 0)
        
        let gamesRequest: NSFetchRequest<Game> = Game.fetchRequest()
        let games = try! testContext.fetch(gamesRequest)
        XCTAssertEqual(games.count, 0)
    }
    
    // MARK: - Concurrent Data Access Tests
    
    func testMultiViewDataSafety() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        _ = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Create multiple viewModels (simulating multiple views)
        let viewModel1 = PlayersViewModel(viewContext: testContext)
        let viewModel2 = PlayersViewModel(viewContext: testContext)
        
        // Test concurrent updates
        let group = DispatchGroup()
        
        // Update 1: Change player name
        group.enter()
        DispatchQueue.main.async {
            viewModel1.updatePlayer(player, name: "Updated Player 1", color: .red, sport: "Basketball")
            group.leave()
        }
        
        // Update 2: Change player name
        group.enter()
        DispatchQueue.main.async {
            viewModel2.updatePlayer(player, name: "Updated Player 2", color: .blue, sport: "Basketball")
            group.leave()
        }
        
        // Wait for both updates
        let expectation = XCTestExpectation(description: "Concurrent updates completed")
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify final state is consistent
        XCTAssertNotNil(player.name)
        XCTAssertTrue(player.name == "Updated Player 1" || player.name == "Updated Player 2")
    }
    
    func testBackgroundSaveHandling() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        // Simulate external update
        player.name = "Background Updated Player"
        try! testContext.save()
        
        // Verify the change was saved
        XCTAssertEqual(player.name, "Background Updated Player")
        
        // Refresh viewModel to ensure it picks up external changes
        viewModel.refreshData()
        XCTAssertEqual(viewModel.players.first?.name, "Background Updated Player")
    }
    
    func testDataRefresh() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        // Verify initial state
        XCTAssertEqual(viewModel.players.count, 1)
        XCTAssertEqual(viewModel.players.first?.name, "Test Player")
        
        // Update player externally
        player.name = "Externally Updated Player"
        try! testContext.save()
        
        // Refresh viewModel data
        viewModel.refreshData()
        
        // Verify viewModel reflects external changes
        XCTAssertEqual(viewModel.players.count, 1)
        XCTAssertEqual(viewModel.players.first?.name, "Externally Updated Player")
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
    
    private func getGamesForTeam(_ team: Team) -> [Game] {
        let request: NSFetchRequest<Game> = Game.fetchRequest()
        request.predicate = NSPredicate(format: "team == %@", team)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Game.gameDate, ascending: false)]
        return try! testContext.fetch(request)
    }
} 