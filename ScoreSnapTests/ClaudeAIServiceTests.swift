//
//  ClaudeAIServiceTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import XCTest
@testable import ScoreSnap

final class ClaudeAIServiceTests: XCTestCase {
    
    var claudeAIService: ClaudeAIService!
    var mockAPILimiter: MockAPILimiter!
    var mockKeychainService: MockKeychainService!
    
    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()
        mockAPILimiter = MockAPILimiter()
        mockKeychainService = MockKeychainService()
        claudeAIService = ClaudeAIService(apiLimiter: mockAPILimiter, keychainService: mockKeychainService)
    }
    
    @MainActor
    override func tearDownWithError() throws {
        claudeAIService = nil
        mockAPILimiter = nil
        mockKeychainService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - API Key Management Tests
    
    @MainActor
    func testAPIKeyValidation() {
        // Initially no API key
        XCTAssertFalse(claudeAIService.hasValidAPIKey())
        
        // Invalid API key
        do {
            try claudeAIService.setAPIKey("invalid-key")
            XCTAssertFalse(claudeAIService.hasValidAPIKey())
            
            // Valid API key format
            try claudeAIService.setAPIKey("sk-ant-api03-1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef")
            XCTAssertTrue(claudeAIService.hasValidAPIKey())
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    @MainActor
    func testAPIKeyClearing() {
        do {
            try claudeAIService.setAPIKey("sk-ant-api03-1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef")
            XCTAssertTrue(claudeAIService.hasValidAPIKey())
            
            claudeAIService.clearAPIKey()
            XCTAssertFalse(claudeAIService.hasValidAPIKey())
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Rate Limiting Tests
    
    @MainActor
    func testRateLimitCheck() {
        mockAPILimiter.canMakeAPICallReturnValue = false
        XCTAssertFalse(mockAPILimiter.canMakeAPICall())
        
        mockAPILimiter.canMakeAPICallReturnValue = true
        XCTAssertTrue(mockAPILimiter.canMakeAPICall())
    }
    
    @MainActor
    func testAPICallRecording() {
        XCTAssertFalse(mockAPILimiter.recordAPICallCalled)
        
        let result = mockAPILimiter.recordAPICall()
        XCTAssertTrue(result)
        XCTAssertTrue(mockAPILimiter.recordAPICallCalled)
    }
    
    // MARK: - JSON Parsing Tests
    
    func testValidResponseParsing() {
        // Test that we can parse a valid JSON response
        let jsonString = """
        {
          "homeTeam": {
            "score": 85
          },
          "awayTeam": {
            "score": 78
          },
          "gameInfo": {
            "quarter": 4,
            "timeRemaining": "02:30",
            "possession": "home",
            "shotClock": 14
          },
          "confidence": 0.95,
          "notes": "Clear scoreboard image with good lighting"
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        
        do {
            let analysis = try JSONDecoder().decode(ScoreboardAnalysis.self, from: jsonData)
            
            XCTAssertEqual(analysis.homeTeam?.score, 85)
            XCTAssertNil(analysis.homeTeam?.name) // Team names should not be extracted
            XCTAssertNil(analysis.homeTeam?.fouls) // Fouls should not be extracted
            XCTAssertNil(analysis.homeTeam?.timeouts) // Timeouts should not be extracted
            
            XCTAssertEqual(analysis.awayTeam?.score, 78)
            XCTAssertNil(analysis.awayTeam?.name) // Team names should not be extracted
            XCTAssertNil(analysis.awayTeam?.fouls) // Fouls should not be extracted
            XCTAssertNil(analysis.awayTeam?.timeouts) // Timeouts should not be extracted
            
            XCTAssertEqual(analysis.gameInfo?.quarter, 4)
            XCTAssertEqual(analysis.gameInfo?.timeRemaining, "02:30")
            XCTAssertEqual(analysis.gameInfo?.possession, "home")
            XCTAssertEqual(analysis.gameInfo?.shotClock, 14)
            
            XCTAssertEqual(analysis.confidence, 0.95)
            XCTAssertEqual(analysis.notes, "Clear scoreboard image with good lighting")
            
        } catch {
            XCTFail("Failed to parse valid JSON: \(error)")
        }
    }
    
    func testInvalidResponseParsing() {
        // Test handling of invalid JSON
        let invalidJsonString = """
        {
          "invalid": "structure"
        }
        """
        
        let jsonData = invalidJsonString.data(using: .utf8)!
        
        do {
            let analysis = try JSONDecoder().decode(ScoreboardAnalysis.self, from: jsonData)
            
            // Should still parse but with nil values
            XCTAssertNil(analysis.homeTeam)
            XCTAssertNil(analysis.awayTeam)
            XCTAssertNil(analysis.gameInfo)
            XCTAssertNil(analysis.confidence)
            XCTAssertNil(analysis.notes)
            
        } catch {
            // JSON parsing failure is also acceptable for invalid structure
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    // MARK: - State Management Tests
    
    @MainActor
    func testInitialState() {
        XCTAssertFalse(claudeAIService.isProcessing)
        XCTAssertNil(claudeAIService.getLastAnalysisResult())
        XCTAssertNil(claudeAIService.lastError)
    }
    
    @MainActor
    func testResultClearing() {
        claudeAIService.clearLastResult()
        XCTAssertNil(claudeAIService.getLastAnalysisResult())
        XCTAssertNil(claudeAIService.lastError)
    }
    
    // MARK: - Error Handling Tests
    
    func testClaudeAIErrorDescriptions() {
        let errors: [ClaudeAIError] = [
            .noAPIKey,
            .invalidAPIKey,
            .rateLimitExceeded,
            .invalidURL,
            .invalidRequest,
            .invalidResponse,
            .invalidResponseFormat,
            .serverError,
            .unexpectedStatusCode(404),
            .imageProcessingFailed("Test error"),
            .jsonParsingFailed,
            .analysisFailed(NSError(domain: "test", code: 1, userInfo: nil))
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
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
}

// MARK: - Mock Classes

@MainActor
class MockAPILimiter: APILimiter {
    var canMakeAPICallReturnValue = true
    var recordAPICallCalled = false
    
    override func canMakeAPICall() -> Bool {
        return canMakeAPICallReturnValue
    }
    
    override func recordAPICall() -> Bool {
        recordAPICallCalled = true
        return true
    }
}

@MainActor
class MockKeychainService: KeychainService {
    private var storedKey: String?
    
    override func storeAPIKey(_ key: String) throws {
        storedKey = key
    }
    
    override func retrieveAPIKey() throws -> String {
        guard let key = storedKey else {
            throw KeychainError.itemNotFound
        }
        return key
    }
    
    override func deleteAPIKey() throws {
        storedKey = nil
    }
}