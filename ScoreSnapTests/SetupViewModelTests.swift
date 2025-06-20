//
//  SetupViewModelTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import XCTest
import CoreData
import AVFoundation
import PhotosUI
import CoreLocation
@testable import ScoreSnap

@MainActor
class SetupViewModelTests: XCTestCase {
    
    var testContext: NSManagedObjectContext!
    var servicesManager: ServicesManager!
    var viewModel: SetupViewModel!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create in-memory Core Data stack for testing
        let container = NSPersistentContainer(name: "ScoreSnap")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load test Core Data stack: \(error)")
            }
        }
        
        testContext = container.viewContext
        servicesManager = ServicesManager()
        viewModel = SetupViewModel(viewContext: testContext, servicesManager: servicesManager)
        
        // Clear UserDefaults for each test
        UserDefaults.standard.removeObject(forKey: "hasCompletedSetup")
        UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
        UserDefaults.standard.removeObject(forKey: "setupSkipped")
    }
    
    override func tearDownWithError() throws {
        testContext = nil
        servicesManager = nil
        viewModel = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Setup Progress Tracking Tests
    
    func testSetupStepInitialization() {
        // Test that ViewModel starts with correct initial step (welcome)
        XCTAssertEqual(viewModel.currentStep, .welcome)
        XCTAssertFalse(viewModel.isSetupComplete)
    }
    
    func testStepProgressionTracking() {
        // Test step progression through the setup flow
        XCTAssertEqual(viewModel.currentStep, .welcome)
        
        // Welcome -> Player Creation
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, .playerCreation)
        
        // Player Creation -> Team Creation (with valid player name)
        viewModel.playerName = "Test Player"
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, .teamCreation)
        
        // Team Creation -> Permissions (with valid team name)
        viewModel.teamName = "Test Team"
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, .permissions)
        
        // Permissions -> Completion
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, .completion)
    }
    
    func testStepValidation() {
        // Test that validation prevents advancing without completing current step
        
        // Try to advance from player creation without name
        viewModel.currentStep = .playerCreation
        viewModel.playerName = ""
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, .playerCreation) // Should not advance
        XCTAssertTrue(viewModel.showingError)
        XCTAssertEqual(viewModel.errorMessage, "Please enter a player name")
        
        // Try to advance from team creation without name
        viewModel.currentStep = .teamCreation
        viewModel.teamName = ""
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, .teamCreation) // Should not advance
        XCTAssertTrue(viewModel.showingError)
        XCTAssertEqual(viewModel.errorMessage, "Please enter a team name")
    }
    
    func testSetupCompletionDetection() {
        // Test that setup completion is accurately detected
        XCTAssertFalse(viewModel.isSetupComplete)
        
        // Complete the setup flow
        viewModel.currentStep = .completion
        viewModel.playerName = "Test Player"
        viewModel.teamName = "Test Team"
        viewModel.createPlayerAndTeam()
        viewModel.nextStep() // This should complete setup
        
        XCTAssertTrue(viewModel.isSetupComplete)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedSetup"))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasSeenOnboarding"))
    }
    
    func testSetupRestartCapability() {
        // Test that setup can be restarted from beginning
        viewModel.currentStep = .teamCreation
        viewModel.playerName = "Test Player"
        viewModel.teamName = "Test Team"
        
        // Restart setup
        viewModel.currentStep = .welcome
        viewModel.playerName = ""
        viewModel.teamName = ""
        viewModel.selectedPlayer = nil
        viewModel.selectedTeam = nil
        
        XCTAssertEqual(viewModel.currentStep, .welcome)
        XCTAssertTrue(viewModel.playerName.isEmpty)
        XCTAssertTrue(viewModel.teamName.isEmpty)
        XCTAssertNil(viewModel.selectedPlayer)
        XCTAssertNil(viewModel.selectedTeam)
    }
    
    func testPartialSetupRecovery() {
        // Test that setup resumes from correct step if app is closed mid-setup
        viewModel.currentStep = .teamCreation
        viewModel.playerName = "Test Player"
        
        // Simulate app restart by creating new view model
        let newViewModel = SetupViewModel(viewContext: testContext, servicesManager: servicesManager)
        
        // Should start from welcome since no setup was completed
        XCTAssertEqual(newViewModel.currentStep, .welcome)
        XCTAssertFalse(newViewModel.isSetupComplete)
    }
    
    // MARK: - Player/Team Creation Logic Tests
    
    func testPlayerCreationValidation() {
        // Test player name validation
        XCTAssertFalse(viewModel.canProceedFromPlayerCreation)
        
        viewModel.playerName = "Test Player"
        XCTAssertTrue(viewModel.canProceedFromPlayerCreation)
        
        viewModel.playerName = "   " // Whitespace only
        XCTAssertFalse(viewModel.canProceedFromPlayerCreation)
        
        viewModel.playerName = "A" // Too short
        XCTAssertTrue(viewModel.canProceedFromPlayerCreation) // Single character is valid
        
        viewModel.playerName = String(repeating: "A", count: 51) // Too long
        XCTAssertTrue(viewModel.canProceedFromPlayerCreation) // Should still be valid, validation happens in Core Data
    }
    
    func testTeamCreationValidation() {
        // Test team name validation
        XCTAssertFalse(viewModel.canProceedFromTeamCreation)
        
        viewModel.teamName = "Test Team"
        XCTAssertTrue(viewModel.canProceedFromTeamCreation)
        
        viewModel.teamName = "   " // Whitespace only
        XCTAssertFalse(viewModel.canProceedFromTeamCreation)
    }
    
    func testColorAssignmentLogic() {
        // Test that appropriate default colors are assigned
        XCTAssertEqual(viewModel.teamColor, Constants.Defaults.defaultTeamColor)
        
        // Test color change
        viewModel.teamColor = .blue
        XCTAssertEqual(viewModel.teamColor, .blue)
    }
    
    func testCoreDataCreation() {
        // Test successful creation of Player and Team entities in Core Data
        viewModel.playerName = "Test Player"
        viewModel.teamName = "Test Team"
        
        viewModel.createPlayerAndTeam()
        
        XCTAssertNotNil(viewModel.selectedPlayer)
        XCTAssertNotNil(viewModel.selectedTeam)
        
        // Verify entities exist in Core Data
        let playerRequest: NSFetchRequest<Player> = Player.fetchRequest()
        let players = try! testContext.fetch(playerRequest)
        XCTAssertEqual(players.count, 1)
        XCTAssertEqual(players.first?.name, "Test Player")
        
        let teamRequest: NSFetchRequest<Team> = Team.fetchRequest()
        let teams = try! testContext.fetch(teamRequest)
        XCTAssertEqual(teams.count, 1)
        XCTAssertEqual(teams.first?.name, "Test Team")
    }
    
    func testRelationshipEstablishment() {
        // Test that team is properly linked to player in Core Data relationship
        viewModel.playerName = "Test Player"
        viewModel.teamName = "Test Team"
        
        viewModel.createPlayerAndTeam()
        
        XCTAssertNotNil(viewModel.selectedPlayer)
        XCTAssertNotNil(viewModel.selectedTeam)
        XCTAssertEqual(viewModel.selectedTeam?.player, viewModel.selectedPlayer)
    }
    
    func testDefaultValueAssignment() {
        // Test that appropriate default values are set
        viewModel.playerName = "Test Player"
        viewModel.teamName = "Test Team"
        
        viewModel.createPlayerAndTeam()
        
        XCTAssertNotNil(viewModel.selectedPlayer?.id)
        XCTAssertNotNil(viewModel.selectedTeam?.id)
        XCTAssertEqual(viewModel.selectedTeam?.displayOrder, 0)
        XCTAssertEqual(viewModel.selectedTeam?.teamColor, viewModel.teamColor.rawValue)
    }
    
    func testDuplicateNameHandling() {
        // Test handling of duplicate player/team names
        viewModel.playerName = "Test Player"
        viewModel.teamName = "Test Team"
        viewModel.createPlayerAndTeam()
        
        // Try to create another player with same name
        let newViewModel = SetupViewModel(viewContext: testContext, servicesManager: servicesManager)
        newViewModel.playerName = "Test Player"
        newViewModel.teamName = "Different Team"
        newViewModel.createPlayerAndTeam()
        
        // Should allow duplicate names (Core Data doesn't enforce uniqueness by default)
        let playerRequest: NSFetchRequest<Player> = Player.fetchRequest()
        let players = try! testContext.fetch(playerRequest)
        XCTAssertEqual(players.count, 2)
    }
    
    // MARK: - Permission Management Tests
    
    func testCameraPermissionRequest() {
        // Test camera permission request
        viewModel.requestPermission(.camera)
        
        // Verify permission request was initiated
        XCTAssertEqual(viewModel.currentPermissionRequest, .camera)
        
        // Note: Actual permission status depends on system state
        // We can only test that the request was made
    }
    
    func testPhotoLibraryPermissionRequest() {
        // Test photo library permission request
        viewModel.requestPermission(.photoLibrary)
        
        // Verify permission request was initiated
        XCTAssertEqual(viewModel.currentPermissionRequest, .photoLibrary)
    }
    
    func testLocationPermissionRequest() {
        // Test location permission request
        viewModel.requestPermission(.location)
        
        // Verify permission request was initiated
        XCTAssertEqual(viewModel.currentPermissionRequest, .location)
    }
    
    func testPermissionStatusTracking() {
        // Test that permission status is accurately tracked
        XCTAssertEqual(viewModel.cameraPermissionStatus, .notDetermined)
        XCTAssertEqual(viewModel.photoLibraryPermissionStatus, .notDetermined)
        XCTAssertEqual(viewModel.locationPermissionStatus, .notDetermined)
        
        // Simulate permission changes
        viewModel.cameraPermissionStatus = .authorized
        viewModel.photoLibraryPermissionStatus = .denied
        viewModel.locationPermissionStatus = .restricted
        
        XCTAssertEqual(viewModel.cameraPermissionStatus, .authorized)
        XCTAssertEqual(viewModel.photoLibraryPermissionStatus, .denied)
        XCTAssertEqual(viewModel.locationPermissionStatus, .restricted)
    }
    
    func testPermissionDenialHandling() {
        // Test graceful handling when user denies permissions
        viewModel.requestPermission(.camera)
        
        // Simulate permission denial
        viewModel.cameraPermissionStatus = .denied
        
        XCTAssertEqual(viewModel.cameraPermissionStatus, .denied)
        XCTAssertNil(viewModel.currentPermissionRequest)
    }
    
    func testPermissionGrantHandling() {
        // Test correct state update when user grants permissions
        viewModel.requestPermission(.photoLibrary)
        
        // Simulate permission grant
        viewModel.photoLibraryPermissionStatus = .authorized
        
        XCTAssertEqual(viewModel.photoLibraryPermissionStatus, .authorized)
        XCTAssertNil(viewModel.currentPermissionRequest)
    }
    
    func testPermissionRetryLogic() {
        // Test that user can retry permission requests if initially denied
        viewModel.requestPermission(.location)
        viewModel.locationPermissionStatus = .denied
        
        // Should be able to retry
        viewModel.requestPermission(.location)
        XCTAssertEqual(viewModel.currentPermissionRequest, .location)
    }
    
    // MARK: - Setup Completion Logic Tests
    
    func testAppContextInitialization() {
        // Test that AppContext is properly initialized with created player/team
        viewModel.playerName = "Test Player"
        viewModel.teamName = "Test Team"
        viewModel.createPlayerAndTeam()
        
        XCTAssertNotNil(viewModel.selectedPlayer)
        XCTAssertNotNil(viewModel.selectedTeam)
        
        // Test completion callback execution
        viewModel.currentStep = .completion
        viewModel.nextStep() // This should complete setup
        
        XCTAssertTrue(viewModel.isSetupComplete)
    }
    
    func testCompletionCallbackExecution() {
        // Test that navigation to main app is properly triggered after completion
        viewModel.playerName = "Test Player"
        viewModel.teamName = "Test Team"
        viewModel.createPlayerAndTeam()
        
        // Complete setup
        viewModel.currentStep = .completion
        viewModel.nextStep()
        
        XCTAssertTrue(viewModel.isSetupComplete)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedSetup"))
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() {
        // Test error handling and display through validation
        viewModel.currentStep = .playerCreation
        viewModel.playerName = ""
        viewModel.nextStep()
        
        XCTAssertTrue(viewModel.showingError)
        XCTAssertEqual(viewModel.errorMessage, "Please enter a player name")
        
        viewModel.clearError()
        
        XCTAssertFalse(viewModel.showingError)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testValidationErrorHandling() {
        // Test validation error handling
        viewModel.currentStep = .playerCreation
        viewModel.playerName = ""
        viewModel.nextStep()
        
        XCTAssertTrue(viewModel.showingError)
        XCTAssertEqual(viewModel.errorMessage, "Please enter a player name")
    }
    
    // MARK: - Navigation Tests
    
    func testPreviousStepNavigation() {
        // Test navigation to previous steps
        viewModel.currentStep = .teamCreation
        
        viewModel.previousStep()
        XCTAssertEqual(viewModel.currentStep, .playerCreation)
        
        viewModel.previousStep()
        XCTAssertEqual(viewModel.currentStep, .welcome)
        
        // Can't go back from welcome
        viewModel.previousStep()
        XCTAssertEqual(viewModel.currentStep, .welcome)
    }
    
    func testSkipSetup() {
        // Test setup skip functionality
        viewModel.skipSetup()
        
        XCTAssertTrue(viewModel.isSetupComplete)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "setupSkipped"))
    }
    
    // MARK: - Helper Methods
    
    private func createTestPlayer(name: String) -> Player {
        let player = Player(context: testContext)
        player.id = UUID()
        player.name = name
        player.displayOrder = 0
        return player
    }
    
    private func createTestTeam(name: String, player: Player) -> Team {
        let team = Team(context: testContext)
        team.id = UUID()
        team.name = name
        team.teamColor = TeamColor.red.rawValue
        team.displayOrder = 0
        team.player = player
        return team
    }
} 