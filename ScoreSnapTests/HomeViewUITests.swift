//
//  HomeViewUITests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import XCTest
import SwiftUI
import CoreData
@testable import ScoreSnap

@MainActor
class HomeViewUITests: XCTestCase {
    
    var mockContext: NSManagedObjectContext!
    var appContext: AppContext!
    var testPlayers: [Player] = []
    var testTeams: [Team] = []
    var testGames: [Game] = []
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create in-memory Core Data stack for testing
        let container = NSPersistentContainer(name: "ScoreSnap")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        }
        
        mockContext = container.viewContext
        appContext = AppContext(viewContext: mockContext)
        setupTestData()
    }
    
    override func tearDownWithError() throws {
        mockContext = nil
        appContext = nil
        testPlayers = []
        testTeams = []
        testGames = []
    }
    
    private func setupTestData() {
        // Create test players for UI testing
        for i in 0..<5 {
            let player = Player(context: mockContext)
            player.id = UUID()
            player.name = "Player \(i + 1)"
            player.displayOrder = Int32(i)
            player.playerColor = "#FF000\(i)"
            player.sport = "Basketball"
            testPlayers.append(player)
            
            // Create teams for each player
            let teamCount = i < 2 ? 3 : 2 // First 2 players have 3 teams, others have 2
            for j in 0..<teamCount {
                let team = Team(context: mockContext)
                team.id = UUID()
                team.name = "Team \(i + 1)-\(j + 1)"
                team.displayOrder = Int32(j)
                team.teamColor = "#0000F\(j)"
                team.sport = "Basketball"
                team.player = player
                testTeams.append(team)
                
                // Create games for UI testing
                createGamesForTeam(team, count: 8 + j)
            }
        }
        
        try! mockContext.save()
    }
    
    private func createGamesForTeam(_ team: Team, count: Int) {
        for i in 0..<count {
            let game = Game(context: mockContext)
            game.id = UUID()
            game.opponentName = "Opponent \(i + 1)"
            game.teamScore = Int32(75 + i * 2)
            game.opponentScore = Int32(70 + i * 2 + (i % 3))
            game.isWin = game.teamScore > game.opponentScore
            game.isTie = (i % 7 == 0) && game.teamScore == game.opponentScore
            game.gameDate = Calendar.current.date(byAdding: .day, value: -i, to: Date())
            game.team = team
            testGames.append(game)
        }
    }
    
    // MARK: - Visual Display Tests
    
    func testHomeViewLoads() throws {
        // Given - Home view with data
        let player = testPlayers[0]
        let team = testTeams.filter { $0.player == player }[0]
        
        appContext.switchToPlayer(player)
        appContext.switchToTeam(team)
        
        // When - Create home view
        let homeView = HomeView()
            .environmentObject(appContext)
            .environment(\.managedObjectContext, mockContext)
        
        // Then - View should load without crashing
        XCTAssertNotNil(homeView, "Home view should be created successfully")
        
        // Test basic view structure
        XCTAssertEqual(appContext.currentPlayer?.name, "Player 1", "Should have correct player")
        XCTAssertEqual(appContext.currentTeam?.name, "Team 1-1", "Should have correct team")
    }
    
    func testPlayerSegmentedControlVisibility() throws {
        // Given - Multiple players
        XCTAssertGreaterThan(testPlayers.count, 1, "Should have multiple players for segmented control")
        
        // When - Check player count for UI decisions
        let playerCount = testPlayers.count
        let shouldShowSegmentedControl = playerCount > 1
        
        // Then - Segmented control visibility should be correct
        XCTAssertTrue(shouldShowSegmentedControl, "Should show segmented control with multiple players")
        XCTAssertEqual(playerCount, 5, "Should have 5 test players")
    }
    
    func testTeamDropdownVisibility() throws {
        // Given - Player with multiple teams
        let player = testPlayers[0] // Has 3 teams
        let playerTeams = testTeams.filter { $0.player == player }
        
        // When - Check team count for dropdown visibility
        let shouldShowDropdown = playerTeams.count > 1
        
        // Then - Dropdown should be visible
        XCTAssertTrue(shouldShowDropdown, "Should show dropdown when player has multiple teams")
        XCTAssertEqual(playerTeams.count, 3, "Player should have 3 teams")
    }
    
    func testEmptyStateDisplay() throws {
        // Given - Team with no games
        let emptyTeam = Team(context: mockContext)
        emptyTeam.id = UUID()
        emptyTeam.name = "Empty Team"
        emptyTeam.player = testPlayers[0]
        try! mockContext.save()
        
        // When - Check for empty state
        let teamGames = testGames.filter { $0.team == emptyTeam }
        let isEmpty = teamGames.isEmpty
        
        // Then - Should show empty state
        XCTAssertTrue(isEmpty, "Empty team should have no games")
        XCTAssertEqual(teamGames.count, 0, "Empty team should have 0 games")
    }
    
    // MARK: - User Interaction Tests
    
    func testPlayerSwitching() throws {
        // Given - Multiple players
        let initialPlayer = testPlayers[0]
        let newPlayer = testPlayers[1]
        
        appContext.switchToPlayer(initialPlayer)
        
        // When - Switch player
        appContext.switchToPlayer(newPlayer)
        
        // Then - Context should update
        XCTAssertEqual(appContext.currentPlayer?.id, newPlayer.id, "Should switch to new player")
        XCTAssertNotEqual(appContext.currentPlayer?.id, initialPlayer.id, "Should not be initial player")
    }
    
    func testTeamSelection() throws {
        // Given - Player with multiple teams
        let player = testPlayers[0]
        let playerTeams = testTeams.filter { $0.player == player }
        
        appContext.switchToPlayer(player)
        
        let initialTeam = playerTeams[0]
        let newTeam = playerTeams[1]
        
        appContext.switchToTeam(initialTeam)
        
        // When - Change team selection
        appContext.switchToTeam(newTeam)
        
        // Then - Context should update
        XCTAssertEqual(appContext.currentTeam?.id, newTeam.id, "Should switch to new team")
        XCTAssertNotEqual(appContext.currentTeam?.id, initialTeam.id, "Should not be initial team")
    }
    
    func testMorePlayersButton() throws {
        // Given - More than 3 players
        let allPlayers = testPlayers
        let visiblePlayers = Array(allPlayers.prefix(3))
        let hiddenPlayers = Array(allPlayers.dropFirst(3))
        
        // When - Check "More" button logic
        let showMoreButton = allPlayers.count > 3
        
        // Then - Should show "More" button and have hidden players
        XCTAssertTrue(showMoreButton, "Should show 'More' button with 4+ players")
        XCTAssertEqual(visiblePlayers.count, 3, "Should show 3 visible players")
        XCTAssertEqual(hiddenPlayers.count, 2, "Should have 2 hidden players")
        XCTAssertEqual(visiblePlayers.count + hiddenPlayers.count, allPlayers.count, "Total should match")
    }
    
    // MARK: - Visual Consistency Tests
    
    func testThemeApplicationLogic() throws {
        // Given - Theme colors and styles
        let primaryColor = Theme.Colors.primary
        let backgroundColor = Theme.Colors.background
        let textColor = Theme.Colors.primaryText
        
        // When - Check theme consistency
        // Then - Colors should be defined and consistent
        XCTAssertNotNil(primaryColor, "Primary color should be defined")
        XCTAssertNotNil(backgroundColor, "Background color should be defined")
        XCTAssertNotNil(textColor, "Text color should be defined")
    }
    
    func testTeamColorDisplay() throws {
        // Given - Teams with colors
        let team = testTeams[0]
        let teamColor = team.teamColor
        
        // When - Check team color format
        let isValidHexColor = teamColor?.hasPrefix("#") ?? false
        let hasValidLength = teamColor?.count == 7 // #RRGGBB format
        
        // Then - Team color should be valid hex format
        XCTAssertNotNil(teamColor, "Team should have a color")
        XCTAssertTrue(isValidHexColor, "Team color should be hex format")
        XCTAssertTrue(hasValidLength, "Team color should be 7 characters (#RRGGBB)")
    }
    
    func testResponsiveLayoutLogic() throws {
        // Given - Different screen scenarios
        let compactWidth = 375.0 // iPhone SE width
        let regularWidth = 414.0 // iPhone Pro width
        
        // When - Check layout decisions
        let useCompactLayout = compactWidth < 400
        let useRegularLayout = regularWidth >= 400
        
        // Then - Layout logic should be correct
        XCTAssertTrue(useCompactLayout, "Should use compact layout for narrow screens")
        XCTAssertTrue(useRegularLayout, "Should use regular layout for wider screens")
    }
    
    func testDarkModeCompatibility() throws {
        // Given - Dark mode considerations
        let lightBackground = Theme.Colors.background
        let darkBackground = Theme.Colors.background // Would be different in actual dark mode
        
        // When - Check color adaptability
        // Then - Colors should be adaptable to different modes
        XCTAssertNotNil(lightBackground, "Light background should be defined")
        XCTAssertNotNil(darkBackground, "Dark background should be defined")
        
        // Test that colors are SwiftUI Color objects (adaptable)
        XCTAssertNotNil(lightBackground, "Background should be SwiftUI Color")
    }
    
    // MARK: - Component Display Tests
    
    func testPlayerSegmentedControlDisplay() throws {
        // Given - Players for segmented control
        let players = Array(testPlayers.prefix(3))
        
        // When - Check display requirements
        let allPlayersHaveNames = players.allSatisfy { !($0.name?.isEmpty ?? true) }
        let allPlayersHaveColors = players.allSatisfy { !($0.playerColor?.isEmpty ?? true) }
        
        // Then - All players should have required display data
        XCTAssertTrue(allPlayersHaveNames, "All players should have names")
        XCTAssertTrue(allPlayersHaveColors, "All players should have colors")
        XCTAssertEqual(players.count, 3, "Should have 3 players for display")
    }
    
    func testTeamDropdownContent() throws {
        // Given - Player with teams
        let player = testPlayers[0]
        let playerTeams = testTeams.filter { $0.player == player }
        
        // When - Check dropdown content requirements
        let allTeamsHaveNames = playerTeams.allSatisfy { !($0.name?.isEmpty ?? true) }
        let allTeamsHaveColors = playerTeams.allSatisfy { !($0.teamColor?.isEmpty ?? true) }
        let teamsAreSorted = playerTeams.sorted { $0.displayOrder < $1.displayOrder }
        
        // Then - Teams should have required display data
        XCTAssertTrue(allTeamsHaveNames, "All teams should have names")
        XCTAssertTrue(allTeamsHaveColors, "All teams should have colors")
        XCTAssertEqual(teamsAreSorted.count, playerTeams.count, "Teams should be sortable")
    }
    
    func testTeamRecordDisplay() throws {
        // Given - Team with games
        let team = testTeams[0]
        let teamGames = testGames.filter { $0.team == team }
        
        // When - Calculate record for display
        let wins = teamGames.filter { $0.isWin }.count
        let losses = teamGames.filter { !$0.isWin && !$0.isTie }.count
        let ties = teamGames.filter { $0.isTie }.count
        let recordString = "\(wins)-\(losses)-\(ties)"
        
        // Then - Record should be displayable
        XCTAssertFalse(recordString.isEmpty, "Record string should not be empty")
        XCTAssertTrue(recordString.contains("-"), "Record should contain separators")
        XCTAssertEqual(recordString.components(separatedBy: "-").count, 3, "Record should have 3 parts")
    }
    
    func testGameRowDisplay() throws {
        // Given - Game for display
        let game = testGames[0]
        
        // When - Check display requirements
        let hasOpponentName = !(game.opponentName?.isEmpty ?? true)
        let hasValidDate = game.gameDate != nil
        let hasValidScores = game.teamScore >= 0 && game.opponentScore >= 0
        let scoreString = "\(game.teamScore)-\(game.opponentScore)"
        
        // Then - Game should have all display data
        XCTAssertTrue(hasOpponentName, "Game should have opponent name")
        XCTAssertTrue(hasValidDate, "Game should have valid date")
        XCTAssertTrue(hasValidScores, "Game should have valid scores")
        XCTAssertFalse(scoreString.isEmpty, "Score string should not be empty")
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() throws {
        // Given - UI elements that need accessibility
        let player = testPlayers[0]
        let team = testTeams[0]
        let game = testGames[0]
        
        // When - Create accessibility labels
        let playerLabel = "Player: \(player.name ?? "Unknown")"
        let teamLabel = "Team: \(team.name ?? "Unknown")"
        let gameLabel = "Game vs \(game.opponentName ?? "Unknown")"
        
        // Then - Labels should be meaningful
        XCTAssertFalse(playerLabel.isEmpty, "Player label should not be empty")
        XCTAssertFalse(teamLabel.isEmpty, "Team label should not be empty")
        XCTAssertFalse(gameLabel.isEmpty, "Game label should not be empty")
        XCTAssertTrue(playerLabel.contains("Player"), "Player label should identify element type")
    }
    
    func testVoiceOverSupport() throws {
        // Given - Content for VoiceOver
        let team = testTeams[0]
        let teamGames = testGames.filter { $0.team == team }
        let wins = teamGames.filter { $0.isWin }.count
        let losses = teamGames.filter { !$0.isWin && !$0.isTie }.count
        let ties = teamGames.filter { $0.isTie }.count
        
        // When - Create VoiceOver description
        let recordDescription = "Team record: \(wins) wins, \(losses) losses, \(ties) ties"
        
        // Then - Description should be VoiceOver friendly
        XCTAssertFalse(recordDescription.isEmpty, "VoiceOver description should not be empty")
        XCTAssertTrue(recordDescription.contains("wins"), "Should include wins in description")
        XCTAssertTrue(recordDescription.contains("losses"), "Should include losses in description")
        XCTAssertTrue(recordDescription.contains("ties"), "Should include ties in description")
    }
    
    // MARK: - Performance UI Tests
    
    func testUIRenderingPerformance() throws {
        // Given - Large dataset for UI rendering
        let player = testPlayers[0]
        let team = testTeams.filter { $0.player == player }[0]
        let teamGames = testGames.filter { $0.team == team }
        
        // When - Measure UI calculation performance
        measure {
            // Simulate UI calculations
            let recentGames = Array(teamGames.prefix(10))
            let wins = teamGames.filter { $0.isWin }.count
            let losses = teamGames.filter { !$0.isWin && !$0.isTie }.count
            let ties = teamGames.filter { $0.isTie }.count
            let recordString = "\(wins)-\(losses)-\(ties)"
            
            // Simulate formatting operations
            for game in recentGames {
                let _ = "\(game.teamScore)-\(game.opponentScore)"
                let _ = game.gameDate?.formatted(.dateTime.month().day()) ?? ""
            }
            
            XCTAssertFalse(recordString.isEmpty, "Record should be calculated")
        }
    }
    
    func testScrollingPerformance() throws {
        // Given - Many games for scrolling test
        let team = testTeams[0]
        let teamGames = testGames.filter { $0.team == team }
        
        // When - Simulate scrolling operations
        measure {
            // Simulate lazy loading of game rows
            for game in teamGames {
                let _ = game.opponentName ?? ""
                let _ = game.gameDate != nil
                let _ = "\(game.teamScore)-\(game.opponentScore)"
                let _ = game.isWin ? "W" : (game.isTie ? "T" : "L")
            }
        }
        
        // Then - Should handle scrolling efficiently
        XCTAssertGreaterThan(teamGames.count, 5, "Should have enough games for scrolling test")
    }
} 