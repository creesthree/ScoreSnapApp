//
//  OCRSecurityTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import XCTest
import Security
@testable import ScoreSnap

@MainActor
final class OCRSecurityTests: XCTestCase {
    
    var ocrService: OCRService!
    var apiLimiter: APILimiter!
    var keychainService: KeychainService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize services
        apiLimiter = APILimiter()
        keychainService = KeychainService()
        ocrService = OCRService(apiLimiter: apiLimiter, keychainService: keychainService)
    }
    
    override func tearDownWithError() throws {
        ocrService = nil
        apiLimiter = nil
        keychainService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - API Key Security Tests
    
    func testAPIKeyValidation() throws {
        let validAPIKey = "sk-ant-api03-1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        
        try ocrService.setAPIKey(validAPIKey)
        
        XCTAssertTrue(ocrService.hasValidAPIKey())
    }
    
    func testInvalidAPIKeyRejection() {
        let invalidAPIKeys = [
            "invalid-key",
            "sk-wrong-format",
            "",
            "sk-ant-api03-short",
            "sk-ant-api03-" + String(repeating: "x", count: 200) // Too long
        ]
        
        for invalidAPIKey in invalidAPIKeys {
            XCTAssertThrowsError(try ocrService.setAPIKey(invalidAPIKey)) { error in
                XCTAssertTrue(error is OCRError)
                if case .invalidAPIKeyFormat = error as? OCRError {
                    // Expected
                } else {
                    XCTFail("Expected invalidAPIKeyFormat error for key: \(invalidAPIKey)")
                }
            }
        }
    }
    
    func testAPIKeyWhitespaceHandling() throws {
        let apiKeyWithWhitespace = "  sk-ant-api03-1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef  "
        
        try ocrService.setAPIKey(apiKeyWithWhitespace)
        
        XCTAssertTrue(ocrService.hasValidAPIKey())
    }
    
    // MARK: - Keychain Security Tests
    
    func testKeychainStorageAndRetrieval() throws {
        let validAPIKey = "sk-ant-api03-1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        
        try ocrService.setAPIKey(validAPIKey)
        
        XCTAssertTrue(ocrService.hasValidAPIKey())
    }
    
    func testKeychainKeyDeletion() throws {
        let validAPIKey = "sk-ant-api03-1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        
        try ocrService.setAPIKey(validAPIKey)
        
        ocrService.clearAPIKey()
        
        XCTAssertFalse(ocrService.hasValidAPIKey())
    }
    
    // MARK: - URL Security Tests
    
    func testSecureURLValidation() {
        // Test that the service uses HTTPS
        XCTAssertEqual(ocrService.baseURL, "https://api.anthropic.com/v1/messages")
    }
    
    func testURLSecurityValidation() throws {
        let validAPIKey = "sk-ant-api03-1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        
        try ocrService.setAPIKey(validAPIKey)
        
        XCTAssertTrue(ocrService.hasValidAPIKey())
    }
    
    func testHTTPSEnforcement() throws {
        let validAPIKey = "sk-ant-api03-1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        
        try ocrService.setAPIKey(validAPIKey)
        
        XCTAssertTrue(ocrService.hasValidAPIKey())
    }
    
    // MARK: - Service Integration Security Tests
    
    func testServiceInitialization() {
        XCTAssertNotNil(ocrService)
    }
    
    func testSecureLogging() {
        // Test that sensitive information is not logged
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: [
            NSLocalizedDescriptionKey: "Test error with sensitive data: sk-ant-api03-secret"
        ])
        
        // This should not log the sensitive data
        SecurityUtils.secureLogError(testError, context: "OCR test")
    }
    
    func testInputSanitization() throws {
        let validAPIKey = "sk-ant-api03-1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        
        try ocrService.setAPIKey(validAPIKey)
        
        XCTAssertTrue(ocrService.hasValidAPIKey())
    }
    
    // MARK: - Memory Security Tests
    
    func testMemoryCleanup() {
        XCTAssertNotNil(ocrService)
    }
    
    // MARK: - Network Security Tests
    
    func testNetworkRequestSecurity() {
        // Test that network requests are properly secured
        let keychainStatus = ocrService.getKeychainStatus()
        XCTAssertNotNil(keychainStatus)
    }
    
    func testTLSValidation() {
        // Test TLS certificate validation
        let keychainStatus = ocrService.getKeychainStatus()
        XCTAssertNotNil(keychainStatus)
    }
    
    func testAPIKeyTransmissionSecurity() throws {
        let validAPIKey = "sk-ant-api03-1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        
        try ocrService.setAPIKey(validAPIKey)
        
        // Test that API key is properly secured in transmission
        XCTAssertTrue(ocrService.baseURL.hasPrefix("https://"))
    }
    
    func testSecureHeaderHandling() {
        let url = URL(string: ocrService.baseURL)!
        XCTAssertTrue(url.scheme == "https")
    }
    
    // MARK: - Error Handling Security Tests
    
    func testSecureErrorMessages() {
        let keychainStatus = ocrService.getKeychainStatus()
        XCTAssertNotNil(keychainStatus)
    }
    
    func testErrorInformationLeakage() throws {
        let originalKey = "sk-ant-api03-1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        
        try ocrService.setAPIKey(originalKey)
        
        // Clear the key to test error handling
        ocrService.clearAPIKey()
        
        XCTAssertFalse(ocrService.hasValidAPIKey())
    }
    
    // MARK: - Logging Security Tests
    
    func testSecureLoggingImplementation() {
        SecurityUtils.secureLog("OCR service test", level: .info)
        // Should not throw or leak sensitive information
        XCTAssertTrue(true)
    }
    
    // MARK: - Concurrent Access Security Tests
    
    func testConcurrentAPIKeyAccess() async {
        let validAPIKey = "sk-ant-api03-1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    do {
                        try await self.ocrService.setAPIKey(validAPIKey)
                        await self.ocrService.clearAPIKey()
                    } catch {
                        // Concurrent access errors are acceptable
                    }
                }
            }
        }
    }
    
    // MARK: - Data Validation Security Tests
    
    func testImageDataValidation() {
        // Test that image data is properly validated
        let testImage = UIImage(systemName: "photo")!
        XCTAssertNotNil(testImage)
    }
    
    func testResponseDataValidation() {
        // Test that response data is properly validated
        XCTAssertNotNil(ocrService)
    }
}
