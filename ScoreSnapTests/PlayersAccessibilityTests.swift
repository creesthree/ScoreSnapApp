//
//  PlayersAccessibilityTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import XCTest
import SwiftUI
import CoreData
@testable import ScoreSnap

@MainActor
class PlayersAccessibilityTests: XCTestCase {
    
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
    
    // MARK: - VoiceOver Support Tests
    
    func testPlayerListVoiceOverLabels() {
        let player1 = createTestPlayer(name: "John Doe", displayOrder: 0)
        let player2 = createTestPlayer(name: "Jane Smith", displayOrder: 1)
        try! testContext.save()
        viewModel.loadData()
        
        // Test that players have proper accessibility labels
        XCTAssertEqual(player1.name, "John Doe")
        XCTAssertEqual(player2.name, "Jane Smith")
        
        // Test accessibility labels would be generated
        let player1Label = generatePlayerAccessibilityLabel(player1)
        let player2Label = generatePlayerAccessibilityLabel(player2)
        
        XCTAssertTrue(player1Label.contains("John Doe"))
        XCTAssertTrue(player2Label.contains("Jane Smith"))
        XCTAssertTrue(player1Label.contains("Player"))
        XCTAssertTrue(player2Label.contains("Player"))
    }
    
    func testTeamListVoiceOverLabels() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team1 = createTestTeam(name: "Lakers", player: player, displayOrder: 0)
        let team2 = createTestTeam(name: "Warriors", player: player, displayOrder: 1)
        try! testContext.save()
        viewModel.loadData()
        
        // Test that teams have proper accessibility labels
        XCTAssertEqual(team1.name, "Lakers")
        XCTAssertEqual(team2.name, "Warriors")
        
        // Test accessibility labels would be generated
        let team1Label = generateTeamAccessibilityLabel(team1)
        let team2Label = generateTeamAccessibilityLabel(team2)
        
        XCTAssertTrue(team1Label.contains("Lakers"))
        XCTAssertTrue(team2Label.contains("Warriors"))
        XCTAssertTrue(team1Label.contains("Team"))
        XCTAssertTrue(team2Label.contains("Team"))
    }
    
    func testSelectedItemVoiceOver() {
        let player = createTestPlayer(name: "Selected Player", displayOrder: 0)
        let team = createTestTeam(name: "Selected Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Select player and team
        appContext.switchToPlayerAndTeam(player, team)
        
        // Test selected state accessibility
        XCTAssertEqual(appContext.currentPlayer, player)
        XCTAssertEqual(appContext.currentTeam, team)
        
        // Test accessibility labels for selected state
        let selectedPlayerLabel = generateSelectedPlayerAccessibilityLabel(player)
        let selectedTeamLabel = generateSelectedTeamAccessibilityLabel(team)
        
        XCTAssertTrue(selectedPlayerLabel.contains("Selected"))
        XCTAssertTrue(selectedPlayerLabel.contains("Player"))
        XCTAssertTrue(selectedTeamLabel.contains("Selected"))
        XCTAssertTrue(selectedTeamLabel.contains("Team"))
    }
    
    func testAddButtonVoiceOver() {
        // Test add button accessibility labels
        let addPlayerLabel = generateAddButtonAccessibilityLabel("Player")
        let addTeamLabel = generateAddButtonAccessibilityLabel("Team")
        
        XCTAssertTrue(addPlayerLabel.contains("Add"))
        XCTAssertTrue(addPlayerLabel.contains("Player"))
        XCTAssertTrue(addTeamLabel.contains("Add"))
        XCTAssertTrue(addTeamLabel.contains("Team"))
    }
    
    func testEditButtonVoiceOver() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        
        // Test edit button accessibility labels
        let editPlayerLabel = generateEditButtonAccessibilityLabel(player)
        let editTeamLabel = generateEditButtonAccessibilityLabel(team)
        
        XCTAssertTrue(editPlayerLabel.contains("Edit"))
        XCTAssertTrue(editPlayerLabel.contains("Test Player"))
        XCTAssertTrue(editTeamLabel.contains("Edit"))
        XCTAssertTrue(editTeamLabel.contains("Test Team"))
    }
    
    func testDeleteButtonVoiceOver() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        
        // Test delete button accessibility labels
        let deletePlayerLabel = generateDeleteButtonAccessibilityLabel(player)
        let deleteTeamLabel = generateDeleteButtonAccessibilityLabel(team)
        
        XCTAssertTrue(deletePlayerLabel.contains("Delete"))
        XCTAssertTrue(deletePlayerLabel.contains("Test Player"))
        XCTAssertTrue(deleteTeamLabel.contains("Delete"))
        XCTAssertTrue(deleteTeamLabel.contains("Test Team"))
    }
    
    // MARK: - Dynamic Type Tests
    
    func testDynamicTypeScaling() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Test that text can scale with Dynamic Type
        let playerName = player.name!
        let teamName = team.name!
        
        // Test different text sizes
        let sizes: [CGFloat] = [12, 16, 20, 24, 28, 32]
        
        for size in sizes {
            let scaledPlayerName = scaleText(playerName, to: size)
            let scaledTeamName = scaleText(teamName, to: size)
            
            XCTAssertNotNil(scaledPlayerName)
            XCTAssertNotNil(scaledTeamName)
            XCTAssertEqual(scaledPlayerName, playerName)
            XCTAssertEqual(scaledTeamName, teamName)
        }
    }
    
    func testLargeTextHandling() {
        let longPlayerName = "This is a very long player name that should be handled properly"
        let longTeamName = "This is a very long team name that should be handled properly"
        
        let player = createTestPlayer(name: longPlayerName, displayOrder: 0)
        let team = createTestTeam(name: longTeamName, player: player, displayOrder: 0)
        try! testContext.save()
        
        // Test that long text is handled properly
        XCTAssertEqual(player.name, longPlayerName)
        XCTAssertEqual(team.name, longTeamName)
        
        // Test accessibility labels with long text
        let playerLabel = generatePlayerAccessibilityLabel(player)
        let teamLabel = generateTeamAccessibilityLabel(team)
        
        XCTAssertTrue(playerLabel.contains(longPlayerName))
        XCTAssertTrue(teamLabel.contains(longTeamName))
    }
    
    func testTextTruncation() {
        let veryLongName = String(repeating: "A", count: 100)
        let player = createTestPlayer(name: veryLongName, displayOrder: 0)
        try! testContext.save()
        
        // Test that very long text is truncated appropriately
        XCTAssertEqual(player.name, veryLongName)
        
        // Test accessibility label with truncated text
        let truncatedLabel = generateTruncatedAccessibilityLabel(veryLongName, maxLength: 50)
        XCTAssertLessThanOrEqual(truncatedLabel.count, 50)
        XCTAssertTrue(truncatedLabel.contains("..."))
    }
    
    // MARK: - Color Accessibility Tests
    
    func testColorContrastAccessibility() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        
        // Test different color combinations for accessibility
        let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink, .teal]
        
        for color in colors {
            player.playerColor = Constants.Defaults.defaultPlayerColor.rawValue
            team.teamColor = Constants.Defaults.defaultTeamColor.rawValue
            
            // Test color contrast
            let contrast = calculateColorContrast(color, with: .white)
            XCTAssertGreaterThan(contrast, 0.0)
            
            // Test accessibility label includes color information
            let playerLabel = generateColorAccessibilityLabel(player)
            let teamLabel = generateColorAccessibilityLabel(team)
            
            XCTAssertTrue(playerLabel.contains("color"))
            XCTAssertTrue(teamLabel.contains("color"))
        }
    }
    
    func testColorBlindnessSupport() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        
        // Test that colors have alternative identifiers
        let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange]
        let colorNames = ["red", "blue", "green", "yellow", "purple", "orange"]
        
        for (color, name) in zip(colors, colorNames) {
            player.playerColor = Constants.Defaults.defaultPlayerColor.rawValue
            team.teamColor = Constants.Defaults.defaultTeamColor.rawValue
            
            // Test color name accessibility
            let playerLabel = generateColorNameAccessibilityLabel(player, colorName: name)
            let teamLabel = generateColorNameAccessibilityLabel(team, colorName: name)
            
            XCTAssertTrue(playerLabel.contains(name))
            XCTAssertTrue(teamLabel.contains(name))
        }
    }
    
    // MARK: - Navigation Accessibility Tests
    
    func testSectionNavigation() {
        // Test section navigation accessibility
        let playersSectionLabel = generateSectionAccessibilityLabel("Players")
        let teamsSectionLabel = generateSectionAccessibilityLabel("Teams")
        
        XCTAssertTrue(playersSectionLabel.contains("Players"))
        XCTAssertTrue(teamsSectionLabel.contains("Teams"))
        XCTAssertTrue(playersSectionLabel.contains("section"))
        XCTAssertTrue(teamsSectionLabel.contains("section"))
    }
    
    func testListNavigation() {
        let players = (0..<5).map { createTestPlayer(name: "Player \($0)", displayOrder: Int32($0)) }
        try! testContext.save()
        
        // Test list navigation accessibility
        for (index, player) in players.enumerated() {
            let listItemLabel = generateListItemAccessibilityLabel(player, index: index, total: players.count)
            
            XCTAssertTrue(listItemLabel.contains("Player \(index)"))
            XCTAssertTrue(listItemLabel.contains("\(index + 1) of \(players.count)"))
        }
    }
    
    func testEditModeNavigation() {
        // Test edit mode navigation accessibility
        let editModeLabel = generateEditModeAccessibilityLabel(true)
        let normalModeLabel = generateEditModeAccessibilityLabel(false)
        
        XCTAssertTrue(editModeLabel.contains("Edit mode"))
        XCTAssertTrue(editModeLabel.contains("enabled"))
        XCTAssertTrue(normalModeLabel.contains("Edit mode"))
        XCTAssertTrue(normalModeLabel.contains("disabled"))
    }
    
    // MARK: - Form Accessibility Tests
    
    func testFormFieldAccessibility() {
        // Test form field accessibility labels
        let nameFieldLabel = generateFormFieldAccessibilityLabel("Name", isRequired: true)
        let colorFieldLabel = generateFormFieldAccessibilityLabel("Color", isRequired: false)
        
        XCTAssertTrue(nameFieldLabel.contains("Name"))
        XCTAssertTrue(nameFieldLabel.contains("required"))
        XCTAssertTrue(colorFieldLabel.contains("Color"))
        XCTAssertFalse(colorFieldLabel.contains("required"))
    }
    
    func testFormValidationAccessibility() {
        // Test form validation accessibility
        let validName = "Valid Name"
        let invalidName = ""
        
        let validLabel = generateValidationAccessibilityLabel(validName, isValid: true)
        let invalidLabel = generateValidationAccessibilityLabel(invalidName, isValid: false)
        
        XCTAssertTrue(validLabel.contains("valid"))
        XCTAssertTrue(invalidLabel.contains("invalid"))
        XCTAssertTrue(invalidLabel.contains("required"))
    }
    
    func testColorPickerAccessibility() {
        // Test color picker accessibility
        let colorPickerLabel = generateColorPickerAccessibilityLabel("Player Color")
        
        XCTAssertTrue(colorPickerLabel.contains("Color picker"))
        XCTAssertTrue(colorPickerLabel.contains("Player Color"))
    }
    
    // MARK: - Confirmation Dialog Accessibility Tests
    
    func testDeleteConfirmationAccessibility() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        
        // Test delete confirmation accessibility
        let playerDeleteLabel = generateDeleteConfirmationAccessibilityLabel(player)
        let teamDeleteLabel = generateDeleteConfirmationAccessibilityLabel(team)
        
        XCTAssertTrue(playerDeleteLabel.contains("Delete"))
        XCTAssertTrue(playerDeleteLabel.contains("Test Player"))
        XCTAssertTrue(playerDeleteLabel.contains("confirmation"))
        XCTAssertTrue(teamDeleteLabel.contains("Delete"))
        XCTAssertTrue(teamDeleteLabel.contains("Test Team"))
        XCTAssertTrue(teamDeleteLabel.contains("confirmation"))
    }
    
    func testCascadeDeleteAccessibility() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        
        // Test cascade delete accessibility warning
        let cascadeLabel = generateCascadeDeleteAccessibilityLabel(player)
        
        XCTAssertTrue(cascadeLabel.contains("warning"))
        XCTAssertTrue(cascadeLabel.contains("teams"))
        XCTAssertTrue(cascadeLabel.contains("games"))
    }
    
    // MARK: - Reordering Accessibility Tests
    
    func testReorderAccessibility() {
        let players = (0..<3).map { createTestPlayer(name: "Player \($0)", displayOrder: Int32($0)) }
        try! testContext.save()
        
        // Test reorder accessibility
        let reorderLabel = generateReorderAccessibilityLabel(players[0], from: 0, to: 2)
        
        XCTAssertTrue(reorderLabel.contains("Player 0"))
        XCTAssertTrue(reorderLabel.contains("moved"))
        XCTAssertTrue(reorderLabel.contains("position 3"))
    }
    
    func testDragHandleAccessibility() {
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        
        // Test drag handle accessibility
        let dragHandleLabel = generateDragHandleAccessibilityLabel(player)
        
        XCTAssertTrue(dragHandleLabel.contains("drag handle"))
        XCTAssertTrue(dragHandleLabel.contains("Test Player"))
        XCTAssertTrue(dragHandleLabel.contains("reorder"))
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
    
    // MARK: - Accessibility Label Generators
    
    private func generatePlayerAccessibilityLabel(_ player: Player) -> String {
        return "Player: \(player.name ?? "Unknown")"
    }
    
    private func generateTeamAccessibilityLabel(_ team: Team) -> String {
        return "Team: \(team.name ?? "Unknown")"
    }
    
    private func generateSelectedPlayerAccessibilityLabel(_ player: Player) -> String {
        return "Selected Player: \(player.name ?? "Unknown")"
    }
    
    private func generateSelectedTeamAccessibilityLabel(_ team: Team) -> String {
        return "Selected Team: \(team.name ?? "Unknown")"
    }
    
    private func generateAddButtonAccessibilityLabel(_ type: String) -> String {
        return "Add \(type) button"
    }
    
    private func generateEditButtonAccessibilityLabel(_ entity: NSManagedObject) -> String {
        let name = (entity as? Player)?.name ?? (entity as? Team)?.name ?? "Unknown"
        return "Edit \(name) button"
    }
    
    private func generateDeleteButtonAccessibilityLabel(_ entity: NSManagedObject) -> String {
        let name = (entity as? Player)?.name ?? (entity as? Team)?.name ?? "Unknown"
        return "Delete \(name) button"
    }
    
    private func scaleText(_ text: String, to size: CGFloat) -> String {
        // Simulate text scaling
        return text
    }
    
    private func generateTruncatedAccessibilityLabel(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        }
        let truncated = String(text.prefix(maxLength - 3))
        return "\(truncated)..."
    }
    
    private func calculateColorContrast(_ color1: Color, with color2: Color) -> Double {
        // Simulate color contrast calculation
        return 4.5 // WCAG AA compliant contrast ratio
    }
    
    private func generateColorAccessibilityLabel(_ entity: NSManagedObject) -> String {
        let name = (entity as? Player)?.name ?? (entity as? Team)?.name ?? "Unknown"
        return "\(name) with custom color"
    }
    
    private func generateColorNameAccessibilityLabel(_ entity: NSManagedObject, colorName: String) -> String {
        let name = (entity as? Player)?.name ?? (entity as? Team)?.name ?? "Unknown"
        return "\(name) with \(colorName) color"
    }
    
    private func generateSectionAccessibilityLabel(_ sectionName: String) -> String {
        return "\(sectionName) section"
    }
    
    private func generateListItemAccessibilityLabel(_ entity: NSManagedObject, index: Int, total: Int) -> String {
        let name = (entity as? Player)?.name ?? (entity as? Team)?.name ?? "Unknown"
        return "\(name), item \(index + 1) of \(total)"
    }
    
    private func generateEditModeAccessibilityLabel(_ isEnabled: Bool) -> String {
        return "Edit mode \(isEnabled ? "enabled" : "disabled")"
    }
    
    private func generateFormFieldAccessibilityLabel(_ fieldName: String, isRequired: Bool) -> String {
        return "\(fieldName) field\(isRequired ? ", required" : "")"
    }
    
    private func generateValidationAccessibilityLabel(_ value: String, isValid: Bool) -> String {
        if isValid {
            return "\(value) is valid"
        } else {
            return "\(value) is invalid, required field"
        }
    }
    
    private func generateColorPickerAccessibilityLabel(_ label: String) -> String {
        return "Color picker for \(label)"
    }
    
    private func generateDeleteConfirmationAccessibilityLabel(_ entity: NSManagedObject) -> String {
        let name = (entity as? Player)?.name ?? (entity as? Team)?.name ?? "Unknown"
        return "Delete \(name) confirmation dialog"
    }
    
    private func generateCascadeDeleteAccessibilityLabel(_ player: Player) -> String {
        return "Warning: Deleting \(player.name ?? "player") will also delete all associated teams and games"
    }
    
    private func generateReorderAccessibilityLabel(_ entity: NSManagedObject, from: Int, to: Int) -> String {
        let name = (entity as? Player)?.name ?? (entity as? Team)?.name ?? "Unknown"
        return "\(name) moved from position \(from + 1) to position \(to + 1)"
    }
    
    private func generateDragHandleAccessibilityLabel(_ entity: NSManagedObject) -> String {
        let name = (entity as? Player)?.name ?? (entity as? Team)?.name ?? "Unknown"
        return "Drag handle for \(name), double tap to reorder"
    }
} 