//
//  OCRIntegrationTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import XCTest
import UIKit
@testable import ScoreSnap

@MainActor
final class OCRIntegrationTests: XCTestCase {
    
    var servicesManager: ServicesManager!
    var ocrService: OCRService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        servicesManager = ServicesManager.shared
        ocrService = servicesManager.ocrService
    }
    
    override func tearDownWithError() throws {
        ocrService = nil
        servicesManager = nil
        try super.tearDownWithError()
    }
    
    func testServicesManagerIntegration() {
        // Test that OCRService is properly integrated
        XCTAssertNotNil(servicesManager.ocrService)
        XCTAssertFalse(servicesManager.isOCRServiceReady) // No API key initially
        
        // Set API key
        do {
            try servicesManager.setOCRAPIKey("test-key")
            XCTAssertTrue(servicesManager.isOCRServiceReady)
            
            // Clear API key
            servicesManager.clearOCRAPIKey()
            XCTAssertFalse(servicesManager.isOCRServiceReady)
        } catch {
            XCTFail("Failed to set API key: \(error)")
        }
    }
    
    func testAPILimiterIntegration() {
        // Test that OCRService respects API limits
        do {
            try servicesManager.setOCRAPIKey("sk-ant-api03-1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef")
            XCTAssertTrue(servicesManager.isOCRServiceReady)
            
            // Test that we can check API limits
            let canMakeCall = servicesManager.canMakeAPICall()
            XCTAssertTrue(canMakeCall) // Should be true initially
            
        } catch {
            XCTFail("Failed to set API key: \(error)")
        }
    }
    
    func testInvalidAPIKeyHandling() {
        // Test handling of invalid API keys
        XCTAssertThrowsError(try servicesManager.setOCRAPIKey("invalid-key")) { error in
            XCTAssertTrue(error is OCRError)
        }
        
        XCTAssertFalse(servicesManager.isOCRServiceReady)
    }
    
    // MARK: - Live API Tests (Disabled by default)
    
    func testLiveAPIAnalysis() async throws {
        // This test is disabled by default to avoid API costs
        // To enable: set ENABLE_LIVE_API_TESTS environment variable
        guard ProcessInfo.processInfo.environment["ENABLE_LIVE_API_TESTS"] == "1" else {
            throw XCTSkip("Live API tests are disabled. Set ENABLE_LIVE_API_TESTS=1 to enable.")
        }
        
        guard let apiKey = ProcessInfo.processInfo.environment["OCR_API_KEY"] else {
            throw XCTSkip("OCR_API_KEY environment variable not set")
        }
        
        do {
            try servicesManager.setOCRAPIKey(apiKey)
            
            // Create a simple test image
            let testImage = createTestScoreboardImage()
            
            let result = try await servicesManager.analyzeScoreboard(testImage)
            XCTAssertNotNil(result)
            
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
            XCTFail("Live API test failed: \(error)")
        }
    }
    
    func testAPIRateLimiting() async throws {
        // Test that rate limiting works correctly
        guard ProcessInfo.processInfo.environment["ENABLE_LIVE_API_TESTS"] == "1" else {
            throw XCTSkip("Live API tests are disabled")
        }
        
        guard let apiKey = ProcessInfo.processInfo.environment["OCR_API_KEY"] else {
            throw XCTSkip("OCR_API_KEY environment variable not set")
        }
        
        do {
            try servicesManager.setOCRAPIKey(apiKey)
            
            let testImage = createTestScoreboardImage()
            
            // Make multiple rapid requests
            for i in 1...5 {
                do {
                    _ = try await servicesManager.analyzeScoreboard(testImage)
                } catch {
                    // Rate limiting or other errors are expected
                    XCTAssertTrue(error is OCRError || error is ServiceError)
                }
            }
            
        } catch {
            XCTFail("Rate limiting test setup failed: \(error)")
        }
    }
    
    func testErrorHandling() async {
        // Test various error conditions
        do {
            // Test with no API key
            servicesManager.clearOCRAPIKey()
            let testImage = createTestScoreboardImage()
            
            do {
                _ = try await servicesManager.analyzeScoreboard(testImage)
                XCTFail("Should have thrown an error")
            } catch {
                XCTAssertTrue(error is ServiceError)
            }
            
            // Test with invalid API key
            try servicesManager.setOCRAPIKey("sk-ant-api03-invalid")
            
            do {
                _ = try await servicesManager.analyzeScoreboard(testImage)
                XCTFail("Should have thrown an error")
            } catch {
                XCTAssertTrue(error is OCRError || error is ServiceError)
            }
            
        } catch {
            XCTFail("Error handling test failed: \(error)")
        }
    }
    
    func testImageProcessing() {
        // Test image processing capabilities
        let testImage = createTestScoreboardImage()
        
        // Test that image can be processed
        XCTAssertNotNil(testImage)
        XCTAssertGreaterThan(testImage.size.width, 0)
        XCTAssertGreaterThan(testImage.size.height, 0)
        
        // Test JPEG conversion
        let jpegData = testImage.jpegData(compressionQuality: 0.8)
        XCTAssertNotNil(jpegData)
        XCTAssertGreaterThan(jpegData?.count ?? 0, 0)
    }
    
    func testConcurrentRequests() async throws {
        // Test handling of concurrent requests
        guard ProcessInfo.processInfo.environment["ENABLE_LIVE_API_TESTS"] == "1" else {
            throw XCTSkip("Live API tests are disabled")
        }
        
        guard let apiKey = ProcessInfo.processInfo.environment["OCR_API_KEY"] else {
            throw XCTSkip("OCR_API_KEY environment variable not set")
        }
        
        do {
            try servicesManager.setOCRAPIKey(apiKey)
            
            let testImage = createTestScoreboardImage()
            
            // Make concurrent requests
            await withTaskGroup(of: Void.self) { group in
                for i in 1...3 {
                    group.addTask {
                        do {
                            _ = try await self.servicesManager.analyzeScoreboard(testImage)
                        } catch {
                            // Errors are expected due to rate limiting
                            XCTAssertTrue(error is OCRError || error is ServiceError)
                        }
                    }
                }
            }
            
        } catch {
            XCTFail("Concurrent requests test failed: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestScoreboardImage() -> UIImage {
        let size = CGSize(width: 400, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Create a simple mock scoreboard
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add some text to simulate scoreboard content
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white,
                .font: UIFont.boldSystemFont(ofSize: 24)
            ]
            
            "HOME 85".draw(at: CGPoint(x: 50, y: 50), withAttributes: attributes)
            "AWAY 78".draw(at: CGPoint(x: 250, y: 50), withAttributes: attributes)
            "Q4 2:30".draw(at: CGPoint(x: 170, y: 100), withAttributes: attributes)
        }
    }
} 