//
//  SecurityUtils.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import Foundation
import CryptoKit
import CommonCrypto

struct SecurityUtils {
    
    // MARK: - API Key Validation
    
    static func validateAPIKey(_ apiKey: String) -> APIKeyValidationResult {
        // Check if empty
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.emptyKey)
        }
        
        // Check length
        guard apiKey.count >= 40 && apiKey.count <= 100 else {
            return .failure(.invalidLength)
        }
        
        // Check format for Claude API key
        let claudePattern = "^sk-ant-api03-[a-zA-Z0-9]{32,}$"
        let claudeRegex = try! NSRegularExpression(pattern: claudePattern)
        let claudeRange = NSRange(location: 0, length: apiKey.utf16.count)
        
        if claudeRegex.firstMatch(in: apiKey, range: claudeRange) != nil {
            return .success(.claude)
        }
        
        // Check for other common API key patterns
        let genericPattern = "^[a-zA-Z0-9_-]{32,}$"
        let genericRegex = try! NSRegularExpression(pattern: genericPattern)
        let genericRange = NSRange(location: 0, length: apiKey.utf16.count)
        
        if genericRegex.firstMatch(in: apiKey, range: genericRange) != nil {
            return .success(.generic)
        }
        
        return .failure(.invalidFormat)
    }
    
    static func sanitizeAPIKey(_ apiKey: String) -> String {
        // Remove whitespace and newlines
        return apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Secure Logging
    
    static func secureLog(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(level.rawValue.uppercased())] [\(fileName):\(line)] \(function): \(message)"
        print(logMessage)
        #endif
    }
    
    static func secureLogError(_ error: Error, context: String = "", file: String = #file, function: String = #function, line: Int = #line) {
        // Never log sensitive information
        let sanitizedError = sanitizeErrorMessage(error.localizedDescription)
        secureLog("Error in \(context): \(sanitizedError)", level: .error, file: file, function: function, line: line)
    }
    
    private static func sanitizeErrorMessage(_ message: String) -> String {
        // Remove any potential sensitive data from error messages
        var sanitized = message
        
        // Remove API keys
        let apiKeyPattern = "sk-ant-api[0-9a-zA-Z-]+"
        sanitized = sanitized.replacingOccurrences(of: apiKeyPattern, with: "[API_KEY]", options: .regularExpression)
        
        // Remove other sensitive patterns
        let sensitivePatterns = [
            "Bearer [a-zA-Z0-9._-]+",
            "key=[a-zA-Z0-9._-]+",
            "token=[a-zA-Z0-9._-]+"
        ]
        
        for pattern in sensitivePatterns {
            sanitized = sanitized.replacingOccurrences(of: pattern, with: "[SENSITIVE_DATA]", options: .regularExpression)
        }
        
        return sanitized
    }
    
    // MARK: - Data Encryption (Optional)
    
    static func encryptData(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw SecurityError.encryptionFailed
        }
        return combined
    }
    
    static func decryptData(_ data: Data, using key: SymmetricKey) throws -> Data {
        guard let sealedBox = try? AES.GCM.SealedBox(combined: data) else {
            throw SecurityError.decryptionFailed
        }
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    static func generateSymmetricKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    // MARK: - Hash Functions
    
    static func hashString(_ string: String) -> String {
        let inputData = Data(string.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    static func hashData(_ data: Data) -> String {
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Secure Random Generation
    
    static func generateSecureRandomString(length: Int = 32) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    static func generateSecureRandomData(length: Int = 32) -> Data {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return Data(bytes)
    }
    
    // MARK: - Certificate Pinning (Future Implementation)
    
    static func validateCertificate(_ serverTrust: SecTrust, domain: String) -> Bool {
        // Use modern API for iOS 15+
        if #available(iOS 15.0, *) {
            var error: CFError?
            let isValid = SecTrustEvaluateWithError(serverTrust, &error)
            return isValid
        } else {
            // Fallback for iOS 14 (though we're targeting iOS 15+)
            var result: SecTrustResultType = .invalid
            let status = SecTrustEvaluate(serverTrust, &result)
            return status == errSecSuccess && (result == .unspecified || result == .proceed)
        }
    }
    
    // MARK: - Network Security
    
    static func validateURL(_ url: URL) -> Bool {
        // Ensure HTTPS is used
        guard url.scheme == "https" else {
            return false
        }
        
        // Validate domain (optional)
        let allowedDomains = [
            "api.anthropic.com",
            "api.openai.com"
        ]
        
        return allowedDomains.contains(url.host ?? "")
    }
    
    // MARK: - Input Sanitization
    
    static func sanitizeInput(_ input: String) -> String {
        // Remove potentially dangerous characters
        let dangerousCharacters = CharacterSet(charactersIn: "<>\"'&")
        return input.components(separatedBy: dangerousCharacters).joined()
    }
    
    static func validateInput(_ input: String, maxLength: Int = 1000) -> Bool {
        // Check length
        guard input.count <= maxLength else {
            return false
        }
        
        // Check for null bytes
        guard !input.contains("\0") else {
            return false
        }
        
        return true
    }
}

// MARK: - Supporting Types

enum APIKeyValidationResult {
    case success(APIKeyType)
    case failure(APIKeyValidationError)
    
    // MARK: - Computed Properties for Easy Checking
    
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
    
    var isFailure: Bool {
        return !isSuccess
    }
    
    var successValue: APIKeyType? {
        switch self {
        case .success(let type):
            return type
        case .failure:
            return nil
        }
    }
    
    var failureValue: APIKeyValidationError? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
}

enum APIKeyType {
    case claude
    case generic
}

enum APIKeyValidationError: LocalizedError {
    case emptyKey
    case invalidLength
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .emptyKey:
            return "API key cannot be empty"
        case .invalidLength:
            return "API key length is invalid"
        case .invalidFormat:
            return "API key format is invalid"
        }
    }
}

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

enum SecurityError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case invalidKey
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .invalidKey:
            return "Invalid encryption key"
        case .invalidData:
            return "Invalid data provided"
        }
    }
} 