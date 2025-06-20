//
//  OCRServiceTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import XCTest
@testable import ScoreSnap

final class OCRServiceTests: XCTestCase {
    
    var ocrService: OCRService!
    var mockAPILimiter: MockAPILimiter!
    var mockKeychainService: MockKeychainService!
    
    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()
        mockAPILimiter = MockAPILimiter()
        mockKeychainService = MockKeychainService()
        ocrService = OCRService(apiLimiter: mockAPILimiter, keychainService: mockKeychainService)
    }
    
    @MainActor
    override func tearDownWithError() throws {
        ocrService = nil
        mockAPILimiter = nil
        mockKeychainService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - API Key Management Tests
    
    @MainActor
    func testBasicInitialization() {
        XCTAssertNotNil(ocrService)
        XCTAssertFalse(ocrService.hasValidAPIKey())
        
        XCTAssertThrowsError(try ocrService.setAPIKey("invalid-key"))
        XCTAssertFalse(ocrService.hasValidAPIKey())
        
        XCTAssertNoThrow(try ocrService.setAPIKey("sk-ant-api03-1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"))
        XCTAssertTrue(ocrService.hasValidAPIKey())
    }
    
    @MainActor
    func testAPIKeyClearance() throws {
        try ocrService.setAPIKey("sk-ant-api03-1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef")
        XCTAssertTrue(ocrService.hasValidAPIKey())
        
        // Test clearance
        ocrService.clearAPIKey()
        XCTAssertFalse(ocrService.hasValidAPIKey())
    }
    
    // MARK: - Rate Limiting Tests
    
    @MainActor
    func testRateLimitingIntegration() {
        mockAPILimiter.shouldAllowRequest = false
        
        // Rate limiting should be checked before processing
        XCTAssertFalse(mockAPILimiter.canMakeAPICall())
    }
    
    // MARK: - JSON Parsing Tests
    
    func testScoreboardAnalysisParsing() {
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
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            XCTFail("Failed to create JSON data")
            return
        }
        
        do {
            let analysis = try JSONDecoder().decode(ScoreboardAnalysis.self, from: jsonData)
            XCTAssertEqual(analysis.homeTeam?.score, 85)
            XCTAssertEqual(analysis.awayTeam?.score, 78)
            XCTAssertEqual(analysis.gameInfo?.quarter, 4)
            XCTAssertEqual(analysis.confidence, 0.95)
        } catch {
            XCTFail("Failed to decode ScoreboardAnalysis: \(error)")
        }
    }
    
    // MARK: - State Management Tests
    
    @MainActor
    func testInitialState() {
        XCTAssertFalse(ocrService.isProcessing)
        XCTAssertNil(ocrService.getLastAnalysisResult())
        XCTAssertNil(ocrService.lastError)
    }
    
    @MainActor
    func testResultClearing() {
        // Set some mock results
        ocrService.clearLastResult()
        XCTAssertNil(ocrService.getLastAnalysisResult())
        XCTAssertNil(ocrService.lastError)
    }
    
    // MARK: - Error Handling Tests
    
    func testOCRErrorDescriptions() {
        let errors: [OCRError] = [
            .noAPIKey,
            .invalidAPIKey,
            .rateLimitExceeded,
            .invalidURL,
            .invalidRequest,
            .invalidResponse,
            .invalidResponseFormat,
            .unexpectedStatusCode(404),
            .serverError,
            .imageProcessingFailed("Test error"),
            .analysisFailed(NSError(domain: "Test", code: 1, userInfo: nil)),
            .parsingFailed(NSError(domain: "Test", code: 2, userInfo: nil))
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}

// MARK: - Mock Classes

@MainActor
class MockAPILimiter: APILimiter {
    var shouldAllowRequest = true
    var recordAPICallCalled = false
    
    override func canMakeAPICall() -> Bool {
        return shouldAllowRequest
    }
    
    override func recordAPICall() -> Bool {
        recordAPICallCalled = true
        return shouldAllowRequest
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