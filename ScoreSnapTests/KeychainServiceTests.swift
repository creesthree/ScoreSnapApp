//
//  KeychainServiceTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import XCTest
import LocalAuthentication
@testable import ScoreSnap

@MainActor
final class KeychainServiceTests: XCTestCase {
    
    var keychainService: KeychainService!
    
    override func setUp() {
        super.setUp()
        keychainService = KeychainService()
    }
    
    override func tearDown() {
        // Clean up any stored keys
        try? keychainService.clearAllKeys()
        keychainService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testKeychainServiceInitialization() {
        XCTAssertNotNil(keychainService)
        XCTAssertTrue(keychainService.isKeychainAvailable)
    }
    
    // MARK: - API Key Management Tests
    
    func testStoreValidAPIKey() throws {
        let validAPIKey = "sk-ant-api03-1234567890abcdef1234567890abcdef"
        
        try keychainService.storeAPIKey(validAPIKey)
        
        XCTAssertTrue(keychainService.hasAPIKey())
        
        let retrievedKey = try keychainService.retrieveAPIKey()
        XCTAssertEqual(retrievedKey, validAPIKey)
    }
    
    func testStoreInvalidAPIKey() {
        let invalidAPIKey = "invalid-key-format"
        
        XCTAssertThrowsError(try keychainService.storeAPIKey(invalidAPIKey)) { error in
            XCTAssertTrue(error is KeychainError)
            if case .invalidAPIKeyFormat = error as? KeychainError {
                // Expected error
            } else {
                XCTFail("Expected invalidAPIKeyFormat error")
            }
        }
    }
    
    func testStoreEmptyAPIKey() {
        let emptyKey = ""
        
        XCTAssertThrowsError(try keychainService.storeAPIKey(emptyKey)) { error in
            XCTAssertTrue(error is KeychainError)
            if case .invalidInput = error as? KeychainError {
                // Expected error
            } else {
                XCTFail("Expected invalidInput error")
            }
        }
    }
    
    func testStoreWhitespaceAPIKey() {
        let whitespaceKey = "   "
        
        XCTAssertThrowsError(try keychainService.storeAPIKey(whitespaceKey)) { error in
            XCTAssertTrue(error is KeychainError)
            if case .invalidInput = error as? KeychainError {
                // Expected error
            } else {
                XCTFail("Expected invalidInput error")
            }
        }
    }
    
    func testRetrieveNonExistentAPIKey() {
        XCTAssertThrowsError(try keychainService.retrieveAPIKey()) { error in
            XCTAssertTrue(error is KeychainError)
            if case .itemNotFound = error as? KeychainError {
                // Expected error
            } else {
                XCTFail("Expected itemNotFound error")
            }
        }
    }
    
    func testDeleteAPIKey() throws {
        let validAPIKey = "sk-ant-api03-1234567890abcdef1234567890abcdef"
        
        // Store the key
        try keychainService.storeAPIKey(validAPIKey)
        XCTAssertTrue(keychainService.hasAPIKey())
        
        // Delete the key
        try keychainService.deleteAPIKey()
        XCTAssertFalse(keychainService.hasAPIKey())
        
        // Verify it's gone
        XCTAssertThrowsError(try keychainService.retrieveAPIKey())
    }
    
    func testDeleteNonExistentAPIKey() {
        // Should not throw when deleting non-existent key
        XCTAssertNoThrow(try keychainService.deleteAPIKey())
    }
    
    func testHasAPIKey() throws {
        XCTAssertFalse(keychainService.hasAPIKey())
        
        let validAPIKey = "sk-ant-api03-1234567890abcdef1234567890abcdef"
        try keychainService.storeAPIKey(validAPIKey)
        
        XCTAssertTrue(keychainService.hasAPIKey())
    }
    
    // MARK: - API Key Validation Tests
    
    func testValidClaudeAPIKeyFormat() {
        let validKeys = [
            "sk-ant-api03-1234567890abcdef1234567890abcdef",
            "sk-ant-api03-abcdef1234567890abcdef1234567890",
            "sk-ant-api03-1234567890abcdef1234567890abcdef1234567890abcdef"
        ]
        
        for key in validKeys {
            XCTAssertTrue(keychainService.hasAPIKey() == false) // Should be false initially
            XCTAssertNoThrow(try keychainService.storeAPIKey(key))
            XCTAssertTrue(keychainService.hasAPIKey())
            XCTAssertNoThrow(try keychainService.deleteAPIKey())
        }
    }
    
    func testInvalidAPIKeyFormats() {
        let invalidKeys = [
            "sk-ant-api03-123", // Too short
            "sk-ant-api03-1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef", // Too long
            "invalid-key-format",
            "sk-ant-api03-", // Missing key part
            "sk-ant-api03-1234567890abcdef1234567890abcdef!", // Invalid character
            "sk-ant-api03-1234567890abcdef1234567890abcdef ", // Trailing space
            " sk-ant-api03-1234567890abcdef1234567890abcdef" // Leading space
        ]
        
        for key in invalidKeys {
            XCTAssertThrowsError(try keychainService.storeAPIKey(key)) { error in
                XCTAssertTrue(error is KeychainError)
            }
        }
    }
    
    // MARK: - Key Rotation Tests
    
    func testRotateAPIKey() throws {
        let originalKey = "sk-ant-api03-1234567890abcdef1234567890abcdef"
        
        // Store original key
        try keychainService.storeAPIKey(originalKey)
        XCTAssertTrue(keychainService.hasAPIKey())
        
        // Rotate key (should delete existing)
        try keychainService.rotateAPIKey()
        XCTAssertFalse(keychainService.hasAPIKey())
    }
    
    func testRotateNonExistentAPIKey() {
        XCTAssertThrowsError(try keychainService.rotateAPIKey()) { error in
            XCTAssertTrue(error is KeychainError)
            if case .itemNotFound = error as? KeychainError {
                // Expected error
            } else {
                XCTFail("Expected itemNotFound error")
            }
        }
    }
    
    // MARK: - Clear All Keys Tests
    
    func testClearAllKeys() throws {
        let validAPIKey = "sk-ant-api03-1234567890abcdef1234567890abcdef"
        
        // Store a key
        try keychainService.storeAPIKey(validAPIKey)
        XCTAssertTrue(keychainService.hasAPIKey())
        
        // Clear all keys
        try keychainService.clearAllKeys()
        XCTAssertFalse(keychainService.hasAPIKey())
    }
    
    func testClearAllKeysWhenEmpty() {
        XCTAssertNoThrow(try keychainService.clearAllKeys())
    }
    
    // MARK: - Keychain Status Tests
    
    func testGetKeychainStatus() {
        let status = keychainService.getKeychainStatus()
        
        XCTAssertTrue(status.isAvailable)
        XCTAssertFalse(status.hasAPIKey)
        XCTAssertNil(status.lastError)
        XCTAssertFalse(status.isReady)
    }
    
    func testGetKeychainStatusWithAPIKey() throws {
        let validAPIKey = "sk-ant-api03-1234567890abcdef1234567890abcdef"
        try keychainService.storeAPIKey(validAPIKey)
        
        let status = keychainService.getKeychainStatus()
        
        XCTAssertTrue(status.isAvailable)
        XCTAssertTrue(status.hasAPIKey)
        XCTAssertNil(status.lastError)
        XCTAssertTrue(status.isReady)
    }
    
    // MARK: - Error Handling Tests
    
    func testKeychainErrorDescriptions() {
        let errors: [KeychainError] = [
            .keychainNotAvailable,
            .invalidInput,
            .invalidAPIKeyFormat,
            .encodingFailed,
            .decodingFailed,
            .storeFailed(errSecDuplicateItem),
            .retrieveFailed(errSecItemNotFound),
            .deleteFailed(errSecItemNotFound),
            .itemNotFound,
            .invalidData,
            .biometricsNotAvailable,
            .biometricAuthenticationFailed(NSError(domain: "test", code: 1))
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    // MARK: - Performance Tests
    
    func testAPIKeyStoragePerformance() throws {
        let validAPIKey = "sk-ant-api03-1234567890abcdef1234567890abcdef"
        
        measure {
            do {
                try keychainService.storeAPIKey(validAPIKey)
                try keychainService.deleteAPIKey()
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
    
    func testAPIKeyRetrievalPerformance() throws {
        let validAPIKey = "sk-ant-api03-1234567890abcdef1234567890abcdef"
        try keychainService.storeAPIKey(validAPIKey)
        
        measure {
            do {
                _ = try keychainService.retrieveAPIKey()
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
    
    // MARK: - Concurrency Tests
    
    func testConcurrentAPIKeyOperations() async throws {
        let validAPIKey = "sk-ant-api03-1234567890abcdef1234567890abcdef"
        
        // Test concurrent storage
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    do {
                        try await self.keychainService.storeAPIKey(validAPIKey)
                        try await self.keychainService.deleteAPIKey()
                    } catch {
                        XCTFail("Concurrent operation failed: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testVeryLongAPIKey() {
        let longKey = "sk-ant-api03-" + String(repeating: "a", count: 100)
        
        XCTAssertThrowsError(try keychainService.storeAPIKey(longKey)) { error in
            XCTAssertTrue(error is KeychainError)
        }
    }
    
    func testUnicodeAPIKey() {
        let unicodeKey = "sk-ant-api03-1234567890abcdef1234567890abcdef🚀"
        
        XCTAssertThrowsError(try keychainService.storeAPIKey(unicodeKey)) { error in
            XCTAssertTrue(error is KeychainError)
        }
    }
    
    func testSpecialCharactersAPIKey() {
        let specialKey = "sk-ant-api03-1234567890abcdef1234567890abcdef@#$%"
        
        XCTAssertThrowsError(try keychainService.storeAPIKey(specialKey)) { error in
            XCTAssertTrue(error is KeychainError)
        }
    }
} 