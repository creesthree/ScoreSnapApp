//
//  SetupViewTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import XCTest
import SwiftUI
import CoreData
import AVFoundation
import PhotosUI
import CoreLocation
@testable import ScoreSnap

@MainActor
class SetupViewTests: XCTestCase {
    
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
    
    // MARK: - Permissions Step Display Tests
    
    func testPermissionsExplanation() {
        // Test that clear explanation of why each permission is needed
        let cameraExplanation = PermissionType.camera.explanation
        let photoLibraryExplanation = PermissionType.photoLibrary.explanation
        let locationExplanation = PermissionType.location.explanation
        
        XCTAssertTrue(cameraExplanation.contains("camera"))
        XCTAssertTrue(cameraExplanation.contains("scoreboards"))
        XCTAssertTrue(photoLibraryExplanation.contains("photo library"))
        XCTAssertTrue(photoLibraryExplanation.contains("existing photos"))
        XCTAssertTrue(locationExplanation.contains("location"))
        XCTAssertTrue(locationExplanation.contains("games"))
    }
    
    func testPermissionRequestButtons() {
        // Test that buttons to request each permission work correctly
        viewModel.currentStep = .permissions
        
        // Test camera permission request
        viewModel.requestPermission(.camera)
        XCTAssertEqual(viewModel.currentPermissionRequest, .camera)
        
        // Test photo library permission request
        viewModel.requestPermission(.photoLibrary)
        XCTAssertEqual(viewModel.currentPermissionRequest, .photoLibrary)
        
        // Test location permission request
        viewModel.requestPermission(.location)
        XCTAssertEqual(viewModel.currentPermissionRequest, .location)
    }
    
    func testPermissionStatusDisplay() {
        // Test that current status of each permission is clearly indicated
        XCTAssertEqual(viewModel.cameraPermissionStatus, .notDetermined)
        XCTAssertEqual(viewModel.photoLibraryPermissionStatus, .notDetermined)
        XCTAssertEqual(viewModel.locationPermissionStatus, .notDetermined)
        
        // Simulate different permission states
        viewModel.cameraPermissionStatus = .authorized
        viewModel.photoLibraryPermissionStatus = .denied
        viewModel.locationPermissionStatus = .restricted
        
        XCTAssertEqual(viewModel.cameraPermissionStatus, .authorized)
        XCTAssertEqual(viewModel.photoLibraryPermissionStatus, .denied)
        XCTAssertEqual(viewModel.locationPermissionStatus, .restricted)
    }
    
    func testPermissionGrantFeedback() {
        // Test visual feedback when permissions are granted
        viewModel.requestPermission(.camera)
        XCTAssertEqual(viewModel.currentPermissionRequest, .camera)
        
        // Simulate permission grant
        viewModel.cameraPermissionStatus = .authorized
        XCTAssertNil(viewModel.currentPermissionRequest) // Request should be cleared
    }
    
    func testPermissionDenialHandling() {
        // Test clear guidance when permissions are denied
        viewModel.requestPermission(.photoLibrary)
        XCTAssertEqual(viewModel.currentPermissionRequest, .photoLibrary)
        
        // Simulate permission denial
        viewModel.photoLibraryPermissionStatus = .denied
        XCTAssertNil(viewModel.currentPermissionRequest) // Request should be cleared
        
        // Should be able to retry
        viewModel.requestPermission(.photoLibrary)
        XCTAssertEqual(viewModel.currentPermissionRequest, .photoLibrary)
    }
    
    func testSettingsAppIntegration() {
        // Test that deep links to Settings app for permission changes work
        // This is a UI test that would require actual app testing
        // For unit tests, we can verify the method exists and doesn't crash
        viewModel.openSettings()
        // If this doesn't crash, the test passes
    }
    
    // MARK: - Setup Step Navigation Tests
    
    func testWelcomeStepDisplay() {
        // Test welcome step displays correctly
        viewModel.currentStep = .welcome
        
        XCTAssertEqual(viewModel.currentStep, .welcome)
        XCTAssertEqual(viewModel.currentStep.title, "Welcome to ScoreSnap")
        XCTAssertEqual(viewModel.currentStep.description, "Let's get you started with ScoreSnap")
    }
    
    func testPlayerCreationStepDisplay() {
        // Test player creation step displays correctly
        viewModel.currentStep = .playerCreation
        
        XCTAssertEqual(viewModel.currentStep, .playerCreation)
        XCTAssertEqual(viewModel.currentStep.title, "Create Your Profile")
        XCTAssertEqual(viewModel.currentStep.description, "Tell us about yourself")
    }
    
    func testTeamCreationStepDisplay() {
        // Test team creation step displays correctly
        viewModel.currentStep = .teamCreation
        
        XCTAssertEqual(viewModel.currentStep, .teamCreation)
        XCTAssertEqual(viewModel.currentStep.title, "Create Your Team")
        XCTAssertEqual(viewModel.currentStep.description, "Set up your basketball team")
    }
    
    func testPermissionsStepDisplay() {
        // Test permissions step displays correctly
        viewModel.currentStep = .permissions
        
        XCTAssertEqual(viewModel.currentStep, .permissions)
        XCTAssertEqual(viewModel.currentStep.title, "App Permissions")
        XCTAssertEqual(viewModel.currentStep.description, "Enable features for the best experience")
    }
    
    func testCompletionStepDisplay() {
        // Test completion step displays correctly
        viewModel.currentStep = .completion
        
        XCTAssertEqual(viewModel.currentStep, .completion)
        XCTAssertEqual(viewModel.currentStep.title, "You're All Set!")
        XCTAssertEqual(viewModel.currentStep.description, "You're ready to start tracking games!")
    }
    
    // MARK: - Progress Indicator Tests
    
    func testProgressIndicatorSteps() {
        // Test that progress indicator shows correct number of steps
        let allSteps = SetupStep.allCases
        XCTAssertEqual(allSteps.count, 5)
        
        // Test step order
        XCTAssertEqual(allSteps[0], .welcome)
        XCTAssertEqual(allSteps[1], .playerCreation)
        XCTAssertEqual(allSteps[2], .teamCreation)
        XCTAssertEqual(allSteps[3], .permissions)
        XCTAssertEqual(allSteps[4], .completion)
    }
    
    func testProgressIndicatorCurrentStep() {
        // Test that progress indicator shows current step correctly
        viewModel.currentStep = .teamCreation
        
        // Should show step 3 of 5 (0-indexed, so step 2 = 3rd step)
        let currentStepNumber = viewModel.currentStep.rawValue + 1
        let totalSteps = SetupStep.allCases.count
        
        XCTAssertEqual(currentStepNumber, 3)
        XCTAssertEqual(totalSteps, 5)
    }
    
    // MARK: - Form Validation Tests
    
    func testPlayerNameValidation() {
        // Test player name validation in form
        viewModel.currentStep = .playerCreation
        
        // Empty name should not allow progression
        viewModel.playerName = ""
        XCTAssertFalse(viewModel.canProceedFromPlayerCreation)
        
        // Valid name should allow progression
        viewModel.playerName = "Test Player"
        XCTAssertTrue(viewModel.canProceedFromPlayerCreation)
        
        // Whitespace-only name should not allow progression
        viewModel.playerName = "   "
        XCTAssertFalse(viewModel.canProceedFromPlayerCreation)
    }
    
    func testTeamNameValidation() {
        // Test team name validation in form
        viewModel.currentStep = .teamCreation
        
        // Empty name should not allow progression
        viewModel.teamName = ""
        XCTAssertFalse(viewModel.canProceedFromTeamCreation)
        
        // Valid name should allow progression
        viewModel.teamName = "Test Team"
        XCTAssertTrue(viewModel.canProceedFromTeamCreation)
        
        // Whitespace-only name should not allow progression
        viewModel.teamName = "   "
        XCTAssertFalse(viewModel.canProceedFromTeamCreation)
    }
    
    // MARK: - Color Selection Tests
    
    func testTeamColorSelection() {
        // Test team color selection functionality
        XCTAssertEqual(viewModel.teamColor, Constants.Defaults.defaultTeamColor)
        
        // Test color change
        viewModel.teamColor = .blue
        XCTAssertEqual(viewModel.teamColor, .blue)
        
        viewModel.teamColor = .green
        XCTAssertEqual(viewModel.teamColor, .green)
    }
    
    func testDefaultColorAssignment() {
        // Test that default colors are assigned correctly
        XCTAssertEqual(viewModel.teamColor, Constants.Defaults.defaultTeamColor)
        
        // Verify default color is a valid TeamColor
        XCTAssertTrue(TeamColor.allCases.contains(viewModel.teamColor))
    }
    
    // MARK: - Error Display Tests
    
    func testErrorDisplay() {
        // Test error display functionality through validation
        viewModel.currentStep = .playerCreation
        viewModel.playerName = ""
        viewModel.nextStep()
        
        XCTAssertTrue(viewModel.showingError)
        XCTAssertEqual(viewModel.errorMessage, "Please enter a player name")
    }
    
    func testErrorClearing() {
        // Test error clearing functionality
        viewModel.currentStep = .playerCreation
        viewModel.playerName = ""
        viewModel.nextStep()
        XCTAssertTrue(viewModel.showingError)
        
        viewModel.clearError()
        XCTAssertFalse(viewModel.showingError)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Setup Completion Tests
    
    func testSetupCompletionFlow() {
        // Test complete setup flow
        viewModel.playerName = "Test Player"
        viewModel.teamName = "Test Team"
        
        // Create player and team
        viewModel.createPlayerAndTeam()
        XCTAssertNotNil(viewModel.selectedPlayer)
        XCTAssertNotNil(viewModel.selectedTeam)
        
        // Complete setup
        viewModel.currentStep = .completion
        viewModel.nextStep()
        
        XCTAssertTrue(viewModel.isSetupComplete)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedSetup"))
    }
    
    func testSetupSkipFlow() {
        // Test setup skip flow
        viewModel.skipSetup()
        
        XCTAssertTrue(viewModel.isSetupComplete)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "setupSkipped"))
    }
    
    // MARK: - Permission Type Tests
    
    func testPermissionTypeProperties() {
        // Test PermissionType enum properties
        
        // Camera permission
        XCTAssertEqual(PermissionType.camera.icon, "camera.fill")
        XCTAssertEqual(PermissionType.camera.title, "Camera Access")
        XCTAssertEqual(PermissionType.camera.description, "Take photos of basketball scoreboards")
        
        // Photo library permission
        XCTAssertEqual(PermissionType.photoLibrary.icon, "photo.fill")
        XCTAssertEqual(PermissionType.photoLibrary.title, "Photo Library Access")
        XCTAssertEqual(PermissionType.photoLibrary.description, "Select existing photos of scoreboards")
        
        // Location permission
        XCTAssertEqual(PermissionType.location.icon, "location.fill")
        XCTAssertEqual(PermissionType.location.title, "Location Access")
        XCTAssertEqual(PermissionType.location.description, "Record where your games are played")
    }
    
    func testPermissionTypeAllCases() {
        // Test that all permission types are available
        let allPermissions = PermissionType.allCases
        XCTAssertEqual(allPermissions.count, 3)
        XCTAssertTrue(allPermissions.contains(.camera))
        XCTAssertTrue(allPermissions.contains(.photoLibrary))
        XCTAssertTrue(allPermissions.contains(.location))
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