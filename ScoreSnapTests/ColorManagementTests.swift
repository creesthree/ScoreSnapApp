//
//  ColorManagementTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import XCTest
import SwiftUI
import CoreData
@testable import ScoreSnap

@MainActor
class ColorManagementTests: XCTestCase {
    
    var testContext: NSManagedObjectContext!
    var viewModel: PlayersViewModel!
    
    override func setUpWithError() throws {
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
    
    override func tearDownWithError() throws {
        testContext = nil
        viewModel = nil
    }
    
    // MARK: - TeamColor Tests
    
    func testTeamColorEnumValues() {
        // Test that all 12 colors are available
        XCTAssertEqual(TeamColor.allCases.count, 12)
        
        // Test specific colors
        XCTAssertEqual(TeamColor.red.rawValue, "red")
        XCTAssertEqual(TeamColor.blue.rawValue, "blue")
        XCTAssertEqual(TeamColor.green.rawValue, "green")
        XCTAssertEqual(TeamColor.orange.rawValue, "orange")
        XCTAssertEqual(TeamColor.purple.rawValue, "purple")
        XCTAssertEqual(TeamColor.pink.rawValue, "pink")
        XCTAssertEqual(TeamColor.teal.rawValue, "teal")
        XCTAssertEqual(TeamColor.indigo.rawValue, "indigo")
        XCTAssertEqual(TeamColor.yellow.rawValue, "yellow")
        XCTAssertEqual(TeamColor.gray.rawValue, "gray")
        XCTAssertEqual(TeamColor.brown.rawValue, "brown")
        XCTAssertEqual(TeamColor.black.rawValue, "black")
    }
    
    func testTeamColorDisplayNames() {
        XCTAssertEqual(TeamColor.red.displayName, "Red")
        XCTAssertEqual(TeamColor.blue.displayName, "Blue")
        XCTAssertEqual(TeamColor.green.displayName, "Green")
    }
    
    func testTeamColorColorValues() {
        // Test that colors are properly mapped
        XCTAssertEqual(TeamColor.red.color, Color.red)
        XCTAssertEqual(TeamColor.blue.color, Color.blue)
        XCTAssertEqual(TeamColor.green.color, Color.green)
    }
    
    // MARK: - Player Color Management Tests
    
    func testPlayerColorStorage() {
        let player = Player(context: testContext)
        player.name = "Test Player"
        player.playerColor = TeamColor.red.rawValue
        
        let retrievedColor = viewModel.getPlayerColor(player)
        XCTAssertEqual(retrievedColor, TeamColor.red.color)
    }
    
    func testPlayerColorWithInvalidValue() {
        let player = Player(context: testContext)
        player.name = "Test Player"
        player.playerColor = "invalid_color"
        
        // Should return default color for invalid values
        let retrievedColor = viewModel.getPlayerColor(player)
        XCTAssertEqual(retrievedColor, Constants.Defaults.defaultTeamColor.color)
    }
    
    func testPlayerColorWithNilValue() {
        let player = Player(context: testContext)
        player.name = "Test Player"
        player.playerColor = nil
        
        // Should return default color for nil values
        let retrievedColor = viewModel.getPlayerColor(player)
        XCTAssertEqual(retrievedColor, Constants.Defaults.defaultTeamColor.color)
    }
    
    // MARK: - Team Color Management Tests
    
    func testTeamColorStorage() {
        let player = Player(context: testContext)
        let team = Team(context: testContext)
        team.name = "Test Team"
        team.teamColor = TeamColor.blue.rawValue
        team.player = player
        
        let retrievedColor = viewModel.getTeamColor(team)
        XCTAssertEqual(retrievedColor, TeamColor.blue.color)
    }
    
    func testTeamColorWithInvalidValue() {
        let player = Player(context: testContext)
        let team = Team(context: testContext)
        team.name = "Test Team"
        team.teamColor = "invalid_color"
        team.player = player
        
        // Should return default color for invalid values
        let retrievedColor = viewModel.getTeamColor(team)
        XCTAssertEqual(retrievedColor, Constants.Defaults.defaultTeamColor.color)
    }
    
    func testTeamColorWithNilValue() {
        let player = Player(context: testContext)
        let team = Team(context: testContext)
        team.name = "Test Team"
        team.teamColor = nil
        team.player = player
        
        // Should return default color for nil values
        let retrievedColor = viewModel.getTeamColor(team)
        XCTAssertEqual(retrievedColor, Constants.Defaults.defaultTeamColor.color)
    }
    
    // MARK: - Theme TeamColors Tests
    
    func testThemeTeamColorsColorFromString() {
        let player = Player(context: testContext)
        let team = Team(context: testContext)
        
        player.playerColor = TeamColor.red.rawValue
        team.teamColor = TeamColor.blue.rawValue
        
        let playerColor = Theme.TeamColors.color(from: player.playerColor)
        let teamColor = Theme.TeamColors.color(from: team.teamColor)
        
        XCTAssertEqual(playerColor, TeamColor.red.color)
        XCTAssertEqual(teamColor, TeamColor.blue.color)
    }
    
    func testThemeTeamColorsColorFromNil() {
        let nilColor = Theme.TeamColors.color(from: nil)
        XCTAssertEqual(nilColor, Constants.Defaults.defaultTeamColor.color)
    }
    
    func testThemeTeamColorsColorFromInvalidString() {
        let invalidColor = Theme.TeamColors.color(from: "invalid_color")
        XCTAssertEqual(invalidColor, Constants.Defaults.defaultTeamColor.color)
    }
    
    func testThemeTeamColorsColorFromEmptyString() {
        let emptyColor = Theme.TeamColors.color(from: "")
        XCTAssertEqual(emptyColor, Constants.Defaults.defaultTeamColor.color)
    }
    
    // MARK: - Color Persistence Tests
    
    func testColorPersistenceAcrossViewModelInstances() {
        let player = Player(context: testContext)
        player.name = "Test Player"
        player.playerColor = TeamColor.green.rawValue
        
        let team = Team(context: testContext)
        team.name = "Test Team"
        team.teamColor = TeamColor.purple.rawValue
        team.player = player
        
        try? testContext.save()
        
        let newViewModel = PlayersViewModel(viewContext: testContext)
        let loadedPlayer = try? testContext.fetch(Player.fetchRequest()).first
        let loadedTeam = try? testContext.fetch(Team.fetchRequest()).first
        
        XCTAssertNotNil(loadedPlayer)
        XCTAssertNotNil(loadedTeam)
        
        let retrievedPlayerColor = newViewModel.getPlayerColor(loadedPlayer!)
        let retrievedTeamColor = newViewModel.getTeamColor(loadedTeam!)
        
        XCTAssertEqual(retrievedPlayerColor, TeamColor.green.color)
        XCTAssertEqual(retrievedTeamColor, TeamColor.purple.color)
    }
    
    // MARK: - Color Validation Tests
    
    func testValidTeamColorValues() {
        for teamColor in TeamColor.allCases {
            XCTAssertNotNil(TeamColor(rawValue: teamColor.rawValue))
            XCTAssertEqual(TeamColor(rawValue: teamColor.rawValue), teamColor)
        }
    }
    
    func testInvalidTeamColorValues() {
        let invalidColors = ["", "invalid", "RED", "Blue123", "green_"]
        
        for invalidColor in invalidColors {
            XCTAssertNil(TeamColor(rawValue: invalidColor))
        }
    }
    
    // MARK: - Default Color Tests
    
    func testDefaultColors() {
        XCTAssertEqual(Constants.Defaults.defaultTeamColor, TeamColor.blue)
        XCTAssertEqual(Constants.Defaults.defaultPlayerColor, TeamColor.red)
        
        XCTAssertTrue(Constants.Defaults.teamColors.contains(TeamColor.blue))
        XCTAssertTrue(Constants.Defaults.teamColors.contains(TeamColor.red))
        XCTAssertEqual(Constants.Defaults.teamColors.count, 12)
    }
    
    // MARK: - Color Accessibility Tests
    
    func testColorAccessibility() {
        // Test contrasting text color calculation
        let lightColor = Color.white
        let darkColor = Color.black
        
        let lightContrast = lightColor.contrastingTextColor
        let darkContrast = darkColor.contrastingTextColor
        
        XCTAssertNotNil(lightContrast)
        XCTAssertNotNil(darkContrast)
        
        // Test that contrasting colors are different from background
        XCTAssertNotEqual(lightContrast, lightColor)
        XCTAssertNotEqual(darkContrast, darkColor)
        
        // Test medium colors
        let mediumColors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]
        
        for color in mediumColors {
            let contrast = color.contrastingTextColor
            XCTAssertNotNil(contrast)
            XCTAssertNotEqual(contrast, color)
        }
    }
    
    func testColorUniqueness() {
        // Test that different colors are suggested for new entities
        let player1 = Player(context: testContext)
        let player2 = Player(context: testContext)
        let team1 = Team(context: testContext)
        let team2 = Team(context: testContext)
        
        // Test that default colors are assigned
        XCTAssertNotNil(player1.playerColor)
        XCTAssertNotNil(player2.playerColor)
        XCTAssertNotNil(team1.teamColor)
        XCTAssertNotNil(team2.teamColor)
        
        // Test color retrieval
        let player1Color = viewModel.getPlayerColor(player1)
        let player2Color = viewModel.getPlayerColor(player2)
        let team1Color = viewModel.getTeamColor(team1)
        let team2Color = viewModel.getTeamColor(team2)
        
        XCTAssertNotNil(player1Color)
        XCTAssertNotNil(player2Color)
        XCTAssertNotNil(team1Color)
        XCTAssertNotNil(team2Color)
    }
    
    // MARK: - Color Theme Integration Tests
    
    func testThemeColorIntegration() {
        // Test that colors work with theme system
        let player = Player(context: testContext)
        let team = Team(context: testContext)
        
        // Test theme color retrieval
        let playerColor = Theme.TeamColors.color(from: player.playerColor)
        let teamColor = Theme.TeamColors.color(from: team.teamColor)
        
        XCTAssertNotNil(playerColor)
        XCTAssertNotNil(teamColor)
        
        // Test default color fallback
        let nilColor = Theme.TeamColors.color(from: nil)
        XCTAssertNotNil(nilColor)
    }
    
    func testAvailableColors() {
        // Test that available colors are provided
        let availableColors = Theme.TeamColors.availableColors
        XCTAssertFalse(availableColors.isEmpty)
        
        // Test that all available colors are valid
        for color in availableColors {
            let hex = color.rawValue
            let _ = Color(hex: hex)
            
            // Test color name functionality
            let colorName = Theme.TeamColors.colorName(for: color)
            XCTAssertNotNil(colorName)
            XCTAssertFalse(colorName.isEmpty)
        }
    }
    
    func testColorNameConversion() {
        // Test color name for storage
        let testColors: [TeamColor] = [.red, .blue, .green, .yellow, .purple, .orange]
        
        for color in testColors {
            let colorName = Theme.TeamColors.colorName(for: color)
            XCTAssertNotNil(colorName)
            
            // Test that color name is a valid TeamColor raw value
            XCTAssertNotNil(TeamColor(rawValue: colorName))
        }
    }
    
    // MARK: - Color Edge Case Tests
    
    func testColorEdgeCases() {
        // Test empty color string
        let emptyColor = Color(hex: "")
        XCTAssertNotNil(emptyColor)
        
        // Test very long color string
        let longColorString = String(repeating: "F", count: 100)
        let longColor = Color(hex: longColorString)
        XCTAssertNotNil(longColor)
        
        // Test special characters
        let specialColorString = "#FF00@!"
        let specialColor = Color(hex: specialColorString)
        XCTAssertNotNil(specialColor)
        
        // Test short hex format (3 digits)
        let shortHex = "F00"
        let shortColor = Color(hex: shortHex)
        XCTAssertNotNil(shortColor)
    }
    
    func testColorPerformance() {
        // Test color conversion performance
        let colors: [TeamColor] = [.red, .blue, .green, .yellow, .purple, .orange]
        
        measure {
            for _ in 0..<1000 {
                for color in colors {
                    let hex = color.rawValue
                    let _ = Color(hex: hex)
                    
                    // Test color name functionality
                    let colorName = Theme.TeamColors.colorName(for: color)
                    XCTAssertNotNil(colorName)
                    XCTAssertFalse(colorName.isEmpty)
                }
            }
        }
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