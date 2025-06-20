//
//  KeychainService.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import Foundation
import Security
import LocalAuthentication

@MainActor
class KeychainService: ObservableObject {
    
    // MARK: - Configuration
    
    private let serviceIdentifier = "com.scoreSnap.apiKeys"
    private let accountIdentifier = "claudeAPIKey"
    
    // MARK: - State
    
    @Published var isKeychainAvailable = false
    @Published var lastError: KeychainError?
    
    // MARK: - Initialization
    
    init() {
        checkKeychainAvailability()
    }
    
    // MARK: - Keychain Availability
    
    private func checkKeychainAvailability() {
        // Test if we can access the keychain
        let testData = "test".data(using: .utf8)!
        
        do {
            try store(data: testData, forKey: "testKey")
            try delete(key: "testKey")
            isKeychainAvailable = true
        } catch {
            isKeychainAvailable = false
            lastError = KeychainError.keychainNotAvailable
        }
    }
    
    // MARK: - API Key Management
    
    func storeAPIKey(_ apiKey: String) throws {
        guard !apiKey.isEmpty else {
            throw KeychainError.invalidInput
        }
        
        // Validate API key format
        guard isValidAPIKeyFormat(apiKey) else {
            throw KeychainError.invalidAPIKeyFormat
        }
        
        // Convert to data
        guard let keyData = apiKey.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        
        // Store in keychain
        try store(data: keyData, forKey: accountIdentifier)
    }
    
    func retrieveAPIKey() throws -> String {
        let keyData = try retrieve(key: accountIdentifier)
        
        guard let apiKey = String(data: keyData, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }
        
        return apiKey
    }
    
    func deleteAPIKey() throws {
        try delete(key: accountIdentifier)
    }
    
    func hasAPIKey() -> Bool {
        do {
            _ = try retrieveAPIKey()
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Secure Storage Methods
    
    private func store(data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecUseDataProtectionKeychain as String: true
        ]
        
        // First, try to delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }
    
    private func retrieve(key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseDataProtectionKeychain as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            } else {
                throw KeychainError.retrieveFailed(status)
            }
        }
        
        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }
        
        return data
    }
    
    private func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
    
    // MARK: - API Key Validation
    
    private func isValidAPIKeyFormat(_ apiKey: String) -> Bool {
        // Claude API key format: sk-ant-api03-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        let pattern = "^sk-ant-api03-[a-zA-Z0-9]{32,}$"
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: apiKey.utf16.count)
        return regex.firstMatch(in: apiKey, range: range) != nil
    }
    
    // MARK: - Biometric Authentication (Optional)
    
    func authenticateWithBiometrics() async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw KeychainError.biometricsNotAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Authenticate to access API key") { success, error in
                if let error = error {
                    continuation.resume(throwing: KeychainError.biometricAuthenticationFailed(error))
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }
    
    // MARK: - Key Rotation
    
    func rotateAPIKey() throws {
        guard hasAPIKey() else {
            throw KeychainError.itemNotFound
        }
        
        // For now, just delete the existing key
        // In a real implementation, you might want to support multiple keys
        try deleteAPIKey()
    }
    
    // MARK: - Security Utilities
    
    func clearAllKeys() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecUseDataProtectionKeychain as String: true
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
    
    func getKeychainStatus() -> KeychainStatus {
        return KeychainStatus(
            isAvailable: isKeychainAvailable,
            hasAPIKey: hasAPIKey(),
            lastError: lastError
        )
    }
}

// MARK: - Supporting Types

struct KeychainStatus {
    let isAvailable: Bool
    let hasAPIKey: Bool
    let lastError: KeychainError?
    
    var isReady: Bool {
        return isAvailable && hasAPIKey
    }
}

enum KeychainError: LocalizedError {
    case keychainNotAvailable
    case invalidInput
    case invalidAPIKeyFormat
    case encodingFailed
    case decodingFailed
    case storeFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case itemNotFound
    case invalidData
    case biometricsNotAvailable
    case biometricAuthenticationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .keychainNotAvailable:
            return "Keychain is not available on this device"
        case .invalidInput:
            return "Invalid input provided"
        case .invalidAPIKeyFormat:
            return "Invalid API key format"
        case .encodingFailed:
            return "Failed to encode data"
        case .decodingFailed:
            return "Failed to decode data"
        case .storeFailed(let status):
            return "Failed to store data in keychain: \(status)"
        case .retrieveFailed(let status):
            return "Failed to retrieve data from keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete data from keychain: \(status)"
        case .itemNotFound:
            return "Item not found in keychain"
        case .invalidData:
            return "Invalid data retrieved from keychain"
        case .biometricsNotAvailable:
            return "Biometric authentication is not available"
        case .biometricAuthenticationFailed(let error):
            return "Biometric authentication failed: \(error.localizedDescription)"
        }
    }
} 