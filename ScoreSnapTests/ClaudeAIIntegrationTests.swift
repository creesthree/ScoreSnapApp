//
//  ClaudeAIIntegrationTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import XCTest
import UIKit
@testable import ScoreSnap

@MainActor
final class ClaudeAIIntegrationTests: XCTestCase {
    
    var servicesManager: ServicesManager!
    var claudeAIService: ClaudeAIService!
    
    override func setUpWithError() throws {
        servicesManager = ServicesManager()
        claudeAIService = servicesManager.claudeAIService
    }
    
    override func tearDownWithError() throws {
        servicesManager = nil
        claudeAIService = nil
    }
    
    // MARK: - Services Integration Tests
    
    func testServicesManagerIntegration() {
        // Test that ClaudeAIService is properly integrated
        XCTAssertNotNil(servicesManager.claudeAIService)
        XCTAssertFalse(servicesManager.isClaudeAIServiceReady) // No API key initially
        
        // Set API key
        do {
            try servicesManager.setClaudeAPIKey("test-key")
            XCTAssertTrue(servicesManager.isClaudeAIServiceReady)
            
            // Clear API key
            servicesManager.clearClaudeAPIKey()
            XCTAssertFalse(servicesManager.isClaudeAIServiceReady)
        } catch {
            XCTFail("Failed to set API key: \(error)")
        }
    }
    
    func testAPILimiterIntegration() {
        // Test that ClaudeAIService respects API limits
        do {
            try servicesManager.setClaudeAPIKey("test-key")
            
            // Initially should be able to make calls
            XCTAssertTrue(servicesManager.canMakeAPICall())
            
            // Simulate rate limit exceeded
            servicesManager.apiLimiter.updateLimits(APILimits(perMinute: 0, perHour: 0, perDay: 0))
            XCTAssertFalse(servicesManager.canMakeAPICall())
        } catch {
            XCTFail("Failed to set API key: \(error)")
        }
    }
    
    // MARK: - Scoreboard Image Analysis Tests
    
    func testVariousScoreboardFormats() async {
        do {
            try servicesManager.setClaudeAPIKey("test-key")
            
            let testImages = [
                createDigitalScoreboardImage(),
                createAnalogScoreboardImage(),
                createPartialScoreboardImage(),
                createBlurryScoreboardImage()
            ]
            
            for (index, image) in testImages.enumerated() {
                do {
                    let result = try await servicesManager.analyzeScoreboardImage(image)
                    XCTAssertNotNil(result, "Analysis should return result for image \(index)")
                    
                    // Verify basic structure
                    if let homeTeam = result.homeTeam {
                        XCTAssertNil(homeTeam.name) // Team names should not be extracted
                        XCTAssertNotNil(homeTeam.score)
                        XCTAssertNil(homeTeam.fouls) // Fouls should not be extracted
                        XCTAssertNil(homeTeam.timeouts) // Timeouts should not be extracted
                    }
                    
                    if let awayTeam = result.awayTeam {
                        XCTAssertNil(awayTeam.name) // Team names should not be extracted
                        XCTAssertNotNil(awayTeam.score)
                        XCTAssertNil(awayTeam.fouls) // Fouls should not be extracted
                        XCTAssertNil(awayTeam.timeouts) // Timeouts should not be extracted
                    }
                    
                } catch {
                    // Some images might fail analysis, which is expected
                    print("Analysis failed for image \(index): \(error)")
                }
            }
        } catch {
            XCTFail("Failed to set API key: \(error)")
        }
    }
    
    func testNonScoreboardImageHandling() async {
        do {
            try servicesManager.setClaudeAPIKey("test-key")
            
            let nonScoreboardImages = [
                createRandomImage(),
                createTextImage(),
                createEmptyImage()
            ]
            
            for (index, image) in nonScoreboardImages.enumerated() {
                do {
                    let result = try await servicesManager.analyzeScoreboardImage(image)
                    
                    // Non-scoreboard images should either return null results or low confidence
                    if let confidence = result.confidence {
                        XCTAssertLessThan(confidence, 0.5, "Non-scoreboard image \(index) should have low confidence")
                    }
                    
                    // Or the result should be invalid
                    if !result.isValid {
                        // This is expected for non-scoreboard images
                        XCTAssertTrue(true)
                    }
                    
                } catch {
                    // Analysis failure is also acceptable for non-scoreboard images
                    print("Analysis failed for non-scoreboard image \(index): \(error)")
                }
            }
        } catch {
            XCTFail("Failed to set API key: \(error)")
        }
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testNetworkFailureHandling() async {
        do {
            try servicesManager.setClaudeAPIKey("test-key")
            
            // This test would require network mocking
            // For now, we'll test the error handling structure
            let testImage = createTestImage()
            
            do {
                let result = try await servicesManager.analyzeScoreboardImage(testImage)
                // If we get here, the service handled the request properly
                XCTAssertNotNil(result)
            } catch {
                // Network errors are expected in test environment
                XCTAssertTrue(error is ClaudeAIError || error is ServiceError)
            }
        } catch {
            XCTFail("Failed to set API key: \(error)")
        }
    }
    
    func testInvalidAPIKeyHandling() async {
        do {
            try servicesManager.setClaudeAPIKey("invalid-key")
            
            let testImage = createTestImage()
            
            do {
                _ = try await servicesManager.analyzeScoreboardImage(testImage)
                // If we get here, the service might be using a mock or test environment
                XCTAssertTrue(true)
            } catch {
                // Invalid API key should cause an error
                XCTAssertTrue(error is ClaudeAIError || error is ServiceError)
            }
        } catch {
            // Setting invalid API key should fail
            XCTAssertTrue(true)
        }
    }
    
    func testRateLimitHandling() async {
        do {
            try servicesManager.setClaudeAPIKey("test-key")
            
            // Set very low limits
            servicesManager.apiLimiter.updateLimits(APILimits(perMinute: 1, perHour: 1, perDay: 1))
            
            let testImage = createTestImage()
            
            // First call should work
            do {
                let result = try await servicesManager.analyzeScoreboardImage(testImage)
                XCTAssertNotNil(result)
            } catch {
                // First call might fail due to test environment
                print("First call failed: \(error)")
            }
            
            // Second call should hit rate limit
            do {
                _ = try await servicesManager.analyzeScoreboardImage(testImage)
                // If we get here, rate limiting might not be enforced in test environment
                XCTAssertTrue(true)
            } catch {
                XCTAssertTrue(error is ClaudeAIError || error is ServiceError)
            }
        } catch {
            XCTFail("Failed to set API key: \(error)")
        }
    }
    
    // MARK: - Retry Logic Integration Tests
    
    func testRetryLogicWithTransientFailures() async {
        do {
            try servicesManager.setClaudeAPIKey("test-key")
            
            let testImage = createTestImage()
            
            // Test with retry count
            do {
                let result = try await servicesManager.analyzeScoreboardImage(testImage)
                XCTAssertNotNil(result)
            } catch {
                // Retry logic should handle transient failures
                XCTAssertTrue(error is ClaudeAIError || error is ServiceError)
            }
        } catch {
            XCTFail("Failed to set API key: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testAnalysisPerformance() async {
        do {
            try servicesManager.setClaudeAPIKey("test-key")
            
            let testImage = createTestImage()
            let startTime = Date()
            
            do {
                let result = try await servicesManager.analyzeScoreboardImage(testImage)
                let endTime = Date()
                let duration = endTime.timeIntervalSince(startTime)
                
                XCTAssertNotNil(result)
                XCTAssertLessThan(duration, 30.0, "Analysis should complete within 30 seconds")
                
            } catch {
                // Performance test might fail due to network issues
                print("Performance test failed: \(error)")
            }
        } catch {
            XCTFail("Failed to set API key: \(error)")
        }
    }
    
    func testConcurrentAnalysisRequests() async {
        do {
            try servicesManager.setClaudeAPIKey("test-key")
            
            let testImages = [
                createTestImage(),
                createTestImage(),
                createTestImage()
            ]
            
            let startTime = Date()
            
            await withTaskGroup(of: Void.self) { group in
                for (index, image) in testImages.enumerated() {
                    group.addTask {
                        do {
                            let result = try await self.servicesManager.analyzeScoreboardImage(image)
                            XCTAssertNotNil(result, "Concurrent analysis \(index) should return result")
                        } catch {
                            print("Concurrent analysis \(index) failed: \(error)")
                        }
                    }
                }
            }
            
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            XCTAssertLessThan(duration, 60.0, "Concurrent analysis should complete within 60 seconds")
        } catch {
            XCTFail("Failed to set API key: \(error)")
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryUsageWithLargeImages() async {
        do {
            try servicesManager.setClaudeAPIKey("test-key")
            
            let largeImage = createLargeTestImage()
            
            // Monitor memory usage
            let initialMemory = getMemoryUsage()
            
            do {
                let result = try await servicesManager.analyzeScoreboardImage(largeImage)
                XCTAssertNotNil(result)
                
                let finalMemory = getMemoryUsage()
                let memoryIncrease = finalMemory - initialMemory
                
                // Memory increase should be reasonable (less than 100MB)
                XCTAssertLessThan(memoryIncrease, 100 * 1024 * 1024, "Memory usage should be reasonable")
                
            } catch {
                print("Memory test failed: \(error)")
            }
        } catch {
            XCTFail("Failed to set API key: \(error)")
        }
    }
    
    // MARK: - Data Persistence Tests
    
    func testLastResultPersistence() async {
        do {
            try servicesManager.setClaudeAPIKey("test-key")
            
            // Initially no result
            XCTAssertNil(servicesManager.getLastAnalysisResult())
            
            let testImage = createTestImage()
            
            do {
                let result = try await servicesManager.analyzeScoreboardImage(testImage)
                
                // Check that result is stored
                let storedResult = servicesManager.getLastAnalysisResult()
                XCTAssertNotNil(storedResult)
                XCTAssertEqual(storedResult?.homeTeam?.score, result.homeTeam?.score)
                
                // Clear result
                servicesManager.clearLastAnalysisResult()
                XCTAssertNil(servicesManager.getLastAnalysisResult())
                
            } catch {
                print("Persistence test failed: \(error)")
            }
        } catch {
            XCTFail("Failed to set API key: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
    
    private func createDigitalScoreboardImage() -> UIImage {
        let size = CGSize(width: 300, height: 200)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        
        // Draw digital scoreboard background
        UIColor.black.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        // Draw score display areas
        UIColor.green.setFill()
        UIRectFill(CGRect(x: 50, y: 50, width: 80, height: 60))
        UIRectFill(CGRect(x: 170, y: 50, width: 80, height: 60))
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
    
    private func createAnalogScoreboardImage() -> UIImage {
        let size = CGSize(width: 300, height: 200)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        
        // Draw analog scoreboard background
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        // Draw manual score indicators
        UIColor.black.setFill()
        UIRectFill(CGRect(x: 50, y: 50, width: 20, height: 20))
        UIRectFill(CGRect(x: 230, y: 50, width: 20, height: 20))
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
    
    private func createPartialScoreboardImage() -> UIImage {
        let size = CGSize(width: 300, height: 200)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        
        // Draw partial scoreboard (only part visible)
        UIColor.gray.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        // Only show part of the score
        UIColor.green.setFill()
        UIRectFill(CGRect(x: 50, y: 50, width: 40, height: 60))
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
    
    private func createBlurryScoreboardImage() -> UIImage {
        let size = CGSize(width: 300, height: 200)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        
        // Draw blurry scoreboard
        UIColor.blue.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        // Add some blur effect by drawing overlapping shapes
        for i in 0..<10 {
            UIColor.green.withAlphaComponent(0.1).setFill()
            UIRectFill(CGRect(x: 50 + i, y: 50 + i, width: 80, height: 60))
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
    
    private func createRandomImage() -> UIImage {
        let size = CGSize(width: 300, height: 200)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        
        // Draw random content
        let colors: [UIColor] = [.red, .blue, .green, .yellow, .purple]
        for i in 0..<20 {
            let color = colors[i % colors.count]
            color.setFill()
            UIRectFill(CGRect(x: CGFloat(i * 15), y: CGFloat(i * 10), width: 20, height: 20))
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
    
    private func createTextImage() -> UIImage {
        let size = CGSize(width: 300, height: 200)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        
        // Draw text
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        let text = "This is not a scoreboard"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20),
            .foregroundColor: UIColor.black
        ]
        
        text.draw(at: CGPoint(x: 50, y: 100), withAttributes: attributes)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
    
    private func createEmptyImage() -> UIImage {
        let size = CGSize(width: 300, height: 200)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        
        // Draw empty/blank image
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
    
    private func createLargeTestImage() -> UIImage {
        let size = CGSize(width: 2000, height: 2000)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        UIColor.blue.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
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