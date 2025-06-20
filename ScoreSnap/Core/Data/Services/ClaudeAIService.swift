//
//  ClaudeAIService.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import Foundation
import UIKit
import Combine

@MainActor
class ClaudeAIService: ObservableObject {
    // MARK: - Configuration
    
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-3-5-haiku-20241022"
    private let maxTokens = 1000
    
    // MARK: - State
    
    @Published var isProcessing = false
    @Published var lastAnalysisResult: ScoreboardAnalysis?
    @Published var lastError: ClaudeAIError?
    
    // MARK: - Dependencies
    
    private let apiLimiter: APILimiter
    private let keychainService: KeychainService
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(apiLimiter: APILimiter, keychainService: KeychainService) {
        self.apiLimiter = apiLimiter
        self.keychainService = keychainService
        self.session = URLSession(configuration: .default)
        
        SecurityUtils.secureLog("ClaudeAIService initialized", level: .info)
    }
    
    // MARK: - API Key Management
    
    func setAPIKey(_ key: String) throws {
        SecurityUtils.secureLog("Setting API key", level: .info)
        
        // Validate and sanitize the API key
        let sanitizedKey = SecurityUtils.sanitizeAPIKey(key)
        let validationResult = SecurityUtils.validateAPIKey(sanitizedKey)
        
        switch validationResult {
        case .success(_):
            try keychainService.storeAPIKey(sanitizedKey)
            SecurityUtils.secureLog("API key stored securely in keychain", level: .info)
        case .failure(let error):
            SecurityUtils.secureLogError(error, context: "API key validation failed")
            throw ClaudeAIError.invalidAPIKeyFormat(error)
        }
    }
    
    func hasValidAPIKey() -> Bool {
        do {
            let apiKey = try keychainService.retrieveAPIKey()
            let validationResult = SecurityUtils.validateAPIKey(apiKey)
            return validationResult.isSuccess
        } catch {
            return false
        }
    }
    
    func clearAPIKey() {
        do {
            try keychainService.deleteAPIKey()
            SecurityUtils.secureLog("API key cleared from keychain", level: .info)
        } catch {
            SecurityUtils.secureLogError(error, context: "Failed to clear API key")
        }
    }
    
    private func getAPIKey() throws -> String {
        let apiKey = try keychainService.retrieveAPIKey()
        SecurityUtils.secureLog("API key retrieved successfully", level: .debug)
        return apiKey
    }
    
    // MARK: - Scoreboard Analysis
    
    func analyzeScoreboard(_ image: UIImage, retryCount: Int = 3) async throws -> ScoreboardAnalysis {
        guard hasValidAPIKey() else {
            SecurityUtils.secureLog("No valid API key available", level: .error)
            throw ClaudeAIError.noAPIKey
        }
        
        guard apiLimiter.canMakeAPICall() else {
            SecurityUtils.secureLog("API rate limit exceeded", level: .warning)
            throw ClaudeAIError.rateLimitExceeded
        }
        
        isProcessing = true
        lastError = nil
        
        defer {
            isProcessing = false
        }
        
        do {
            // Preprocess image
            let imageData = try preprocessImage(image)
            
            // Convert to base64
            let base64String = imageData.base64EncodedString()
            guard let base64Data = base64String.data(using: .utf8) else {
                SecurityUtils.secureLog("Failed to encode image to base64", level: .error)
                throw ClaudeAIError.imageProcessingFailed("Failed to encode image to base64")
            }
            
            // Create request
            let request = try createAnalysisRequest(imageBase64: base64Data, imageData: imageData)
            
            SecurityUtils.secureLog("Starting scoreboard analysis", level: .info)
            
            // Make API call with retry logic
            let analysis = try await performAnalysisWithRetry(request: request, retryCount: retryCount)
            
            // Record successful API call
            let apiCallRecorded = apiLimiter.recordAPICall()
            if !apiCallRecorded {
                SecurityUtils.secureLog("Failed to record API call", level: .warning)
            }
            
            // Store result
            lastAnalysisResult = analysis
            
            SecurityUtils.secureLog("Scoreboard analysis completed successfully", level: .info)
            
            return analysis
            
        } catch {
            SecurityUtils.secureLogError(error, context: "Scoreboard analysis failed")
            lastError = ClaudeAIError.analysisFailed(error)
            throw lastError!
        }
    }
    
    // MARK: - Image Processing
    
    private func preprocessImage(_ image: UIImage) throws -> Data {
        // For optimal OCR results, we preserve original image quality
        // and only convert HEIC to JPEG since Claude doesn't support HEIC
        
        // Try to get original image data first (preserves quality)
        if let originalData = image.jpegData(compressionQuality: 1.0) {
            // Image is already JPEG or can be converted without quality loss
            return originalData
        }
        
        // If JPEG conversion fails, try PNG (lossless)
        if let pngData = image.pngData() {
            return pngData
        }
        
        // Fallback: high-quality JPEG conversion
        guard let jpegData = image.jpegData(compressionQuality: 0.95) else {
            throw ClaudeAIError.imageProcessingFailed("Failed to convert image to supported format")
        }
        
        return jpegData
    }
    
    private func getImageMediaType(from imageData: Data) -> String {
        // Check image format by examining data header
        guard imageData.count >= 4 else { return "image/jpeg" }
        
        let header = imageData.prefix(4)
        let bytes = [UInt8](header)
        
        // PNG signature: 89 50 4E 47
        if bytes.count >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "image/png"
        }
        
        // GIF signature: 47 49 46 38
        if bytes.count >= 4 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38 {
            return "image/gif"
        }
        
        // WebP signature: starts with "RIFF" and contains "WEBP"
        if bytes.count >= 4 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 {
            // Check for WEBP at offset 8-11 if data is long enough
            if imageData.count >= 12 {
                let webpCheck = imageData.subdata(in: 8..<12)
                let webpBytes = [UInt8](webpCheck)
                if webpBytes[0] == 0x57 && webpBytes[1] == 0x45 && webpBytes[2] == 0x42 && webpBytes[3] == 0x50 {
                    return "image/webp"
                }
            }
        }
        
        // Default to JPEG (most common for iOS photos)
        return "image/jpeg"
    }
    
    // MARK: - Request Creation
    
    private func createAnalysisRequest(imageBase64: Data, imageData: Data) throws -> URLRequest {
        guard let url = URL(string: baseURL) else {
            SecurityUtils.secureLog("Invalid API URL: \(baseURL)", level: .error)
            throw ClaudeAIError.invalidURL
        }
        
        // Validate URL for security
        guard SecurityUtils.validateURL(url) else {
            SecurityUtils.secureLog("URL validation failed: \(baseURL)", level: .error)
            throw ClaudeAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Required header for Claude API - specifies API version for consistent behavior
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        // Get API key securely
        let apiKey = try getAPIKey()
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "x-api-key")
        
        let requestBody = ClaudeRequest(
            model: model,
            maxTokens: maxTokens,
            messages: [
                ClaudeMessage(
                    role: "user",
                    content: [
                        ClaudeContent(
                            type: "text",
                            text: createBasketballPrompt()
                        ),
                        ClaudeContent(
                            type: "image",
                            source: ClaudeImageSource(
                                type: "base64",
                                mediaType: getImageMediaType(from: imageData),
                                data: imageBase64
                            )
                        )
                    ]
                )
            ]
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        return request
    }
    
    // MARK: - Basketball-Specific Prompts
    
    private func createBasketballPrompt() -> String {
        return """
        You are an expert basketball scoreboard analyzer. Analyze this image of a basketball scoreboard and extract the following information in JSON format:
        
        {
          "homeTeam": {
            "score": number
          },
          "awayTeam": {
            "score": number
          },
          "gameInfo": {
            "quarter": number (1-4 or OT),
            "timeRemaining": "string (MM:SS format)",
            "possession": "home" or "away" (if visible),
            "shotClock": number (if visible)
          },
          "confidence": number (0-1, how confident you are in the extraction),
          "notes": "string (any relevant observations or uncertainties)"
        }
        
        Important guidelines:
        - Focus only on the scoreboard display, ignore other elements
        - Do not attempt to extract team names, fouls, or timeouts as most scoreboards do not display them
        - If a value is not visible or unclear, use null
        - Be precise with numbers and text
        - Consider different scoreboard layouts and formats
        - Handle both digital and analog displays
        - Account for potential glare, angle, or lighting issues
        - If the image is not a basketball scoreboard, return null for all fields
        """
    }
    
    // MARK: - API Call with Retry Logic
    
    private func performAnalysisWithRetry(request: URLRequest, retryCount: Int) async throws -> ScoreboardAnalysis {
        var lastError: Error?
        
        for attempt in 1...retryCount {
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ClaudeAIError.invalidResponse
                }
                
                switch httpResponse.statusCode {
                case 200:
                    let analysis = try parseAnalysisResponse(data)
                    return analysis
                    
                case 429:
                    throw ClaudeAIError.rateLimitExceeded
                    
                case 401:
                    throw ClaudeAIError.invalidAPIKey
                    
                case 400:
                    throw ClaudeAIError.invalidRequest
                    
                case 500...599:
                    throw ClaudeAIError.serverError
                    
                default:
                    throw ClaudeAIError.unexpectedStatusCode(httpResponse.statusCode)
                }
                
            } catch {
                lastError = error
                
                if attempt < retryCount {
                    // Exponential backoff
                    let delay = pow(2.0, Double(attempt)) * 1.0
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? ClaudeAIError.analysisFailed(NSError())
    }
    
    // MARK: - Response Parsing
    
    private func parseAnalysisResponse(_ data: Data) throws -> ScoreboardAnalysis {
        let decoder = JSONDecoder()
        
        do {
            let claudeResponse = try decoder.decode(ClaudeResponse.self, from: data)
            
            guard let content = claudeResponse.content.first,
                  let text = content.text else {
                throw ClaudeAIError.invalidResponseFormat
            }
            
            // Extract JSON from Claude's response
            let jsonString = extractJSONFromResponse(text)
            
            guard let jsonData = jsonString.data(using: .utf8) else {
                throw ClaudeAIError.invalidResponseFormat
            }
            
            let analysis = try decoder.decode(ScoreboardAnalysis.self, from: jsonData)
            return analysis
            
        } catch {
            SecurityUtils.secureLogError(error, context: "Failed to parse Claude response")
            throw ClaudeAIError.parsingFailed(error)
        }
    }
    
    private func extractJSONFromResponse(_ response: String) -> String {
        // Look for JSON content in the response
        if let startIndex = response.firstIndex(of: "{"),
           let endIndex = response.lastIndex(of: "}") {
            let jsonString = String(response[startIndex...endIndex])
            return jsonString
        }
        
        // If no JSON found, return the entire response
        return response
    }
    
    // MARK: - Utility Methods
    
    func getLastAnalysisResult() -> ScoreboardAnalysis? {
        return lastAnalysisResult
    }
    
    func clearLastResult() {
        lastAnalysisResult = nil
        lastError = nil
    }
    
    func getKeychainStatus() -> KeychainStatus {
        return keychainService.getKeychainStatus()
    }
}

// MARK: - Data Models

struct ClaudeRequest: Codable {
    let model: String
    let maxTokens: Int
    let messages: [ClaudeMessage]
}

struct ClaudeMessage: Codable {
    let role: String
    let content: [ClaudeContent]
}

struct ClaudeContent: Codable {
    let type: String
    let text: String?
    let source: ClaudeImageSource?
    
    init(type: String, text: String) {
        self.type = type
        self.text = text
        self.source = nil
    }
    
    init(type: String, source: ClaudeImageSource) {
        self.type = type
        self.text = nil
        self.source = source
    }
}

struct ClaudeImageSource: Codable {
    let type: String
    let mediaType: String
    let data: Data
}

struct ClaudeResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ClaudeContent]
    let model: String
    let stopReason: String?
    let stopSequence: String?
    let usage: ClaudeUsage
}

struct ClaudeUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
}

struct ScoreboardAnalysis: Codable {
    let homeTeam: TeamScore?
    let awayTeam: TeamScore?
    let gameInfo: GameInfo?
    let confidence: Double?
    let notes: String?
    
    var isValid: Bool {
        return homeTeam != nil || awayTeam != nil || gameInfo != nil
    }
}

struct TeamScore: Codable {
    let name: String?
    let score: Int?
    let fouls: Int?
    let timeouts: Int?
}

struct GameInfo: Codable {
    let quarter: Int?
    let timeRemaining: String?
    let possession: String?
    let shotClock: Int?
}

// MARK: - Error Types

enum ClaudeAIError: LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case rateLimitExceeded
    case invalidURL
    case invalidRequest
    case invalidResponse
    case invalidResponseFormat
    case serverError
    case unexpectedStatusCode(Int)
    case imageProcessingFailed(String)
    case jsonParsingFailed
    case responseParsingFailed(Error)
    case analysisFailed(Error)
    case invalidAPIKeyFormat(Error)
    case parsingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured"
        case .invalidAPIKey:
            return "Invalid API key"
        case .rateLimitExceeded:
            return "API rate limit exceeded"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidRequest:
            return "Invalid request format"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidResponseFormat:
            return "Invalid response format"
        case .serverError:
            return "Server error occurred"
        case .unexpectedStatusCode(let code):
            return "Unexpected status code: \(code)"
        case .imageProcessingFailed(let reason):
            return "Failed to process image: \(reason)"
        case .jsonParsingFailed:
            return "Failed to parse JSON response"
        case .responseParsingFailed(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .analysisFailed(let error):
            return "Analysis failed: \(error.localizedDescription)"
        case .invalidAPIKeyFormat(let error):
            return "Invalid API key format: \(error.localizedDescription)"
        case .parsingFailed(let error):
            return "Parsing failed: \(error.localizedDescription)"
        }
    }
} 