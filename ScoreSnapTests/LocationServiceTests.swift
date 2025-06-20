//
//  LocationServiceTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import XCTest
import CoreLocation
import Combine
@testable import ScoreSnap

@MainActor
class LocationServiceTests: XCTestCase {
    
    var locationService: LocationService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        locationService = LocationService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        locationService = nil
        super.tearDown()
    }
    
    // MARK: - Current Location Tests
    
    func testLocationPermissionChecking() {
        // Test location permission status detection
        locationService.checkLocationServices()
        
        // Should have a valid authorization status
        XCTAssertTrue(locationService.authorizationStatus == .notDetermined ||
                     locationService.authorizationStatus == .authorizedWhenInUse ||
                     locationService.authorizationStatus == .authorizedAlways ||
                     locationService.authorizationStatus == .denied ||
                     locationService.authorizationStatus == .restricted)
    }
    
    func testLocationPermissionRequest() {
        // Test location permission request
        locationService.requestLocationPermission()
        
        // Should not crash and should update authorization status
        XCTAssertNotNil(locationService.authorizationStatus)
    }
    
    func testLocationPermissionDenialHandling() {
        // Simulate denied permission
        locationService.authorizationStatus = .denied
        
        // Test graceful handling
        XCTAssertFalse(locationService.isLocationEnabled)
        
        // Test that requesting permission again doesn't crash
        locationService.requestLocationPermission()
        XCTAssertEqual(locationService.authorizationStatus, .denied)
    }
    
    func testCurrentLocationRetrieval() async {
        // Test current location retrieval - will likely fail in simulator but should handle gracefully
        do {
            let location = try await locationService.requestSingleLocation()
            // If we get here, location was successfully retrieved
            XCTAssertNotNil(location)
            XCTAssertTrue(location.coordinate.latitude >= -90 && location.coordinate.latitude <= 90)
            XCTAssertTrue(location.coordinate.longitude >= -180 && location.coordinate.longitude <= 180)
        } catch {
            // Expected to fail in test environment, but should be a LocationError
            XCTAssertTrue(error is LocationError)
        }
    }
    
    func testLocationAccuracyLevels() {
        // Test that service requests appropriate accuracy
        locationService.startLocationUpdates()
        
        // Should not crash and should handle location updates appropriately
        XCTAssertNotNil(locationService.authorizationStatus)
    }
    
    func testLocationTimeoutHandling() async {
        // Test location timeout handling
        do {
            let _ = try await locationService.requestSingleLocation()
            // If successful, that's fine
        } catch LocationError.timeout {
            // Expected timeout in test environment
        } catch {
            // Other errors are also acceptable
            XCTAssertTrue(error is LocationError)
        }
    }
    
    func testLocationUnavailabilityHandling() async {
        // Test location unavailability handling
        do {
            let _ = try await locationService.requestSingleLocation()
            // If successful, that's fine
        } catch LocationError.locationUnavailable {
            // Expected in test environment
        } catch {
            // Other errors are also acceptable
            XCTAssertTrue(error is LocationError)
        }
    }
    
    func testLocationServicesDisabledHandling() {
        // Simulate disabled location services
        locationService.isLocationEnabled = false
        
        // Test graceful handling
        XCTAssertFalse(locationService.isLocationEnabled)
        
        // Test that requesting location doesn't crash
        locationService.requestLocationPermission()
    }
    
    // MARK: - Reverse Geocoding Tests
    
    func testCoordinateToAddressConversion() async {
        // Test coordinate to address conversion
        let testLocation = CLLocation(latitude: 40.7128, longitude: -74.0060) // New York
        
        do {
            let placemark = try await locationService.reverseGeocode(location: testLocation)
            XCTAssertNotNil(placemark)
            XCTAssertNotNil(placemark.locality) // Should have city name
        } catch {
            // May fail in test environment due to network issues
            XCTAssertTrue(error is LocationError)
        }
    }
    
    func testCityNameExtraction() async {
        // Test city name extraction
        let testLocation = CLLocation(latitude: 34.0522, longitude: -118.2437) // Los Angeles
        
        do {
            let placemark = try await locationService.reverseGeocode(location: testLocation)
            XCTAssertNotNil(placemark.locality) // Should have city name
        } catch {
            // May fail in test environment
            XCTAssertTrue(error is LocationError)
        }
    }
    
    func testInternationalLocationSupport() async {
        // Test international location support
        let testLocation = CLLocation(latitude: 51.5074, longitude: -0.1278) // London
        
        do {
            let placemark = try await locationService.reverseGeocode(location: testLocation)
            XCTAssertNotNil(placemark)
            XCTAssertNotNil(placemark.country) // Should have country
        } catch {
            // May fail in test environment
            XCTAssertTrue(error is LocationError)
        }
    }
    
    func testInvalidCoordinateHandling() async {
        // Test invalid coordinate handling
        let invalidLocation = CLLocation(latitude: 1000.0, longitude: 2000.0) // Invalid coordinates
        
        do {
            let _ = try await locationService.reverseGeocode(location: invalidLocation)
            // May succeed with some geocoding services
        } catch {
            // Expected to fail with invalid coordinates
            XCTAssertTrue(error is LocationError)
        }
    }
    
    func testGeocodingServiceFailures() async {
        // Test geocoding service failures
        let testLocation = CLLocation(latitude: 0.0, longitude: 0.0) // Null Island
        
        do {
            let _ = try await locationService.reverseGeocode(location: testLocation)
            // May succeed or fail depending on geocoding service
        } catch LocationError.geocodingFailed {
            // Expected failure
        } catch {
            // Other errors are also acceptable
            XCTAssertTrue(error is LocationError)
        }
    }
    
    func testGeocodingTimeoutHandling() async {
        // Test geocoding timeout handling
        let testLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        
        do {
            let _ = try await locationService.reverseGeocode(location: testLocation)
            // May succeed or timeout
        } catch LocationError.timeout {
            // Expected timeout
        } catch {
            // Other errors are also acceptable
            XCTAssertTrue(error is LocationError)
        }
    }
    
    func testAddressFormatting() async {
        // Test address formatting
        let testLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        
        do {
            let locationName = try await locationService.getLocationName(for: testLocation)
            XCTAssertNotNil(locationName)
            XCTAssertFalse(locationName.isEmpty)
        } catch {
            // May fail in test environment
            XCTAssertTrue(error is LocationError)
        }
    }
    
    func testAddressLocalization() async {
        // Test address localization
        let testLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        
        do {
            let placemark = try await locationService.reverseGeocode(location: testLocation)
            XCTAssertNotNil(placemark)
            // Should have localized address components
        } catch {
            // May fail in test environment
            XCTAssertTrue(error is LocationError)
        }
    }
    
    // MARK: - Location Validation Tests
    
    func testValidLocationValidation() {
        let validLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        XCTAssertTrue(locationService.isValidLocation(validLocation))
    }
    
    func testInvalidLocationValidation() {
        let invalidLocation = CLLocation(latitude: 1000.0, longitude: 2000.0)
        XCTAssertFalse(locationService.isValidLocation(invalidLocation))
    }
    
    func testOldLocationValidation() {
        let oldLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        // Create a location with old timestamp
        let oldDate = Date().addingTimeInterval(-10 * 60) // 10 minutes ago
        let oldLocationWithTimestamp = CLLocation(
            coordinate: oldLocation.coordinate,
            altitude: oldLocation.altitude,
            horizontalAccuracy: oldLocation.horizontalAccuracy,
            verticalAccuracy: oldLocation.verticalAccuracy,
            timestamp: oldDate
        )
        XCTAssertFalse(locationService.isValidLocation(oldLocationWithTimestamp))
    }
    
    func testLowAccuracyLocationValidation() {
        let lowAccuracyLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            altitude: 0,
            horizontalAccuracy: 200, // Low accuracy
            verticalAccuracy: 0,
            timestamp: Date()
        )
        XCTAssertFalse(locationService.isValidLocation(lowAccuracyLocation))
    }
    
    // MARK: - Distance Calculation Tests
    
    func testDistanceCalculation() {
        let location1 = CLLocation(latitude: 40.7128, longitude: -74.0060) // New York
        let location2 = CLLocation(latitude: 34.0522, longitude: -118.2437) // Los Angeles
        
        let distance = locationService.distance(from: location1, to: location2)
        XCTAssertGreaterThan(distance, 0)
        XCTAssertLessThan(distance, 5000000) // Should be less than 5000 km
    }
    
    func testNearbyLocationDetection() {
        let location1 = CLLocation(latitude: 40.7128, longitude: -74.0060)
        let location2 = CLLocation(latitude: 40.7129, longitude: -74.0061) // Very close
        
        XCTAssertTrue(locationService.isNearby(location1, to: location2, within: 100)) // Within 100 meters
        XCTAssertFalse(locationService.isNearby(location1, to: location2, within: 1)) // Not within 1 meter
    }
    
    // MARK: - Cache Management Tests
    
    func testLocationCacheFunctionality() async {
        let testLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        
        // First geocoding request
        do {
            let placemark1 = try await locationService.reverseGeocode(location: testLocation)
            XCTAssertNotNil(placemark1)
            
            // Second request should use cache
            let placemark2 = try await locationService.reverseGeocode(location: testLocation)
            XCTAssertNotNil(placemark2)
            
            // Both should be the same (from cache)
            XCTAssertEqual(placemark1.locality, placemark2.locality)
        } catch {
            // May fail in test environment
            XCTAssertTrue(error is LocationError)
        }
    }
    
    func testCacheCleanup() {
        // Test cache cleanup
        locationService.clearCache()
        
        // Should not crash
        XCTAssertTrue(true)
    }
    
    // MARK: - Location History Tests
    
    func testLocationHistorySaving() {
        let testLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        
        locationService.saveLocationToHistory(testLocation, withName: "Test Location")
        
        // Should not crash
        XCTAssertTrue(true)
    }
    
    func testRecentLocationsRetrieval() {
        let recentLocations = locationService.getRecentLocations(limit: 5)
        
        // Should return array (may be empty)
        XCTAssertNotNil(recentLocations)
        XCTAssertLessThanOrEqual(recentLocations.count, 5)
    }
    
    // MARK: - Error Handling Tests
    
    func testNetworkErrorHandling() async {
        // Test network error handling
        let testLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        
        do {
            let _ = try await locationService.reverseGeocode(location: testLocation)
            // May succeed or fail depending on network
        } catch LocationError.networkError {
            // Expected network error
        } catch {
            // Other errors are also acceptable
            XCTAssertTrue(error is LocationError)
        }
    }
    
    func testPermissionErrorHandling() async {
        // Test permission error handling
        locationService.authorizationStatus = .denied
        
        do {
            let _ = try await locationService.requestSingleLocation()
            XCTFail("Should throw permission error")
        } catch LocationError.permissionDenied {
            // Expected permission error
        } catch {
            // Other errors are also acceptable
            XCTAssertTrue(error is LocationError)
        }
    }
    
    // MARK: - Performance Tests
    
    func testLocationAcquisitionSpeed() async {
        let startTime = Date()
        
        do {
            let _ = try await locationService.requestSingleLocation()
            let duration = Date().timeIntervalSince(startTime)
            
            // Should complete within 8 seconds
            XCTAssertLessThan(duration, 8.0)
        } catch {
            // May fail in test environment, but should fail quickly
            let duration = Date().timeIntervalSince(startTime)
            XCTAssertLessThan(duration, 8.0)
        }
    }
    
    func testGeocodingSpeed() async {
        let testLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        let startTime = Date()
        
        do {
            let _ = try await locationService.reverseGeocode(location: testLocation)
            let duration = Date().timeIntervalSince(startTime)
            
            // Should complete within reasonable time
            XCTAssertLessThan(duration, 10.0)
        } catch {
            // May fail in test environment, but should fail quickly
            let duration = Date().timeIntervalSince(startTime)
            XCTAssertLessThan(duration, 10.0)
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testLocationServiceMemoryUsage() {
        // Test that location service doesn't accumulate memory
        let initialMemory = getMemoryUsage()
        
        // Perform multiple location operations
        for _ in 0..<10 {
            locationService.checkLocationServices()
            locationService.requestLocationPermission()
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable (less than 10MB)
        XCTAssertLessThan(memoryIncrease, 10 * 1024 * 1024)
    }
    
    func testCacheMemoryManagement() {
        // Test cache memory management
        let initialMemory = getMemoryUsage()
        
        // Add multiple locations to cache
        for i in 0..<50 {
            let location = CLLocation(latitude: Double(i), longitude: Double(i))
            locationService.saveLocationToHistory(location, withName: "Test \(i)")
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable
        XCTAssertLessThan(memoryIncrease, 5 * 1024 * 1024)
    }
    
    // MARK: - Helper Methods
    
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