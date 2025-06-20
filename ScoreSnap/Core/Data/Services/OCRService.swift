//
//  OCRService.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import Foundation
import UIKit
import SwiftUI

@MainActor
class OCRService: ObservableObject {
    // MARK: - Properties
    private let apiLimiter: APILimiter
    private let keychainService: KeychainService
    
    @Published var isProcessing: Bool = false
    @Published var lastAnalysisResult: ScoreboardAnalysis?
    @Published var lastError: OCRError?
    
    // Provider-specific configuration (currently Claude AI)
    let baseURL = "https://api.anthropic.com/v1/messages"
    private let modelName = "claude-3-5-sonnet-20241022"
    private let maxTokens = 1024
    
    // MARK: - Initialization
    init(apiLimiter: APILimiter, keychainService: KeychainService) {
        self.apiLimiter = apiLimiter
        self.keychainService = keychainService
        
        // Log initialization
        SecurityUtils.secureLog("OCRService initialized", level: .info)
    }
    
    // MARK: - API Key Management
    func setAPIKey(_ key: String) throws {
        let sanitizedKey = SecurityUtils.sanitizeAPIKey(key)
        
        // Validate API key format (Claude AI specific for now)
        let validationResult = SecurityUtils.validateAPIKey(sanitizedKey)
        switch validationResult {
        case .success(_):
            break
        case .failure(let error):
            throw OCRError.invalidAPIKeyFormat(error)
        }
        
        // Store in keychain
        do {
            try keychainService.storeAPIKey(sanitizedKey)
        } catch {
            throw error
        }
    }
    
    func clearAPIKey() {
        do {
            try keychainService.deleteAPIKey()
        } catch {
            // Log error but don't throw - clearing should be non-throwing
            print("Warning: Failed to delete API key from keychain: \(error)")
        }
    }
    
    func getKeychainStatus() -> KeychainStatus {
        return keychainService.getKeychainStatus()
    }
    
    func hasValidAPIKey() -> Bool {
        do {
            let key = try keychainService.retrieveAPIKey()
            let validationResult = SecurityUtils.validateAPIKey(key)
            return validationResult.isSuccess
        } catch {
            return false
        }
    }
    
    // MARK: - OCR Analysis
    func analyzeScoreboard(_ image: UIImage) async throws -> ScoreboardAnalysis {
        // Check rate limiting
        guard apiLimiter.canMakeAPICall() else {
            throw OCRError.rateLimitExceeded
        }
        
        // Get API key
        let apiKey: String
        do {
            apiKey = try keychainService.retrieveAPIKey()
        } catch {
            throw OCRError.noAPIKey
        }
        
        // Convert image to base64
        let base64Image: String
        do {
            base64Image = try await convertImageToBase64(image)
        } catch {
            throw OCRError.imageProcessingFailed("Failed to encode image to base64")
        }
        
        // Record API call
        let _ = apiLimiter.recordAPICall()
        
        // Set processing state
        await MainActor.run {
            isProcessing = true
            lastError = nil
        }
        
        do {
            let analysis = try await performOCRAnalysis(apiKey: apiKey, base64Image: base64Image)
            
            await MainActor.run {
                lastAnalysisResult = analysis
                isProcessing = false
            }
            
            return analysis
        } catch {
            await MainActor.run {
                lastError = OCRError.analysisFailed(error)
                isProcessing = false
            }
            throw error
        }
    }
    
    // MARK: - Image Processing
    private func convertImageToBase64(_ image: UIImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Convert to JPEG with compression
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    continuation.resume(throwing: OCRError.imageProcessingFailed("Failed to convert image to supported format"))
                    return
                }
                
                let base64String = imageData.base64EncodedString()
                continuation.resume(returning: base64String)
            }
        }
    }
    
    // MARK: - Network Communication
    private func performOCRAnalysis(apiKey: String, base64Image: String) async throws -> ScoreboardAnalysis {
        // Create request
        let request = try createOCRRequest(apiKey: apiKey, base64Image: base64Image)
        
        // Perform network request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Handle response
        try handleHTTPResponse(response)
        
        // Parse response
        return try parseOCRResponse(data)
    }
    
    private func createOCRRequest(apiKey: String, base64Image: String) throws -> URLRequest {
        guard let url = URL(string: baseURL) else {
            throw OCRError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        // Create request body (Claude AI specific format)
        let requestBody = ClaudeRequest(
            model: modelName,
            maxTokens: maxTokens,
            messages: [
                ClaudeMessage(
                    role: "user",
                    content: [
                        ClaudeContent(
                            type: "image",
                            source: ClaudeImageSource(
                                type: "base64",
                                mediaType: "image/jpeg",
                                data: base64Image
                            )
                        ),
                        ClaudeContent(
                            type: "text",
                            text: createBasketballPrompt()
                        )
                    ]
                )
            ]
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw OCRError.invalidURL
        }
        
        return request
    }
    
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
          "notes": "string (any additional observations)"
        }
        
        Important guidelines:
        - Focus on scores, quarter/period, and game time
        - If you can't clearly see a value, omit it from the JSON
        - Use null for unclear values
        - Provide confidence score based on image clarity
        - Only extract information that is clearly visible
        """
    }
    
    private func handleHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OCRError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 429:
            throw OCRError.rateLimitExceeded
        case 401:
            throw OCRError.invalidAPIKey
        case 400:
            throw OCRError.invalidRequest
        case 500...599:
            throw OCRError.serverError
        default:
            throw OCRError.unexpectedStatusCode(httpResponse.statusCode)
        }
    }
    
    private func parseOCRResponse(_ data: Data) throws -> ScoreboardAnalysis {
        do {
            let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            
            guard let content = claudeResponse.content.first,
                  content.type == "text",
                  let text = content.text else {
                throw lastError ?? OCRError.analysisFailed(NSError())
            }
            
            // Extract JSON from the response text
            let jsonString = extractJSONFromText(text)
            
            guard let jsonData = jsonString.data(using: .utf8) else {
                throw OCRError.invalidResponseFormat
            }
            
            // Parse the basketball analysis
            let analysis = try JSONDecoder().decode(ScoreboardAnalysis.self, from: jsonData)
            
            return analysis
            
        } catch let decodingError as DecodingError {
            throw OCRError.invalidResponseFormat
        } catch {
            throw OCRError.parsingFailed(error)
        }
    }
    
    private func extractJSONFromText(_ text: String) -> String {
        // Look for JSON block in the response
        if let jsonStart = text.range(of: "{"),
           let jsonEnd = text.range(of: "}", options: .backwards) {
            return String(text[jsonStart.lowerBound...jsonEnd.upperBound])
        }
        
        // If no clear JSON block, return the entire text
        return text
    }
    
    // MARK: - Result Management
    func getLastAnalysisResult() -> ScoreboardAnalysis? {
        return lastAnalysisResult
    }
    
    func clearLastResult() {
        lastAnalysisResult = nil
        lastError = nil
    }
}

// MARK: - Data Models

// Provider-specific request models (Claude AI format)
struct ClaudeRequest: Codable {
    let model: String
    let maxTokens: Int
    let messages: [ClaudeMessage]
    
    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
}

struct ClaudeMessage: Codable {
    let role: String
    let content: [ClaudeContent]
}

struct ClaudeContent: Codable {
    let type: String
    let text: String?
    let source: ClaudeImageSource?
    
    init(type: String, text: String? = nil, source: ClaudeImageSource? = nil) {
        self.type = type
        self.text = text
        self.source = source
    }
}

struct ClaudeImageSource: Codable {
    let type: String
    let mediaType: String
    let data: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }
}

struct ClaudeResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ClaudeResponseContent]
    let model: String
    let stopReason: String?
    let stopSequence: String?
    let usage: ClaudeUsage
    
    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case usage
    }
}

struct ClaudeResponseContent: Codable {
    let type: String
    let text: String?
}

struct ClaudeUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// Generic OCR result models
struct ScoreboardAnalysis: Codable {
    let detectedScore: DetectedScore?
    let confidence: Double
    let period: String?
    let timeRemaining: String?
    let additionalInfo: String?
    
    // Legacy support for old format
    let homeTeam: TeamScore?
    let awayTeam: TeamScore?
    let gameInfo: GameInfo?
    let notes: String?
    
    init(detectedScore: DetectedScore?, confidence: Double, period: String? = nil, timeRemaining: String? = nil, additionalInfo: String? = nil) {
        self.detectedScore = detectedScore
        self.confidence = confidence
        self.period = period
        self.timeRemaining = timeRemaining
        self.additionalInfo = additionalInfo
        
        // Legacy fields
        self.homeTeam = nil
        self.awayTeam = nil
        self.gameInfo = nil
        self.notes = additionalInfo
    }
    
    // Legacy initializer
    init(homeTeam: TeamScore?, awayTeam: TeamScore?, gameInfo: GameInfo?, confidence: Double?, notes: String?) {
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.gameInfo = gameInfo
        self.notes = notes
        
        // Convert to new format
        if let home = homeTeam?.score, let away = awayTeam?.score {
            self.detectedScore = DetectedScore(homeScore: home, awayScore: away)
        } else {
            self.detectedScore = nil
        }
        
        self.confidence = confidence ?? 0.0
        
        if let quarter = gameInfo?.quarter {
            self.period = "Quarter \(quarter)"
        } else {
            self.period = nil
        }
        
        self.timeRemaining = gameInfo?.timeRemaining
        self.additionalInfo = notes
    }
}

struct DetectedScore: Codable {
    let homeScore: Int
    let awayScore: Int
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

// MARK: - Error Handling
enum OCRError: LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case invalidAPIKeyFormat(Error)
    case rateLimitExceeded
    case invalidURL
    case invalidRequest
    case invalidResponse
    case invalidResponseFormat
    case unexpectedStatusCode(Int)
    case serverError
    case imageProcessingFailed(String)
    case analysisFailed(Error)
    case parsingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please set up your OCR service API key."
        case .invalidAPIKey:
            return "Invalid API key. Please check your API key and try again."
        case .invalidAPIKeyFormat(let error):
            return "Invalid API key format: \(error.localizedDescription)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please wait before making another request."
        case .invalidURL:
            return "Invalid URL configuration."
        case .invalidRequest:
            return "Invalid request format."
        case .invalidResponse:
            return "Invalid response from OCR service."
        case .invalidResponseFormat:
            return "Unable to parse OCR service response."
        case .unexpectedStatusCode(let code):
            return "Unexpected response code: \(code)"
        case .serverError:
            return "OCR service server error. Please try again later."
        case .imageProcessingFailed(let message):
            return "Image processing failed: \(message)"
        case .analysisFailed(let error):
            return "Analysis failed: \(error.localizedDescription)"
        case .parsingFailed(let error):
            return "Failed to parse results: \(error.localizedDescription)"
        }
    }
} 