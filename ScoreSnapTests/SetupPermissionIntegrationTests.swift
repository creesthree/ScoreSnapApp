//
//  SetupPermissionIntegrationTests.swift
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
class SetupPermissionIntegrationTests: XCTestCase {
    
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
        servicesManager = ServicesManager.shared
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
    
    // MARK: - Camera Permission Flow Tests
    
    func testCameraPermissionExplanation() {
        // Test clear explanation of camera usage for scoreboard photos
        let cameraExplanation = PermissionType.camera.explanation
        
        XCTAssertTrue(cameraExplanation.contains("camera"))
        XCTAssertTrue(cameraExplanation.contains("scoreboards"))
        XCTAssertTrue(cameraExplanation.contains("photos"))
        XCTAssertTrue(cameraExplanation.contains("ScoreSnap"))
        XCTAssertTrue(cameraExplanation.contains("accurately"))
        XCTAssertTrue(cameraExplanation.contains("record"))
    }
    
    func testCameraPermissionRequestFlow() {
        // Test camera permission request flow
        viewModel.currentStep = .permissions
        
        // Initial state
        XCTAssertEqual(viewModel.cameraPermissionStatus, .notDetermined)
        XCTAssertNil(viewModel.currentPermissionRequest)
        
        // Request permission
        viewModel.requestPermission(.camera)
        XCTAssertEqual(viewModel.currentPermissionRequest, .camera)
        
        // Simulate permission grant
        viewModel.cameraPermissionStatus = .authorized
        XCTAssertNil(viewModel.currentPermissionRequest) // Should be cleared
    }
    
    func testCameraPermissionRetry() {
        // Test that user can retry camera permission request after denial
        viewModel.currentStep = .permissions
        
        // First request
        viewModel.requestPermission(.camera)
        XCTAssertEqual(viewModel.currentPermissionRequest, .camera)
        
        // Simulate denial
        viewModel.cameraPermissionStatus = .denied
        XCTAssertNil(viewModel.currentPermissionRequest)
        
        // Retry request
        viewModel.requestPermission(.camera)
        XCTAssertEqual(viewModel.currentPermissionRequest, .camera)
        
        // Simulate grant on retry
        viewModel.cameraPermissionStatus = .authorized
        XCTAssertNil(viewModel.currentPermissionRequest)
    }
    
    func testCameraPermissionRestricted() {
        // Test handling of restricted camera permission
        viewModel.currentStep = .permissions
        
        viewModel.requestPermission(.camera)
        viewModel.cameraPermissionStatus = .restricted
        
        XCTAssertEqual(viewModel.cameraPermissionStatus, .restricted)
        XCTAssertNil(viewModel.currentPermissionRequest)
    }
    
    // MARK: - Photo Library Permission Flow Tests
    
    func testPhotoLibraryPermissionExplanation() {
        // Test clear explanation of photo library usage
        let photoLibraryExplanation = PermissionType.photoLibrary.explanation
        
        XCTAssertTrue(photoLibraryExplanation.contains("photo library"))
        XCTAssertTrue(photoLibraryExplanation.contains("existing photos"))
        XCTAssertTrue(photoLibraryExplanation.contains("scoreboards"))
        XCTAssertTrue(photoLibraryExplanation.contains("upload"))
        XCTAssertTrue(photoLibraryExplanation.contains("already taken"))
    }
    
    func testPhotoLibraryPermissionRequestFlow() {
        // Test photo library permission request flow
        viewModel.currentStep = .permissions
        
        // Initial state
        XCTAssertEqual(viewModel.photoLibraryPermissionStatus, .notDetermined)
        XCTAssertNil(viewModel.currentPermissionRequest)
        
        // Request permission
        viewModel.requestPermission(.photoLibrary)
        XCTAssertEqual(viewModel.currentPermissionRequest, .photoLibrary)
        
        // Simulate permission grant
        viewModel.photoLibraryPermissionStatus = .authorized
        XCTAssertNil(viewModel.currentPermissionRequest) // Should be cleared
    }
    
    func testPhotoLibraryPermissionRetry() {
        // Test that user can retry photo library permission request
        viewModel.currentStep = .permissions
        
        // First request
        viewModel.requestPermission(.photoLibrary)
        XCTAssertEqual(viewModel.currentPermissionRequest, .photoLibrary)
        
        // Simulate denial
        viewModel.photoLibraryPermissionStatus = .denied
        XCTAssertNil(viewModel.currentPermissionRequest)
        
        // Retry request
        viewModel.requestPermission(.photoLibrary)
        XCTAssertEqual(viewModel.currentPermissionRequest, .photoLibrary)
        
        // Simulate grant on retry
        viewModel.photoLibraryPermissionStatus = .authorized
        XCTAssertNil(viewModel.currentPermissionRequest)
    }
    
    func testPhotoLibraryPermissionLimited() {
        // Test handling of limited photo library permission
        viewModel.currentStep = .permissions
        
        viewModel.requestPermission(.photoLibrary)
        viewModel.photoLibraryPermissionStatus = .limited
        
        XCTAssertEqual(viewModel.photoLibraryPermissionStatus, .limited)
        XCTAssertNil(viewModel.currentPermissionRequest)
    }
    
    // MARK: - Location Permission Flow Tests
    
    func testLocationPermissionExplanation() {
        // Test clear explanation of location usage for game tracking
        let locationExplanation = PermissionType.location.explanation
        
        XCTAssertTrue(locationExplanation.contains("location"))
        XCTAssertTrue(locationExplanation.contains("games"))
        XCTAssertTrue(locationExplanation.contains("played"))
        XCTAssertTrue(locationExplanation.contains("organize"))
        XCTAssertTrue(locationExplanation.contains("history"))
        XCTAssertTrue(locationExplanation.contains("statistics"))
    }
    
    func testLocationPermissionRequestFlow() {
        // Test location permission request flow
        viewModel.currentStep = .permissions
        
        // Initial state
        XCTAssertEqual(viewModel.locationPermissionStatus, .notDetermined)
        XCTAssertNil(viewModel.currentPermissionRequest)
        
        // Request permission
        viewModel.requestPermission(.location)
        XCTAssertEqual(viewModel.currentPermissionRequest, .location)
        
        // Simulate permission grant
        viewModel.locationPermissionStatus = .authorizedWhenInUse
        XCTAssertNil(viewModel.currentPermissionRequest) // Should be cleared
    }
    
    func testLocationPermissionRetry() {
        // Test that user can retry location permission request
        viewModel.currentStep = .permissions
        
        // First request
        viewModel.requestPermission(.location)
        XCTAssertEqual(viewModel.currentPermissionRequest, .location)
        
        // Simulate denial
        viewModel.locationPermissionStatus = .denied
        XCTAssertNil(viewModel.currentPermissionRequest)
        
        // Retry request
        viewModel.requestPermission(.location)
        XCTAssertEqual(viewModel.currentPermissionRequest, .location)
        
        // Simulate grant on retry
        viewModel.locationPermissionStatus = .authorizedAlways
        XCTAssertNil(viewModel.currentPermissionRequest)
    }
    
    func testLocationPermissionRestricted() {
        // Test handling of restricted location permission
        viewModel.currentStep = .permissions
        
        viewModel.requestPermission(.location)
        viewModel.locationPermissionStatus = .restricted
        
        XCTAssertEqual(viewModel.locationPermissionStatus, .restricted)
        XCTAssertNil(viewModel.currentPermissionRequest)
    }
    
    // MARK: - Multiple Permission Integration Tests
    
    func testMultiplePermissionRequests() {
        // Test requesting multiple permissions in sequence
        viewModel.currentStep = .permissions
        
        // Request camera permission
        viewModel.requestPermission(.camera)
        XCTAssertEqual(viewModel.currentPermissionRequest, .camera)
        viewModel.cameraPermissionStatus = .authorized
        
        // Request photo library permission
        viewModel.requestPermission(.photoLibrary)
        XCTAssertEqual(viewModel.currentPermissionRequest, .photoLibrary)
        viewModel.photoLibraryPermissionStatus = .authorized
        
        // Request location permission
        viewModel.requestPermission(.location)
        XCTAssertEqual(viewModel.currentPermissionRequest, .location)
        viewModel.locationPermissionStatus = .authorizedWhenInUse
        
        // Verify all permissions are granted
        XCTAssertEqual(viewModel.cameraPermissionStatus, .authorized)
        XCTAssertEqual(viewModel.photoLibraryPermissionStatus, .authorized)
        XCTAssertEqual(viewModel.locationPermissionStatus, .authorizedWhenInUse)
        XCTAssertNil(viewModel.currentPermissionRequest)
    }
    
    func testMixedPermissionStates() {
        // Test handling of mixed permission states
        viewModel.currentStep = .permissions
        
        // Set different permission states
        viewModel.cameraPermissionStatus = .authorized
        viewModel.photoLibraryPermissionStatus = .denied
        viewModel.locationPermissionStatus = .notDetermined
        
        XCTAssertEqual(viewModel.cameraPermissionStatus, .authorized)
        XCTAssertEqual(viewModel.photoLibraryPermissionStatus, .denied)
        XCTAssertEqual(viewModel.locationPermissionStatus, .notDetermined)
        
        // Should be able to request denied permissions
        viewModel.requestPermission(.photoLibrary)
        XCTAssertEqual(viewModel.currentPermissionRequest, .photoLibrary)
        
        // Should be able to request undetermined permissions
        viewModel.requestPermission(.location)
        XCTAssertEqual(viewModel.currentPermissionRequest, .location)
    }
    
    // MARK: - Permission Explanation Integration Tests
    
    func testPermissionExplanationDisplay() {
        // Test that permission explanations are displayed correctly
        viewModel.currentStep = .permissions
        
        // Test showing permission explanation
        viewModel.showPermissionExplanation(for: .camera)
        XCTAssertTrue(viewModel.showingPermissionExplanation)
        XCTAssertEqual(viewModel.currentPermissionRequest, .camera)
        
        // Test showing different permission explanation
        viewModel.showPermissionExplanation(for: .photoLibrary)
        XCTAssertTrue(viewModel.showingPermissionExplanation)
        XCTAssertEqual(viewModel.currentPermissionRequest, .photoLibrary)
    }
    
    func testPermissionExplanationContent() {
        // Test that permission explanations contain appropriate content
        let cameraExplanation = PermissionType.camera.explanation
        let photoLibraryExplanation = PermissionType.photoLibrary.explanation
        let locationExplanation = PermissionType.location.explanation
        
        // Camera explanation should be comprehensive
        XCTAssertTrue(cameraExplanation.count > 50) // Reasonable length
        XCTAssertTrue(cameraExplanation.contains("ScoreSnap"))
        XCTAssertTrue(cameraExplanation.contains("camera"))
        
        // Photo library explanation should be comprehensive
        XCTAssertTrue(photoLibraryExplanation.count > 50)
        XCTAssertTrue(photoLibraryExplanation.contains("ScoreSnap"))
        XCTAssertTrue(photoLibraryExplanation.contains("photo library"))
        
        // Location explanation should be comprehensive
        XCTAssertTrue(locationExplanation.count > 50)
        XCTAssertTrue(locationExplanation.contains("ScoreSnap"))
        XCTAssertTrue(locationExplanation.contains("location"))
    }
    
    // MARK: - Settings Integration Tests
    
    func testSettingsAppNavigation() {
        // Test navigation to Settings app for permission changes
        // This is primarily a UI test, but we can test the method exists
        viewModel.openSettings()
        // If this doesn't crash, the test passes
    }
    
    func testPermissionStatusPersistence() {
        // Test that permission status changes are properly tracked
        viewModel.currentStep = .permissions
        
        // Set permission states
        viewModel.cameraPermissionStatus = .authorized
        viewModel.photoLibraryPermissionStatus = .denied
        viewModel.locationPermissionStatus = .restricted
        
        // Verify states are maintained
        XCTAssertEqual(viewModel.cameraPermissionStatus, .authorized)
        XCTAssertEqual(viewModel.photoLibraryPermissionStatus, .denied)
        XCTAssertEqual(viewModel.locationPermissionStatus, .restricted)
    }
    
    // MARK: - Error Handling Tests
    
    func testPermissionRequestErrorHandling() {
        // Test error handling during permission requests
        viewModel.currentStep = .permissions
        
        // Request permission (this should not cause an error in normal operation)
        viewModel.requestPermission(.camera)
        XCTAssertEqual(viewModel.currentPermissionRequest, .camera)
        
        // Test error clearing functionality
        viewModel.clearError()
        XCTAssertFalse(viewModel.showingError)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Setup Flow Integration Tests
    
    func testPermissionsStepInSetupFlow() {
        // Test permissions step as part of complete setup flow
        viewModel.currentStep = .welcome
        
        // Navigate to permissions step
        viewModel.nextStep() // welcome -> playerCreation
        viewModel.playerName = "Test Player"
        viewModel.nextStep() // playerCreation -> teamCreation
        viewModel.teamName = "Test Team"
        viewModel.nextStep() // teamCreation -> permissions
        
        XCTAssertEqual(viewModel.currentStep, .permissions)
        
        // Request permissions
        viewModel.requestPermission(.camera)
        viewModel.cameraPermissionStatus = .authorized
        
        viewModel.requestPermission(.photoLibrary)
        viewModel.photoLibraryPermissionStatus = .authorized
        
        viewModel.requestPermission(.location)
        viewModel.locationPermissionStatus = .authorizedWhenInUse
        
        // Continue to completion
        viewModel.nextStep() // permissions -> completion
        XCTAssertEqual(viewModel.currentStep, .completion)
    }
    
    func testSetupCompletionWithPermissions() {
        // Test setup completion with permission handling
        viewModel.playerName = "Test Player"
        viewModel.teamName = "Test Team"
        viewModel.createPlayerAndTeam()
        
        viewModel.currentStep = .permissions
        
        // Set permission states
        viewModel.cameraPermissionStatus = .authorized
        viewModel.photoLibraryPermissionStatus = .denied
        viewModel.locationPermissionStatus = .authorizedWhenInUse
        
        // Complete setup
        viewModel.nextStep() // permissions -> completion
        viewModel.nextStep() // completion -> finish
        
        XCTAssertTrue(viewModel.isSetupComplete)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedSetup"))
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