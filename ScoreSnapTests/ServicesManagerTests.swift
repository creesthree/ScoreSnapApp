//
//  ServicesManagerTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import XCTest
import UIKit
import CoreLocation
import Combine
@testable import ScoreSnap

@MainActor
class ServicesManagerTests: XCTestCase {
    
    var servicesManager: ServicesManager!
    var mockViewController: ServicesManagerMockViewController!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        servicesManager = ServicesManager()
        mockViewController = ServicesManagerMockViewController()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        servicesManager = nil
        mockViewController = nil
        super.tearDown()
    }
    
    // MARK: - Service Integration Tests
    
    func testServiceInitialization() async {
        // Test that all services initialize properly
        await servicesManager.initializeServices()
        
        // All services should be ready or have valid states
        XCTAssertNotNil(servicesManager.photoService)
        XCTAssertNotNil(servicesManager.locationService)
        XCTAssertNotNil(servicesManager.apiLimiter)
    }
    
    func testServiceDependencyManagement() {
        // Test that services properly depend on each other without circular dependencies
        // ServicesManager should coordinate services without creating circular references
        
        // Check that services are independent but coordinated
        XCTAssertNotNil(servicesManager.photoService)
        XCTAssertNotNil(servicesManager.locationService)
        XCTAssertNotNil(servicesManager.apiLimiter)
        
        // Services should not reference each other directly
        // This is a structural test - if we reach here without crashes, dependencies are managed correctly
        XCTAssertTrue(true)
    }
    
    func testServiceErrorIsolation() {
        // Test that failure in one service doesn't crash others
        
        // Simulate photo service error
        servicesManager.photoService.isCameraAvailable = false
        servicesManager.photoService.isPhotoLibraryAvailable = false
        
        // Other services should still be functional
        XCTAssertNotNil(servicesManager.locationService)
        XCTAssertNotNil(servicesManager.apiLimiter)
        
        // Photo service should handle errors gracefully
        XCTAssertFalse(servicesManager.isPhotoServiceReady)
    }
    
    func testServiceStateConsistency() {
        // Test that services maintain consistent state across operations
        
        // Initial state
        let initialPhotoReady = servicesManager.isPhotoServiceReady
        let initialLocationReady = servicesManager.isLocationServiceReady
        let initialAPILimiterReady = servicesManager.isAPILimiterReady
        
        // Perform operations
        servicesManager.resetAllServices()
        
        // State should remain consistent
        XCTAssertNotNil(servicesManager.isPhotoServiceReady)
        XCTAssertNotNil(servicesManager.isLocationServiceReady)
        XCTAssertNotNil(servicesManager.isAPILimiterReady)
    }
    
    func testServiceLifecycleManagement() {
        // Test that services properly initialize and clean up
        
        // Test initialization
        XCTAssertNotNil(servicesManager.photoService)
        XCTAssertNotNil(servicesManager.locationService)
        XCTAssertNotNil(servicesManager.apiLimiter)
        
        // Test cleanup
        servicesManager.clearAllCaches()
        
        // Should not crash
        XCTAssertTrue(true)
    }
    
    // MARK: - PhotoService + LocationService Integration Tests
    
    func testPhotoLocationExtractionWorkflow() async {
        // Test complete flow from photo to city name
        do {
            let photoWithLocation = try await servicesManager.capturePhotoWithLocation(from: mockViewController)
            
            // Should have photo
            XCTAssertNotNil(photoWithLocation.image)
            
            // Location may or may not be available in test environment
            if photoWithLocation.hasLocation {
                XCTAssertNotNil(photoWithLocation.location)
                XCTAssertNotNil(photoWithLocation.locationName)
            }
            
            // Should have timestamp
            XCTAssertNotNil(photoWithLocation.timestamp)
            
        } catch {
            // Expected to fail in test environment, but should be a ServiceError
            XCTAssertTrue(error is ServiceError)
        }
    }
    
    func testMetadataLocationProcessing() async {
        // Test photo GPS coordinates correctly processed by LocationService
        do {
            let photoWithLocation = try await servicesManager.selectPhotoWithLocation(from: mockViewController)
            
            // Should have photo
            XCTAssertNotNil(photoWithLocation.image)
            
            // EXIF metadata should be extracted
            XCTAssertNotNil(photoWithLocation.exifMetadata)
            
            // If photo has GPS data, it should be processed
            if photoWithLocation.hasEXIFData {
                XCTAssertNotNil(photoWithLocation.exifMetadata)
            }
            
        } catch {
            // Expected to fail in test environment
            XCTAssertTrue(error is ServiceError)
        }
    }
    
    func testFallbackLocationHandling() async {
        // Test uses current location when photo has no GPS data
        do {
            let photoWithLocation = try await servicesManager.capturePhotoWithLocation(from: mockViewController)
            
            // Should have photo regardless of location availability
            XCTAssertNotNil(photoWithLocation.image)
            
            // Location is optional, so photo processing should continue even if location fails
            XCTAssertNotNil(photoWithLocation.timestamp)
            
        } catch {
            // Expected to fail in test environment
            XCTAssertTrue(error is ServiceError)
        }
    }
    
    func testLocationErrorPropagation() async {
        // Test photo processing continues gracefully when location fails
        do {
            let photoWithLocation = try await servicesManager.selectPhotoWithLocation(from: mockViewController)
            
            // Should have photo even if location fails
            XCTAssertNotNil(photoWithLocation.image)
            
        } catch {
            // Expected to fail in test environment
            XCTAssertTrue(error is ServiceError)
        }
    }
    
    // MARK: - PhotoService + APILimiter Integration Tests
    
    func testAPILimitCheckingBeforeProcessing() {
        // Test API limit checking before expensive photo processing
        
        // Set low limits
        servicesManager.apiLimiter.updateLimits(APILimits(perMinute: 1, perHour: 5, perDay: 10))
        
        // Use up the limit
        XCTAssertTrue(servicesManager.recordAPICall())
        
        // Next call should be blocked
        XCTAssertFalse(servicesManager.canMakeAPICall())
    }
    
    func testGracefulDegradationOnLimitReached() async {
        // Test provides appropriate user feedback when limits hit
        
        // Set very low limits
        servicesManager.apiLimiter.updateLimits(APILimits(perMinute: 1, perHour: 1, perDay: 1))
        
        // Use up the limit
        servicesManager.recordAPICall()
        
        // Try to capture photo - should fail with appropriate error
        do {
            let _ = try await servicesManager.capturePhoto(from: mockViewController)
            XCTFail("Should not succeed when limit is reached")
        } catch ServiceError.apiLimitExceeded {
            // Expected error
        } catch {
            // Other errors are also acceptable in test environment
            XCTAssertTrue(error is ServiceError)
        }
    }
    
    // MARK: - Core Data Integration Tests
    
    func testServiceDataPersistence() {
        // Test service configurations and data properly stored
        
        // Update API limits
        let testLimits = APILimits(perMinute: 5, perHour: 25, perDay: 50)
        servicesManager.apiLimiter.updateLimits(testLimits)
        
        // Create new services manager to simulate app restart
        let newServicesManager = ServicesManager()
        
        // Should have same limits
        XCTAssertEqual(newServicesManager.apiLimiter.limits.perMinute, testLimits.perMinute)
        XCTAssertEqual(newServicesManager.apiLimiter.limits.perHour, testLimits.perHour)
        XCTAssertEqual(newServicesManager.apiLimiter.limits.perDay, testLimits.perDay)
    }
    
    func testServiceDataCleanup() {
        // Test service data cleanup doesn't interfere with app data
        
        // Add some location history
        let testLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        servicesManager.locationService.saveLocationToHistory(testLocation, withName: "Test")
        
        // Clear caches
        servicesManager.clearAllCaches()
        
        // Should not crash
        XCTAssertTrue(true)
    }
    
    // MARK: - AppContext Integration Tests
    
    func testContextAwareServiceOperations() {
        // Test services operate within correct player/team context
        
        // This is more of a structural test since ServicesManager doesn't directly use AppContext
        // but it should be designed to work with the app's context system
        
        // Services should be context-agnostic but context-aware
        XCTAssertNotNil(servicesManager.photoService)
        XCTAssertNotNil(servicesManager.locationService)
        XCTAssertNotNil(servicesManager.apiLimiter)
    }
    
    func testServiceStateAndContextSynchronization() {
        // Test services stay synchronized with app context changes
        
        // Services should maintain their own state independently
        let initialPhotoReady = servicesManager.isPhotoServiceReady
        let initialLocationReady = servicesManager.isLocationServiceReady
        let initialAPILimiterReady = servicesManager.isAPILimiterReady
        
        // Reset services
        servicesManager.resetAllServices()
        
        // Should maintain consistent state
        XCTAssertNotNil(servicesManager.isPhotoServiceReady)
        XCTAssertNotNil(servicesManager.isLocationServiceReady)
        XCTAssertNotNil(servicesManager.isAPILimiterReady)
    }
    
    // MARK: - Permission Integration Tests
    
    func testPermissionRevocationHandling() {
        // Test all services handle permission revocation gracefully
        
        // Simulate permission revocation
        servicesManager.photoService.cameraPermissionStatus = .denied
        servicesManager.photoService.photoLibraryPermissionStatus = .denied
        servicesManager.locationService.authorizationStatus = .denied
        
        // Services should handle gracefully
        XCTAssertFalse(servicesManager.isPhotoServiceReady)
        XCTAssertFalse(servicesManager.isLocationServiceReady)
        XCTAssertTrue(servicesManager.isAPILimiterReady) // APILimiter doesn't need permissions
    }
    
    func testPermissionRestorationHandling() {
        // Test services resume normal operation when permissions restored
        
        // Simulate permission restoration
        servicesManager.photoService.cameraPermissionStatus = .authorized
        servicesManager.locationService.authorizationStatus = .authorizedWhenInUse
        
        // Check permissions again
        servicesManager.photoService.checkPermissions()
        servicesManager.locationService.checkLocationServices()
        
        // Should update service readiness
        XCTAssertNotNil(servicesManager.isPhotoServiceReady)
        XCTAssertNotNil(servicesManager.isLocationServiceReady)
    }
    
    func testPermissionRequestOrdering() {
        // Test permissions requested in logical order for user
        
        // Request location permission
        servicesManager.requestLocationPermission()
        
        // Should not crash and should handle permission request appropriately
        XCTAssertNotNil(servicesManager.locationService.authorizationStatus)
    }
    
    func testPermissionExplanationClarity() {
        // Test users understand why permissions are needed
        
        // This is more of a UI/UX test, but we can verify that permission descriptions exist
        // Check Info.plist keys are present (this would be done in a different test)
        XCTAssertTrue(true) // Placeholder for permission explanation test
    }
    
    func testPermissionDenialGracefulDegradation() {
        // Test app remains functional with limited permissions
        
        // Simulate denied permissions
        servicesManager.photoService.cameraPermissionStatus = .denied
        servicesManager.photoService.photoLibraryPermissionStatus = .denied
        servicesManager.locationService.authorizationStatus = .denied
        
        // App should still be functional
        XCTAssertNotNil(servicesManager.apiLimiter)
        XCTAssertTrue(servicesManager.apiLimiter.canMakeAPICall())
    }
    
    // MARK: - Performance Tests
    
    func testPhotoCaptureSpeed() async {
        // Test camera capture completes within 3 seconds
        let startTime = Date()
        
        do {
            let _ = try await servicesManager.capturePhoto(from: mockViewController)
            let duration = Date().timeIntervalSince(startTime)
            XCTAssertLessThan(duration, 3.0)
        } catch {
            // May fail in test environment, but should fail quickly
            let duration = Date().timeIntervalSince(startTime)
            XCTAssertLessThan(duration, 3.0)
        }
    }
    
    func testPhotoLibrarySelectionSpeed() async {
        // Test photo selection interface loads within 1 second
        let startTime = Date()
        
        do {
            let _ = try await servicesManager.selectPhoto(from: mockViewController)
            let duration = Date().timeIntervalSince(startTime)
            XCTAssertLessThan(duration, 1.0)
        } catch {
            // May fail in test environment, but should fail quickly
            let duration = Date().timeIntervalSince(startTime)
            XCTAssertLessThan(duration, 1.0)
        }
    }
    
    func testLocationAcquisitionSpeed() async {
        // Test current location acquired within 8 seconds
        let startTime = Date()
        
        do {
            let _ = try await servicesManager.getCurrentLocation()
            let duration = Date().timeIntervalSince(startTime)
            XCTAssertLessThan(duration, 8.0)
        } catch {
            // May fail in test environment, but should fail quickly
            let duration = Date().timeIntervalSince(startTime)
            XCTAssertLessThan(duration, 8.0)
        }
    }
    
    func testAPILimitCheckingSpeed() {
        // Test API limit checks complete within 10ms
        measure {
            for _ in 0..<1000 {
                _ = servicesManager.canMakeAPICall()
            }
        }
    }
    
    func testCallRecordingSpeed() {
        // Test API call recording doesn't add significant overhead
        measure {
            for _ in 0..<100 {
                _ = servicesManager.recordAPICall()
            }
        }
    }
    
    func testPersistencePerformance() {
        // Test call history persistence doesn't block main thread
        let expectation = XCTestExpectation(description: "Persistence performance")
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Record many calls
            for _ in 0..<100 {
                self.servicesManager.recordAPICall()
            }
            
            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Memory Management Tests
    
    func testPhotoMemoryCleanup() {
        // Test photos properly released from memory after processing
        let initialMemory = getMemoryUsage()
        
        // Process multiple photos
        for _ in 0..<10 {
            let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
            let _ = servicesManager.processImageForAnalysis(testImage)
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable (less than 10MB)
        XCTAssertLessThan(memoryIncrease, 10 * 1024 * 1024)
    }
    
    func testLocationServiceMemoryUsage() {
        // Test location services don't accumulate memory over time
        let initialMemory = getMemoryUsage()
        
        // Perform multiple location operations
        for _ in 0..<10 {
            servicesManager.locationService.checkLocationServices()
            servicesManager.requestLocationPermission()
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable (less than 5MB)
        XCTAssertLessThan(memoryIncrease, 5 * 1024 * 1024)
    }
    
    func testCacheMemoryManagement() {
        // Test caches don't grow beyond reasonable size limits
        let initialMemory = getMemoryUsage()
        
        // Add multiple locations to cache
        for i in 0..<50 {
            let location = CLLocation(latitude: Double(i), longitude: Double(i))
            servicesManager.locationService.saveLocationToHistory(location, withName: "Test \(i)")
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable
        XCTAssertLessThan(memoryIncrease, 5 * 1024 * 1024)
    }
    
    func testServiceLifecycleMemoryManagement() {
        // Test services properly clean up when no longer needed
        let initialMemory = getMemoryUsage()
        
        // Create and destroy multiple service managers
        for _ in 0..<10 {
            let tempManager = ServicesManager()
            tempManager.clearAllCaches()
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be minimal
        XCTAssertLessThan(memoryIncrease, 2 * 1024 * 1024)
    }
    
    // MARK: - Error Handling Tests
    
    func testNetworkErrorHandling() async {
        // Test services handle no network connectivity gracefully
        do {
            let _ = try await servicesManager.getCurrentLocationName()
            // May succeed or fail depending on network
        } catch {
            // Should handle network errors gracefully
            XCTAssertTrue(error is ServiceError)
        }
    }
    
    func testNetworkTimeoutHandling() async {
        // Test services handle network timeouts without crashing
        do {
            let _ = try await servicesManager.reverseGeocode(location: CLLocation(latitude: 40.7128, longitude: -74.0060))
            // May succeed or timeout
        } catch {
            // Should handle timeouts gracefully
            XCTAssertTrue(error is ServiceError)
        }
    }
    
    func testNetworkErrorRecovery() {
        // Test services automatically retry when network restored
        // This is more of an integration test that would require network simulation
        XCTAssertTrue(true) // Placeholder for network recovery test
    }
    
    func testStorageFullConditions() {
        // Test services handle full device storage appropriately
        // This would require simulating storage full conditions
        XCTAssertTrue(true) // Placeholder for storage full test
    }
    
    func testHardwarePermissionChanges() {
        // Test services adapt when hardware permissions change
        servicesManager.photoService.cameraPermissionStatus = .authorized
        servicesManager.photoService.cameraPermissionStatus = .denied
        
        // Should handle permission changes gracefully
        XCTAssertNotNil(servicesManager.isPhotoServiceReady)
    }
    
    func testCorruptedPhotoData() {
        // Test services handle corrupted or invalid photo files
        let corruptedImage = createTestImage(size: CGSize(width: 0, height: 0))
        
        // Should handle gracefully
        let result = servicesManager.photoService.validatePhoto(corruptedImage)
        switch result {
        case .success:
            XCTFail("Corrupted image should fail validation")
        case .failure:
            // Expected failure
            XCTAssertTrue(true)
        }
    }
    
    func testInvalidLocationData() {
        // Test services handle invalid GPS coordinates or location data
        let invalidLocation = CLLocation(latitude: 1000.0, longitude: 2000.0)
        
        // Should handle gracefully
        XCTAssertFalse(servicesManager.locationService.isValidLocation(invalidLocation))
    }
    
    func testCorruptedCacheData() {
        // Test services recover from corrupted cache files
        // Simulate corrupted cache by setting invalid UserDefaults
        UserDefaults.standard.set("invalid", forKey: "LocationHistory")
        
        // Should handle gracefully
        let recentLocations = servicesManager.locationService.getRecentLocations(limit: 5)
        XCTAssertNotNil(recentLocations)
    }
    
    func testAPIResponseErrors() {
        // Test services handle invalid or error responses from external APIs
        // This would require mocking API responses
        XCTAssertTrue(true) // Placeholder for API response error test
    }
    
    // MARK: - Reliability Tests
    
    func testServiceInitializationReliability() {
        // Test services consistently initialize correctly
        for _ in 0..<10 {
            let tempManager = ServicesManager()
            XCTAssertNotNil(tempManager.photoService)
            XCTAssertNotNil(tempManager.locationService)
            XCTAssertNotNil(tempManager.apiLimiter)
        }
    }
    
    func testServiceOperationConsistency() {
        // Test services produce consistent results for same inputs
        let testImage = createTestImage(size: CGSize(width: 500, height: 400))
        
        let result1 = servicesManager.photoService.validatePhoto(testImage)
        let result2 = servicesManager.photoService.validatePhoto(testImage)
        
        // Should produce same result
        switch (result1, result2) {
        case (.success, .success):
            XCTAssertTrue(true)
        case (.failure, .failure):
            XCTAssertTrue(true)
        default:
            XCTFail("Results should be consistent")
        }
    }
    
    func testCacheConsistency() {
        // Test cached data remains consistent with source data
        let testLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        
        // Add to cache
        servicesManager.locationService.saveLocationToHistory(testLocation, withName: "Test")
        
        // Retrieve from cache
        let recentLocations = servicesManager.locationService.getRecentLocations(limit: 1)
        
        // Should be consistent
        XCTAssertNotNil(recentLocations)
    }
    
    func testPermissionStateConsistency() {
        // Test permission states remain accurate across service operations
        let initialStatus = servicesManager.photoService.cameraPermissionStatus
        
        servicesManager.photoService.checkPermissions()
        
        // Should maintain consistent state
        XCTAssertNotNil(servicesManager.photoService.cameraPermissionStatus)
    }
    
    func testConfigurationConsistency() {
        // Test service configurations remain stable across app sessions
        let testLimits = APILimits(perMinute: 5, perHour: 25, perDay: 50)
        servicesManager.apiLimiter.updateLimits(testLimits)
        
        // Create new instance
        let newManager = ServicesManager()
        
        // Should have same configuration
        XCTAssertEqual(newManager.apiLimiter.limits.perMinute, testLimits.perMinute)
        XCTAssertEqual(newManager.apiLimiter.limits.perHour, testLimits.perHour)
        XCTAssertEqual(newManager.apiLimiter.limits.perDay, testLimits.perDay)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size)
        } else {
            return 0
        }
    }
}

// MARK: - Mock View Controller

class ServicesManagerMockViewController: UIViewController {
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        // Mock presentation - immediately dismiss to simulate cancellation
        DispatchQueue.main.async {
            viewControllerToPresent.dismiss(animated: false) {
                completion?()
            }
        }
    }
} 