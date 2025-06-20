//
//  SecurityUtilsTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import XCTest
import CryptoKit
@testable import ScoreSnap

final class SecurityUtilsTests: XCTestCase {
    
    // MARK: - API Key Validation Tests
    
    func testValidClaudeAPIKey() {
        let validKey = "sk-ant-api03-1234567890abcdef1234567890abcdef"
        let result = SecurityUtils.validateAPIKey(validKey)
        
        switch result {
        case .success(let keyType):
            XCTAssertEqual(keyType, .claude)
        case .failure:
            XCTFail("Valid Claude API key should pass validation")
        }
    }
    
    func testValidGenericAPIKey() {
        let validKey = "sk-1234567890abcdef1234567890abcdef1234567890abcdef"
        let result = SecurityUtils.validateAPIKey(validKey)
        
        switch result {
        case .success(let keyType):
            XCTAssertEqual(keyType, .generic)
        case .failure:
            XCTFail("Valid generic API key should pass validation")
        }
    }
    
    func testEmptyAPIKey() {
        let emptyKey = ""
        let result = SecurityUtils.validateAPIKey(emptyKey)
        
        switch result {
        case .success:
            XCTFail("Empty API key should fail validation")
        case .failure(let error):
            XCTAssertEqual(error, .emptyKey)
        }
    }
    
    func testWhitespaceAPIKey() {
        let whitespaceKey = "   "
        let result = SecurityUtils.validateAPIKey(whitespaceKey)
        
        switch result {
        case .success:
            XCTFail("Whitespace API key should fail validation")
        case .failure(let error):
            XCTAssertEqual(error, .emptyKey)
        }
    }
    
    func testTooShortAPIKey() {
        let shortKey = "sk-ant-api03-123"
        let result = SecurityUtils.validateAPIKey(shortKey)
        
        switch result {
        case .success:
            XCTFail("Too short API key should fail validation")
        case .failure(let error):
            XCTAssertEqual(error, .invalidLength)
        }
    }
    
    func testTooLongAPIKey() {
        let longKey = "sk-ant-api03-" + String(repeating: "a", count: 100)
        let result = SecurityUtils.validateAPIKey(longKey)
        
        switch result {
        case .success:
            XCTFail("Too long API key should fail validation")
        case .failure(let error):
            XCTAssertEqual(error, .invalidLength)
        }
    }
    
    func testInvalidFormatAPIKey() {
        let invalidKeys = [
            "invalid-key-format",
            "sk-ant-api03-1234567890abcdef1234567890abcdef!",
            "sk-ant-api03-1234567890abcdef1234567890abcdef ",
            " sk-ant-api03-1234567890abcdef1234567890abcdef"
        ]
        
        for key in invalidKeys {
            let result = SecurityUtils.validateAPIKey(key)
            
            switch result {
            case .success:
                XCTFail("Invalid API key should fail validation: \(key)")
            case .failure(let error):
                XCTAssertEqual(error, .invalidFormat)
            }
        }
    }
    
    // MARK: - API Key Sanitization Tests
    
    func testSanitizeAPIKey() {
        let keysWithWhitespace = [
            "  sk-ant-api03-1234567890abcdef1234567890abcdef  ",
            "\nsk-ant-api03-1234567890abcdef1234567890abcdef\n",
            "\tsk-ant-api03-1234567890abcdef1234567890abcdef\t"
        ]
        
        let expected = "sk-ant-api03-1234567890abcdef1234567890abcdef"
        
        for key in keysWithWhitespace {
            let sanitized = SecurityUtils.sanitizeAPIKey(key)
            XCTAssertEqual(sanitized, expected)
        }
    }
    
    func testSanitizeAlreadyCleanAPIKey() {
        let cleanKey = "sk-ant-api03-1234567890abcdef1234567890abcdef"
        let sanitized = SecurityUtils.sanitizeAPIKey(cleanKey)
        XCTAssertEqual(sanitized, cleanKey)
    }
    
    // MARK: - Secure Logging Tests
    
    func testSecureLog() {
        // This test verifies that secure logging doesn't crash
        // In a real app, you might want to capture log output
        SecurityUtils.secureLog("Test message")
        SecurityUtils.secureLog("Debug message", level: .debug)
        SecurityUtils.secureLog("Warning message", level: .warning)
        SecurityUtils.secureLog("Error message", level: .error)
    }
    
    func testSecureLogError() {
        let testError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        SecurityUtils.secureLogError(testError, context: "Test context")
    }
    
    func testSecureLogErrorWithAPIKey() {
        let errorWithAPIKey = NSError(domain: "test", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Error with sk-ant-api03-1234567890abcdef1234567890abcdef in message"
        ])
        SecurityUtils.secureLogError(errorWithAPIKey, context: "Test context")
    }
    
    // MARK: - Data Encryption Tests
    
    func testDataEncryptionAndDecryption() throws {
        let originalData = "Hello, World!".data(using: .utf8)!
        let key = SecurityUtils.generateSymmetricKey()
        
        let encryptedData = try SecurityUtils.encryptData(originalData, using: key)
        XCTAssertNotEqual(originalData, encryptedData)
        
        let decryptedData = try SecurityUtils.decryptData(encryptedData, using: key)
        XCTAssertEqual(originalData, decryptedData)
    }
    
    func testDataEncryptionWithWrongKey() throws {
        let originalData = "Hello, World!".data(using: .utf8)!
        let key1 = SecurityUtils.generateSymmetricKey()
        let key2 = SecurityUtils.generateSymmetricKey()
        
        let encryptedData = try SecurityUtils.encryptData(originalData, using: key1)
        
        XCTAssertThrowsError(try SecurityUtils.decryptData(encryptedData, using: key2)) { error in
            XCTAssertTrue(error is SecurityError)
        }
    }
    
    func testGenerateSymmetricKey() {
        let key1 = SecurityUtils.generateSymmetricKey()
        let key2 = SecurityUtils.generateSymmetricKey()
        
        XCTAssertNotEqual(key1, key2)
        XCTAssertEqual(key1.bitCount, 256)
        XCTAssertEqual(key2.bitCount, 256)
    }
    
    // MARK: - Hash Functions Tests
    
    func testHashString() {
        let input = "Hello, World!"
        let hash1 = SecurityUtils.hashString(input)
        let hash2 = SecurityUtils.hashString(input)
        
        XCTAssertEqual(hash1, hash2)
        XCTAssertEqual(hash1.count, 64) // SHA256 produces 64 hex characters
        XCTAssertNotEqual(hash1, input)
    }
    
    func testHashData() {
        let inputData = "Hello, World!".data(using: .utf8)!
        let hash1 = SecurityUtils.hashData(inputData)
        let hash2 = SecurityUtils.hashData(inputData)
        
        XCTAssertEqual(hash1, hash2)
        XCTAssertEqual(hash1.count, 64) // SHA256 produces 64 hex characters
    }
    
    func testHashConsistency() {
        let input = "Test string"
        let hash1 = SecurityUtils.hashString(input)
        let hash2 = SecurityUtils.hashString(input)
        let hash3 = SecurityUtils.hashString(input)
        
        XCTAssertEqual(hash1, hash2)
        XCTAssertEqual(hash2, hash3)
    }
    
    // MARK: - Secure Random Generation Tests
    
    func testGenerateSecureRandomString() {
        let random1 = SecurityUtils.generateSecureRandomString(length: 16)
        let random2 = SecurityUtils.generateSecureRandomString(length: 16)
        
        XCTAssertEqual(random1.count, 16)
        XCTAssertEqual(random2.count, 16)
        XCTAssertNotEqual(random1, random2)
    }
    
    func testGenerateSecureRandomStringDefaultLength() {
        let random = SecurityUtils.generateSecureRandomString()
        XCTAssertEqual(random.count, 32)
    }
    
    func testGenerateSecureRandomData() {
        let random1 = SecurityUtils.generateSecureRandomData(length: 16)
        let random2 = SecurityUtils.generateSecureRandomData(length: 16)
        
        XCTAssertEqual(random1.count, 16)
        XCTAssertEqual(random2.count, 16)
        XCTAssertNotEqual(random1, random2)
    }
    
    func testGenerateSecureRandomDataDefaultLength() {
        let random = SecurityUtils.generateSecureRandomData()
        XCTAssertEqual(random.count, 32)
    }
    
    // MARK: - Network Security Tests
    
    func testValidateURL() {
        let validURLs = [
            URL(string: "https://api.anthropic.com/v1/messages")!,
            URL(string: "https://api.openai.com/v1/chat/completions")!
        ]
        
        let invalidURLs = [
            URL(string: "http://api.anthropic.com/v1/messages")!, // HTTP not HTTPS
            URL(string: "https://malicious-site.com/api")!, // Not in allowed domains
            URL(string: "ftp://api.anthropic.com/v1/messages")! // Wrong protocol
        ]
        
        for url in validURLs {
            XCTAssertTrue(SecurityUtils.validateURL(url), "URL should be valid: \(url)")
        }
        
        for url in invalidURLs {
            XCTAssertFalse(SecurityUtils.validateURL(url), "URL should be invalid: \(url)")
        }
    }
    
    // MARK: - Input Sanitization Tests
    
    func testSanitizeInput() {
        let dangerousInputs = [
            "<script>alert('xss')</script>",
            "Hello & World",
            "Test'quote",
            "Test\"quote",
            "Test<>tags"
        ]
        
        let expectedOutputs = [
            "scriptalert('xss')/script",
            "Hello  World",
            "Testquote",
            "Testquote",
            "Testtags"
        ]
        
        for (input, expected) in zip(dangerousInputs, expectedOutputs) {
            let sanitized = SecurityUtils.sanitizeInput(input)
            XCTAssertEqual(sanitized, expected)
        }
    }
    
    func testSanitizeSafeInput() {
        let safeInput = "Hello, World! This is safe text."
        let sanitized = SecurityUtils.sanitizeInput(safeInput)
        XCTAssertEqual(sanitized, safeInput)
    }
    
    func testValidateInput() {
        let validInputs = [
            "Normal text",
            "Text with numbers 123",
            "Text with symbols !@#$%",
            String(repeating: "a", count: 1000) // Max length
        ]
        
        let invalidInputs = [
            String(repeating: "a", count: 1001), // Too long
            "Text with null\0byte",
            "" // Empty string
        ]
        
        for input in validInputs {
            XCTAssertTrue(SecurityUtils.validateInput(input), "Input should be valid: \(input)")
        }
        
        for input in invalidInputs {
            XCTAssertFalse(SecurityUtils.validateInput(input), "Input should be invalid: \(input)")
        }
    }
    
    func testValidateInputWithCustomMaxLength() {
        let input = "Short text"
        XCTAssertTrue(SecurityUtils.validateInput(input, maxLength: 5))
        XCTAssertFalse(SecurityUtils.validateInput(input, maxLength: 3))
    }
    
    // MARK: - Error Type Tests
    
    func testAPIKeyValidationErrorDescriptions() {
        let errors: [APIKeyValidationError] = [
            .emptyKey,
            .invalidLength,
            .invalidFormat
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    func testSecurityErrorDescriptions() {
        let errors: [SecurityError] = [
            .encryptionFailed,
            .decryptionFailed,
            .invalidKey,
            .invalidData
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    // MARK: - Performance Tests
    
    func testHashPerformance() {
        let input = "Performance test string"
        
        measure {
            for _ in 0..<1000 {
                _ = SecurityUtils.hashString(input)
            }
        }
    }
    
    func testEncryptionPerformance() throws {
        let data = "Performance test data".data(using: .utf8)!
        let key = SecurityUtils.generateSymmetricKey()
        
        measure {
            do {
                let encrypted = try SecurityUtils.encryptData(data, using: key)
                _ = try SecurityUtils.decryptData(encrypted, using: key)
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
    
    func testRandomGenerationPerformance() {
        measure {
            for _ in 0..<100 {
                _ = SecurityUtils.generateSecureRandomString()
                _ = SecurityUtils.generateSecureRandomData()
            }
        }
    }
} 