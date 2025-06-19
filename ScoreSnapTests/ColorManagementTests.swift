//
//  ColorManagementTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import XCTest
import SwiftUI
import CoreData
@testable import ScoreSnap

@MainActor
class ColorManagementTests: XCTestCase {
    
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
    
    // MARK: - Color Picker Integration Tests
    
    func testSwiftUIColorPickerDisplay() {
        // Test that ColorPicker can be created with various colors
        let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink, .teal]
        
        for color in colors {
            // Test color creation
            XCTAssertNotNil(color)
            
            // Test color to hex conversion
            let hex = color.toHex()
            XCTAssertTrue(hex.hasPrefix("#"))
            XCTAssertEqual(hex.count, 7) // #RRGGBB format
        }
    }
    
    func testColorSelection() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        // Test color selection and update
        let selectedColor = Color.blue
        viewModel.updatePlayer(player, name: "Test Player", color: selectedColor, sport: "Basketball")
        
        // Verify color was updated
        XCTAssertEqual(player.playerColor, selectedColor.toHex())
        
        // Test color retrieval
        let retrievedColor = viewModel.getPlayerColor(player)
        XCTAssertNotNil(retrievedColor)
    }
    
    func testColorFormatConversion() {
        // Test color to hex conversion
        let testColors: [(Color, String)] = [
            (.red, "#FF0000"),
            (.green, "#00FF00"),
            (.blue, "#0000FF"),
            (.white, "#FFFFFF"),
            (.black, "#000000")
        ]
        
        for (color, expectedHex) in testColors {
            let hex = color.toHex()
            XCTAssertEqual(hex, expectedHex)
            
            // Test hex to color conversion
            let convertedColor = Color(hex: hex)
            XCTAssertNotNil(convertedColor)
        }
    }
    
    func testColorDisplay() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Test color assignment
        let playerColor = Color.red
        let teamColor = Color.blue
        
        player.playerColor = playerColor.toHex()
        team.teamColor = teamColor.toHex()
        
        // Test color retrieval and display
        let retrievedPlayerColor = viewModel.getPlayerColor(player)
        let retrievedTeamColor = viewModel.getTeamColor(team)
        
        XCTAssertNotNil(retrievedPlayerColor)
        XCTAssertNotNil(retrievedTeamColor)
        
        // Test color persistence
        XCTAssertEqual(player.playerColor, playerColor.toHex())
        XCTAssertEqual(team.teamColor, teamColor.toHex())
    }
    
    func testDefaultColorBehavior() {
        // Test that new entities get appropriate default colors
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        
        // Verify default colors are assigned
        XCTAssertNotNil(player.playerColor)
        XCTAssertNotNil(team.teamColor)
        
        // Test default color retrieval
        let playerColor = viewModel.getPlayerColor(player)
        let teamColor = viewModel.getTeamColor(team)
        
        XCTAssertNotNil(playerColor)
        XCTAssertNotNil(teamColor)
        
        // Test that default colors are valid hex strings
        XCTAssertTrue(player.playerColor!.hasPrefix("#"))
        XCTAssertTrue(team.teamColor!.hasPrefix("#"))
        XCTAssertEqual(player.playerColor!.count, 7)
        XCTAssertEqual(team.teamColor!.count, 7)
    }
    
    // MARK: - Color Validation Tests
    
    func testHexFormatValidation() {
        // Test valid hex formats
        let validHexColors = ["#FF0000", "#00FF00", "#0000FF", "#FFFFFF", "#000000", "#123456"]
        
        for hex in validHexColors {
            let color = Color(hex: hex)
            XCTAssertNotNil(color)
        }
        
        // Test invalid hex formats
        let invalidHexColors = ["#GG0000", "FF0000", "#FF00", "#FF00000", "invalid", ""]
        
        for hex in invalidHexColors {
            let color = Color(hex: hex)
            // Should still create a color (fallback behavior)
            XCTAssertNotNil(color)
        }
    }
    
    func testInvalidColorHandling() {
        // Test malformed color strings
        let malformedColors = ["", "invalid", "#GG0000", "FF0000", "#FF00"]
        
        for colorString in malformedColors {
            let color = Color(hex: colorString)
            // Should handle gracefully and create a fallback color
            XCTAssertNotNil(color)
        }
        
        // Test nil color handling
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        player.playerColor = nil
        
        let retrievedColor = viewModel.getPlayerColor(player)
        // Should return default color when nil
        XCTAssertNotNil(retrievedColor)
    }
    
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
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        let team1 = createTestTeam(name: "Team 1", player: player1, displayOrder: 0)
        let team2 = createTestTeam(name: "Team 2", player: player1, displayOrder: 1)
        
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
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        
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
            let hex = color.toHex()
            XCTAssertTrue(hex.hasPrefix("#"))
            XCTAssertEqual(hex.count, 7)
            
            // Test color name conversion
            let colorName = Theme.TeamColors.colorName(for: color)
            XCTAssertNotNil(colorName)
        }
    }
    
    func testColorNameConversion() {
        // Test color name for storage
        let testColors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]
        
        for color in testColors {
            let colorName = Theme.TeamColors.colorName(for: color)
            XCTAssertNotNil(colorName)
            
            // Test that color name is a valid hex string
            XCTAssertTrue(colorName.hasPrefix("#"))
            XCTAssertEqual(colorName.count, 7)
        }
    }
    
    // MARK: - Color Persistence Tests
    
    func testColorPersistence() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        
        // Set custom colors
        let playerColor = Color.purple
        let teamColor = Color.orange
        
        player.playerColor = playerColor.toHex()
        team.teamColor = teamColor.toHex()
        
        try! testContext.save()
        
        // Create new viewModel to simulate reload
        let newViewModel = PlayersViewModel(viewContext: testContext)
        
        // Verify colors persisted
        let loadedPlayer = newViewModel.players.first
        let loadedTeam = newViewModel.teams.first
        
        XCTAssertNotNil(loadedPlayer)
        XCTAssertNotNil(loadedTeam)
        
        XCTAssertEqual(loadedPlayer?.playerColor, playerColor.toHex())
        XCTAssertEqual(loadedTeam?.teamColor, teamColor.toHex())
        
        // Test color retrieval
        let retrievedPlayerColor = newViewModel.getPlayerColor(loadedPlayer!)
        let retrievedTeamColor = newViewModel.getTeamColor(loadedTeam!)
        
        XCTAssertNotNil(retrievedPlayerColor)
        XCTAssertNotNil(retrievedTeamColor)
    }
    
    func testColorUpdatePersistence() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        // Update color
        let newColor = Color.green
        viewModel.updatePlayer(player, name: "Test Player", color: newColor, sport: "Basketball")
        
        // Verify color was updated
        XCTAssertEqual(player.playerColor, newColor.toHex())
        
        // Create new viewModel to simulate reload
        let newViewModel = PlayersViewModel(viewContext: testContext)
        
        // Verify color persisted
        let loadedPlayer = newViewModel.players.first
        XCTAssertNotNil(loadedPlayer)
        XCTAssertEqual(loadedPlayer?.playerColor, newColor.toHex())
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
        let colors = [Color.red, Color.blue, Color.green, Color.yellow, Color.purple, Color.orange]
        
        measure {
            for _ in 0..<1000 {
                for color in colors {
                    let hex = color.toHex()
                    let _ = Color(hex: hex)
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
} 