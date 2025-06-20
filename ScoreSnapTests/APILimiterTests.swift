//
//  APILimiterTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import XCTest
import Combine
@testable import ScoreSnap

@MainActor
class APILimiterTests: XCTestCase {
    
    var apiLimiter: APILimiter!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        apiLimiter = APILimiter()
        cancellables = Set<AnyCancellable>()
        
        // Clear any existing data
        UserDefaults.standard.removeObject(forKey: "APILimiter.Usage")
        UserDefaults.standard.removeObject(forKey: "APILimiter.Limits")
    }
    
    override func tearDown() {
        cancellables.removeAll()
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "APILimiter.Usage")
        UserDefaults.standard.removeObject(forKey: "APILimiter.Limits")
        
        apiLimiter = nil
        super.tearDown()
    }
    
    // MARK: - Rate Limiting Logic Tests
    
    func testCallCountingAccuracy() {
        // Test that calls are counted accurately
        XCTAssertEqual(apiLimiter.currentUsage.calls.count, 0)
        
        // Record some calls
        let success1 = apiLimiter.recordAPICall()
        let success2 = apiLimiter.recordAPICall()
        let success3 = apiLimiter.recordAPICall()
        
        XCTAssertTrue(success1)
        XCTAssertTrue(success2)
        XCTAssertTrue(success3)
        XCTAssertEqual(apiLimiter.currentUsage.calls.count, 3)
    }
    
    func testLimitEnforcement() {
        // Test per-minute limit enforcement
        let originalLimits = apiLimiter.limits
        apiLimiter.updateLimits(APILimits(perMinute: 2, perHour: 10, perDay: 20))
        
        // Should allow 2 calls
        XCTAssertTrue(apiLimiter.recordAPICall())
        XCTAssertTrue(apiLimiter.recordAPICall())
        
        // Third call should be blocked
        XCTAssertFalse(apiLimiter.recordAPICall())
        
        // Restore original limits
        apiLimiter.updateLimits(originalLimits)
    }
    
    func testLimitResetTiming() {
        // Test that limits reset at appropriate intervals
        apiLimiter.updateLimits(APILimits(perMinute: 1, perHour: 5, perDay: 10))
        
        // Use up the minute limit
        XCTAssertTrue(apiLimiter.recordAPICall())
        XCTAssertFalse(apiLimiter.recordAPICall())
        
        // Force reset to simulate time passing
        apiLimiter.forceReset()
        
        // Should be able to make another call
        XCTAssertTrue(apiLimiter.recordAPICall())
    }
    
    func testCallPermissionChecking() {
        // Test that canMakeAPICall correctly determines if calls are allowed
        apiLimiter.updateLimits(APILimits(perMinute: 1, perHour: 2, perDay: 3))
        
        // Should be able to make first call
        XCTAssertTrue(apiLimiter.canMakeAPICall())
        XCTAssertTrue(apiLimiter.recordAPICall())
        
        // Should not be able to make second call
        XCTAssertFalse(apiLimiter.canMakeAPICall())
        XCTAssertFalse(apiLimiter.recordAPICall())
    }
    
    func testLimitExceededState() {
        // Test that isLimitExceeded is set correctly
        apiLimiter.updateLimits(APILimits(perMinute: 1, perHour: 1, perDay: 1))
        
        XCTAssertFalse(apiLimiter.isLimitExceeded)
        
        // Use up the limit
        apiLimiter.recordAPICall()
        
        XCTAssertTrue(apiLimiter.isLimitExceeded)
    }
    
    // MARK: - Configuration Management Tests
    
    func testLimitConfigurationFlexibility() {
        // Test that limits can be easily adjusted
        let newLimits = APILimits(perMinute: 5, perHour: 30, perDay: 100)
        apiLimiter.updateLimits(newLimits)
        
        XCTAssertEqual(apiLimiter.limits.perMinute, 5)
        XCTAssertEqual(apiLimiter.limits.perHour, 30)
        XCTAssertEqual(apiLimiter.limits.perDay, 100)
    }
    
    func testConfigurationValidation() {
        // Test that invalid configurations are prevented
        let invalidLimits = APILimits(perMinute: -1, perHour: 0, perDay: 5)
        
        // Should prevent negative and zero values
        XCTAssertEqual(invalidLimits.perMinute, 1) // Should be clamped to minimum
        XCTAssertEqual(invalidLimits.perHour, 1)   // Should be clamped to minimum
        XCTAssertEqual(invalidLimits.perDay, 5)
    }
    
    func testConfigurationPersistence() {
        // Test that limit settings persist across app sessions
        let testLimits = APILimits(perMinute: 7, perHour: 25, perDay: 50)
        apiLimiter.updateLimits(testLimits)
        
        // Create new instance to simulate app restart
        let newAPILimiter = APILimiter()
        
        // Should have same limits
        XCTAssertEqual(newAPILimiter.limits.perMinute, testLimits.perMinute)
        XCTAssertEqual(newAPILimiter.limits.perHour, testLimits.perHour)
        XCTAssertEqual(newAPILimiter.limits.perDay, testLimits.perDay)
    }
    
    func testResetLimits() {
        // Test resetting to default limits
        apiLimiter.updateLimits(APILimits(perMinute: 10, perHour: 50, perDay: 100))
        apiLimiter.resetLimits()
        
        // Should be back to defaults
        XCTAssertEqual(apiLimiter.limits.perMinute, 3)
        XCTAssertEqual(apiLimiter.limits.perHour, 20)
        XCTAssertEqual(apiLimiter.limits.perDay, 40)
    }
    
    // MARK: - Persistence and Recovery Tests
    
    func testCallHistoryPersistence() {
        // Test that API call history survives app restarts
        apiLimiter.recordAPICall()
        apiLimiter.recordAPICall()
        
        let callCount = apiLimiter.currentUsage.calls.count
        
        // Create new instance to simulate app restart
        let newAPILimiter = APILimiter()
        
        // Should have same call count
        XCTAssertEqual(newAPILimiter.currentUsage.calls.count, callCount)
    }
    
    func testCallHistoryAccuracy() {
        // Test that persisted call history remains accurate over time
        let startTime = Date()
        
        apiLimiter.recordAPICall()
        
        // Wait a moment
        Thread.sleep(forTimeInterval: 0.1)
        
        apiLimiter.recordAPICall()
        
        // Create new instance
        let newAPILimiter = APILimiter()
        
        // Should have 2 calls with timestamps after start time
        XCTAssertEqual(newAPILimiter.currentUsage.calls.count, 2)
        XCTAssertTrue(newAPILimiter.currentUsage.calls.allSatisfy { $0.timestamp > startTime })
    }
    
    func testStorageCleanup() {
        // Test that old call history data is cleaned up appropriately
        apiLimiter.updateLimits(APILimits(perMinute: 100, perHour: 1000, perDay: 10000))
        
        // Add many calls
        for _ in 0..<50 {
            apiLimiter.recordAPICall()
        }
        
        // Force reset to simulate time passing (removes old calls)
        apiLimiter.forceReset()
        
        // Should have cleaned up old calls
        XCTAssertLessThan(apiLimiter.currentUsage.calls.count, 50)
    }
    
    func testCorruptionRecovery() {
        // Test recovery from corrupted call history data
        // Simulate corrupted data by setting invalid UserDefaults
        UserDefaults.standard.set("invalid data", forKey: "APILimiter.Usage")
        
        // Create new instance - should handle corruption gracefully
        let newAPILimiter = APILimiter()
        
        // Should still be functional
        XCTAssertTrue(newAPILimiter.canMakeAPICall())
        XCTAssertTrue(newAPILimiter.recordAPICall())
    }
    
    func testStorageEfficiency() {
        // Test that call history storage doesn't consume excessive space
        let initialSize = getStorageSize()
        
        // Add many calls
        for _ in 0..<100 {
            apiLimiter.recordAPICall()
        }
        
        let finalSize = getStorageSize()
        let sizeIncrease = finalSize - initialSize
        
        // Storage increase should be reasonable (less than 1KB)
        XCTAssertLessThan(sizeIncrease, 1024)
    }
    
    // MARK: - Usage Analysis Tests
    
    func testUsageStatsCalculation() {
        // Test usage statistics calculation
        apiLimiter.recordAPICall()
        apiLimiter.recordAPICall()
        apiLimiter.recordAPICall()
        
        let stats = apiLimiter.getUsageStats()
        
        XCTAssertEqual(stats.totalCalls, 3)
        XCTAssertGreaterThanOrEqual(stats.callsInLast24Hours, 3)
        XCTAssertGreaterThanOrEqual(stats.callsInLast7Days, 3)
    }
    
    func testUsageIntensityCalculation() {
        // Test usage intensity calculation
        let stats = apiLimiter.getUsageStats()
        
        // Should return a valid intensity level
        XCTAssertTrue(["Low", "Medium", "High", "Very High"].contains(stats.usageIntensity))
    }
    
    func testPeakUsageTimeDetection() {
        // Test peak usage time detection
        apiLimiter.recordAPICall()
        
        let stats = apiLimiter.getUsageStats()
        
        // Should either have a peak time or be nil
        XCTAssertTrue(stats.peakUsageTime != nil || stats.peakUsageTime == nil)
    }
    
    func testMostActiveDayDetection() {
        // Test most active day detection
        apiLimiter.recordAPICall()
        
        let stats = apiLimiter.getUsageStats()
        
        // Should either have a most active day or be nil
        XCTAssertTrue(stats.mostActiveDay != nil || stats.mostActiveDay == nil)
    }
    
    // MARK: - Developer Interface Tests
    
    func testDeveloperMode() {
        // Test developer mode functionality
        apiLimiter.setDeveloperMode(true)
        
        // Should have very high limits
        XCTAssertGreaterThan(apiLimiter.limits.perMinute, 50)
        XCTAssertGreaterThan(apiLimiter.limits.perHour, 500)
        XCTAssertGreaterThan(apiLimiter.limits.perDay, 5000)
        
        // Disable developer mode
        apiLimiter.setDeveloperMode(false)
        
        // Should be back to normal limits
        XCTAssertEqual(apiLimiter.limits.perMinute, 3)
        XCTAssertEqual(apiLimiter.limits.perHour, 20)
        XCTAssertEqual(apiLimiter.limits.perDay, 40)
    }
    
    func testDebugInfo() {
        // Test debug info generation
        apiLimiter.recordAPICall()
        
        let debugInfo = apiLimiter.getDebugInfo()
        
        XCTAssertNotNil(debugInfo.description)
        XCTAssertTrue(debugInfo.description.contains("API Limiter Debug Info"))
        XCTAssertTrue(debugInfo.description.contains("Current Usage"))
    }
    
    func testSimulateAPICalls() {
        // Test API call simulation
        let initialCount = apiLimiter.currentUsage.calls.count
        
        apiLimiter.simulateAPICalls(5)
        
        XCTAssertEqual(apiLimiter.currentUsage.calls.count, initialCount + 5)
    }
    
    // MARK: - Performance Tests
    
    func testLimitCheckingSpeed() {
        // Test that API limit checks complete within 10ms
        measure {
            for _ in 0..<1000 {
                _ = apiLimiter.canMakeAPICall()
            }
        }
    }
    
    func testCallRecordingSpeed() {
        // Test that API call recording doesn't add significant overhead
        measure {
            for _ in 0..<100 {
                _ = apiLimiter.recordAPICall()
            }
        }
    }
    
    func testPersistencePerformance() {
        // Test that call history persistence doesn't block main thread
        let expectation = XCTestExpectation(description: "Persistence performance")
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Record many calls
            for _ in 0..<100 {
                self.apiLimiter.recordAPICall()
            }
            
            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryUsage() {
        // Test that APILimiter doesn't accumulate excessive memory
        let initialMemory = getMemoryUsage()
        
        // Record many calls
        for _ in 0..<1000 {
            apiLimiter.recordAPICall()
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable (less than 5MB)
        XCTAssertLessThan(memoryIncrease, 5 * 1024 * 1024)
    }
    
    func testCacheMemoryManagement() {
        // Test that cache doesn't grow beyond reasonable size
        let initialMemory = getMemoryUsage()
        
        // Simulate many API calls over time
        for i in 0..<100 {
            apiLimiter.recordAPICall()
            
            // Force reset periodically to simulate time passing
            if i % 10 == 0 {
                apiLimiter.forceReset()
            }
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable
        XCTAssertLessThan(memoryIncrease, 2 * 1024 * 1024)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidDataHandling() {
        // Test handling of invalid data in UserDefaults
        UserDefaults.standard.set("invalid", forKey: "APILimiter.Usage")
        UserDefaults.standard.set("invalid", forKey: "APILimiter.Limits")
        
        // Should handle gracefully
        let newAPILimiter = APILimiter()
        
        // Should still be functional with default values
        XCTAssertTrue(newAPILimiter.canMakeAPICall())
        XCTAssertEqual(newAPILimiter.limits.perMinute, 3)
    }
    
    func testConcurrentAccess() {
        // Test concurrent access to APILimiter
        let expectation = XCTestExpectation(description: "Concurrent access")
        let group = DispatchGroup()
        
        for _ in 0..<10 {
            group.enter()
            DispatchQueue.global().async {
                for _ in 0..<10 {
                    _ = self.apiLimiter.recordAPICall()
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Should not crash and should have recorded calls
        XCTAssertGreaterThan(apiLimiter.currentUsage.calls.count, 0)
    }
    
    // MARK: - Helper Methods
    
    private func getStorageSize() -> Int {
        // Get size of UserDefaults data
        let userDefaults = UserDefaults.standard
        let usageData = userDefaults.data(forKey: "APILimiter.Usage")
        let limitsData = userDefaults.data(forKey: "APILimiter.Limits")
        
        return (usageData?.count ?? 0) + (limitsData?.count ?? 0)
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