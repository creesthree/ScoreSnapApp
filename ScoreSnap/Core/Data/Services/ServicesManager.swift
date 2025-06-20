//
//  ServicesManager.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import Foundation
import UIKit
import Combine
import CoreLocation

@MainActor
class ServicesManager: ObservableObject {
    // MARK: - Singleton
    static let shared = ServicesManager()
    
    // MARK: - Properties
    
    let photoService: PhotoService
    let locationService: LocationService
    let apiLimiter: APILimiter
    let keychainService: KeychainService
    lazy var ocrService: OCRService = {
        return OCRService(apiLimiter: self.apiLimiter, keychainService: self.keychainService)
    }()
    
    // Service readiness flags
    @Published var isPhotoServiceReady: Bool = false
    @Published var isLocationServiceReady: Bool = false
    @Published var isAPILimiterReady: Bool = false
    @Published var isKeychainServiceReady: Bool = false
    @Published var isOCRServiceReady: Bool = false
    
    @Published var serviceErrors: [ServiceError] = []
    
    // Computed property for overall service readiness
    var areAllServicesReady: Bool {
        return isPhotoServiceReady && isLocationServiceReady && isAPILimiterReady && isKeychainServiceReady && isOCRServiceReady
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        self.photoService = PhotoService()
        self.locationService = LocationService()
        self.apiLimiter = APILimiter()
        self.keychainService = KeychainService()
        
        setupServiceObservers()
        checkServiceReadiness()
        
        SecurityUtils.secureLog("ServicesManager initialized with secure keychain integration", level: .info)
    }
    
    // MARK: - Service Coordination
    
    func initializeServices() async {
        // Initialize all services in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.initializePhotoService()
            }
            
            group.addTask {
                await self.initializeLocationService()
            }
            
            group.addTask {
                await self.initializeAPILimiter()
            }
            
            group.addTask {
                await self.initializeKeychainService()
            }
            
            group.addTask {
                await self.initializeOCRService()
            }
        }
        
        checkServiceReadiness()
    }
    
    private func initializePhotoService() async {
        photoService.checkPermissions()
        isPhotoServiceReady = photoService.isCameraAvailable || photoService.isPhotoLibraryAvailable
    }
    
    private func initializeLocationService() async {
        locationService.checkLocationServices()
        isLocationServiceReady = locationService.isLocationEnabled && 
                                (locationService.authorizationStatus == .authorizedWhenInUse || 
                                 locationService.authorizationStatus == .authorizedAlways)
    }
    
    private func initializeAPILimiter() async {
        // APILimiter is ready immediately after initialization
        isAPILimiterReady = true
    }
    
    private func initializeKeychainService() async {
        // KeychainService is ready if keychain is available
        isKeychainServiceReady = keychainService.isKeychainAvailable
    }
    
    private func initializeOCRService() async {
        // OCRService is ready if API key is configured and keychain is available
        isOCRServiceReady = keychainService.isKeychainAvailable && ocrService.hasValidAPIKey()
    }
    
    // MARK: - Photo Operations
    
    func capturePhoto(from viewController: UIViewController) async throws -> UIImage {
        guard isPhotoServiceReady else {
            throw ServiceError.photoServiceNotReady
        }
        
        // Check API limits
        guard apiLimiter.canMakeAPICall() else {
            throw ServiceError.apiLimitExceeded
        }
        
        do {
            let image = try await photoService.capturePhoto(from: viewController)
            
            // Validate the photo
            let validationResult = photoService.validatePhoto(image)
            switch validationResult {
            case .success(let validatedImage):
                // Record API call
                let _ = apiLimiter.recordAPICall()
                return validatedImage
            case .failure(let error):
                throw ServiceError.photoValidationFailed(error)
            }
        } catch {
            throw ServiceError.photoCaptureFailed(error)
        }
    }
    
    func selectPhoto(from viewController: UIViewController) async throws -> UIImage {
        guard isPhotoServiceReady else {
            throw ServiceError.photoServiceNotReady
        }
        
        // Check API limits
        guard apiLimiter.canMakeAPICall() else {
            throw ServiceError.apiLimitExceeded
        }
        
        do {
            let image = try await photoService.selectPhotoWithPHPicker(from: viewController)
            
            // Validate the photo
            let validationResult = photoService.validatePhoto(image)
            switch validationResult {
            case .success(let validatedImage):
                // Record API call
                let _ = apiLimiter.recordAPICall()
                return validatedImage
            case .failure(let error):
                throw ServiceError.photoValidationFailed(error)
            }
        } catch {
            throw ServiceError.photoSelectionFailed(error)
        }
    }
    
    func processImageForAnalysis(_ image: UIImage) -> UIImage {
        return photoService.processImageForAnalysis(image)
    }
    
    func extractEXIFMetadata(from image: UIImage) -> EXIFMetadata? {
        return photoService.extractEXIFMetadata(from: image)
    }
    
    // MARK: - Location Operations
    
    func getCurrentLocation() async throws -> CLLocation {
        guard isLocationServiceReady else {
            throw ServiceError.locationServiceNotReady
        }
        
        do {
            return try await locationService.requestSingleLocation()
        } catch {
            throw ServiceError.locationRetrievalFailed(error)
        }
    }
    
    func getCurrentLocationName() async throws -> String {
        guard isLocationServiceReady else {
            throw ServiceError.locationServiceNotReady
        }
        
        do {
            return try await locationService.getCurrentLocationName()
        } catch {
            throw ServiceError.locationGeocodingFailed(error)
        }
    }
    
    func reverseGeocode(location: CLLocation) async throws -> CLPlacemark {
        guard isLocationServiceReady else {
            throw ServiceError.locationServiceNotReady
        }
        
        do {
            return try await locationService.reverseGeocode(location: location)
        } catch {
            throw ServiceError.locationGeocodingFailed(error)
        }
    }
    
    func requestLocationPermission() {
        locationService.requestLocationPermission()
    }
    
    // MARK: - OCR Analysis
    func analyzeScoreboard(_ image: UIImage) async throws -> ScoreboardAnalysis {
        guard isOCRServiceReady else {
            throw ServiceError.ocrServiceNotReady
        }
        
        do {
            SecurityUtils.secureLog("Starting scoreboard analysis", level: .info)
            
            let analysis = try await ocrService.analyzeScoreboard(image)
            
            SecurityUtils.secureLog("Scoreboard analysis completed", level: .info)
            return analysis
        } catch {
            SecurityUtils.secureLogError(error, context: "Scoreboard analysis failed")
            throw error
        }
    }
    
    // MARK: - OCR Service Management
    func setOCRAPIKey(_ key: String) throws {
        try ocrService.setAPIKey(key)
        isOCRServiceReady = ocrService.hasValidAPIKey()
    }
    
    func hasValidOCRAPIKey() -> Bool {
        return ocrService.hasValidAPIKey()
    }
    
    func clearOCRAPIKey() {
        ocrService.clearAPIKey()
        isOCRServiceReady = false
    }
    
    func getLastOCRResult() -> ScoreboardAnalysis? {
        return ocrService.getLastAnalysisResult()
    }
    
    // MARK: - Service Access Methods
    
    func getOCRService() -> OCRService {
        return ocrService
    }
    
    func getLocationService() -> LocationService {
        return locationService
    }
    
    func getPhotoService() -> PhotoService {
        return photoService
    }
    
    func clearLastOCRResult() {
        ocrService.clearLastResult()
    }
    
    // MARK: - Keychain Operations
    
    func getKeychainStatus() -> KeychainStatus {
        return keychainService.getKeychainStatus()
    }
    
    func clearAllKeys() throws {
        try keychainService.clearAllKeys()
        isOCRServiceReady = false
        SecurityUtils.secureLog("All keys cleared from keychain", level: .info)
    }
    
    func authenticateWithBiometrics() async throws -> Bool {
        return try await keychainService.authenticateWithBiometrics()
    }
    
    // MARK: - API Operations (Internal Only)
    
    func canMakeAPICall() -> Bool {
        return apiLimiter.canMakeAPICall()
    }
    
    func recordAPICall() -> Bool {
        return apiLimiter.recordAPICall()
    }
    
    func getUsageStats() -> APIUsageStats {
        return apiLimiter.getUsageStats()
    }
    
    // MARK: - Combined Operations
    
    func capturePhotoWithLocation(from viewController: UIViewController) async throws -> PhotoWithLocation {
        // Capture photo
        let image = try await capturePhoto(from: viewController)
        
        // Get location (if available)
        var location: CLLocation?
        var locationName: String?
        
        do {
            location = try await getCurrentLocation()
            locationName = try await getCurrentLocationName()
        } catch {
            // Location is optional, so we don't throw here
            SecurityUtils.secureLog("Location not available: \(error.localizedDescription)", level: .warning)
        }
        
        // Extract EXIF metadata
        let exifMetadata = extractEXIFMetadata(from: image)
        
        return PhotoWithLocation(
            image: image,
            location: location,
            locationName: locationName,
            exifMetadata: exifMetadata,
            timestamp: Date()
        )
    }
    
    func selectPhotoWithLocation(from viewController: UIViewController) async throws -> PhotoWithLocation {
        // Select photo
        let image = try await selectPhoto(from: viewController)
        
        // Get location (if available)
        var location: CLLocation?
        var locationName: String?
        
        do {
            location = try await getCurrentLocation()
            locationName = try await getCurrentLocationName()
        } catch {
            // Location is optional, so we don't throw here
            SecurityUtils.secureLog("Location not available: \(error.localizedDescription)", level: .warning)
        }
        
        // Extract EXIF metadata
        let exifMetadata = extractEXIFMetadata(from: image)
        
        return PhotoWithLocation(
            image: image,
            location: location,
            locationName: locationName,
            exifMetadata: exifMetadata,
            timestamp: Date()
        )
    }
    
    // MARK: - Service Management
    
    func resetAllServices() {
        photoService.checkPermissions()
        locationService.checkLocationServices()
        apiLimiter.forceReset()
        
        checkServiceReadiness()
    }
    
    func clearAllCaches() {
        locationService.clearCache()
        // PhotoService doesn't have a cache to clear
        // APILimiter cache is managed automatically
    }
    
    func setDeveloperMode(_ enabled: Bool) {
        apiLimiter.setDeveloperMode(enabled)
    }
    
    // MARK: - Service Monitoring
    
    private func setupServiceObservers() {
        // Monitor photo service state
        photoService.$isCameraAvailable
            .combineLatest(photoService.$isPhotoLibraryAvailable)
            .sink { [weak self] cameraAvailable, photoLibraryAvailable in
                self?.isPhotoServiceReady = cameraAvailable || photoLibraryAvailable
            }
            .store(in: &cancellables)
        
        // Monitor location service state
        locationService.$isLocationEnabled
            .combineLatest(locationService.$authorizationStatus)
            .sink { [weak self] locationEnabled, authorizationStatus in
                self?.isLocationServiceReady = locationEnabled && 
                (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways)
            }
            .store(in: &cancellables)
        
        // Monitor keychain service state
        keychainService.$isKeychainAvailable
            .sink { [weak self] keychainAvailable in
                self?.isKeychainServiceReady = keychainAvailable
            }
            .store(in: &cancellables)
        
        // Monitor API limiter state
        apiLimiter.$isLimitExceeded
            .sink { [weak self] limitExceeded in
                if limitExceeded {
                    self?.addServiceError(.apiLimitExceeded)
                }
            }
            .store(in: &cancellables)
        
        // Monitor location errors
        locationService.$locationError
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.addServiceError(.locationError(error))
            }
            .store(in: &cancellables)
        
        // Monitor keychain errors
        keychainService.$lastError
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.addServiceError(.keychainError(error))
            }
            .store(in: &cancellables)
    }
    
    private func checkServiceReadiness() {
        isPhotoServiceReady = photoService.isCameraAvailable || photoService.isPhotoLibraryAvailable
        isLocationServiceReady = locationService.isLocationEnabled && 
                                (locationService.authorizationStatus == .authorizedWhenInUse || 
                                 locationService.authorizationStatus == .authorizedAlways)
        isAPILimiterReady = true // Always ready after initialization
        isKeychainServiceReady = keychainService.isKeychainAvailable
        isOCRServiceReady = keychainService.isKeychainAvailable && ocrService.hasValidAPIKey()
    }
    
    private func addServiceError(_ error: ServiceError) {
        serviceErrors.append(error)
        
        // Remove old errors after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.serviceErrors.removeAll { $0 == error }
        }
    }
    
    // MARK: - Debug Information
    
    func getDebugInfo() -> ServicesDebugInfo {
        return ServicesDebugInfo(
            photoServiceReady: isPhotoServiceReady,
            locationServiceReady: isLocationServiceReady,
            apiLimiterReady: isAPILimiterReady,
            keychainServiceReady: isKeychainServiceReady,
            ocrServiceReady: isOCRServiceReady,
            photoServiceDebug: photoService.isCameraAvailable ? "Camera Available" : "Camera Not Available",
            locationServiceDebug: locationService.isLocationEnabled ? "Location Enabled" : "Location Disabled",
            apiLimiterDebug: apiLimiter.getDebugInfo(),
            keychainServiceDebug: keychainService.isKeychainAvailable ? "Keychain Available" : "Keychain Not Available",
            ocrServiceDebug: ocrService.hasValidAPIKey() ? "API Key Configured" : "No API Key",
            serviceErrors: serviceErrors
        )
    }
    
    func getSystemStatus() -> [String: Any] {
        return [
            "photoServiceReady": isPhotoServiceReady,
            "locationServiceReady": isLocationServiceReady,
            "apiLimiterReady": isAPILimiterReady,
            "keychainServiceReady": isKeychainServiceReady,
            "ocrServiceReady": isOCRServiceReady,
            "allServicesReady": areAllServicesReady,
            "photoServiceDebug": photoService.cameraPermissionStatus == .authorized ? "Camera Authorized" : "Camera Not Authorized",
            "locationServiceDebug": locationService.authorizationStatus == .authorizedWhenInUse || locationService.authorizationStatus == .authorizedAlways ? "Location Authorized" : "Location Not Authorized",
            "apiLimiterDebug": "Calls Today: \(apiLimiter.currentUsage.callsInLastDay)/\(apiLimiter.limits.perDay)",
            "keychainServiceDebug": keychainService.isKeychainAvailable ? "Available" : "Not Available",
            "ocrServiceDebug": ocrService.hasValidAPIKey() ? "API Key Configured" : "No API Key",
            "servicesManagerDebug": "Ready: \(areAllServicesReady)"
        ]
    }
}

// MARK: - Supporting Types

struct PhotoWithLocation {
    let image: UIImage
    let location: CLLocation?
    let locationName: String?
    let exifMetadata: EXIFMetadata?
    let timestamp: Date
    
    var hasLocation: Bool {
        return location != nil
    }
    
    var hasEXIFData: Bool {
        return exifMetadata != nil
    }
    
    var formattedLocation: String {
        return locationName ?? "Unknown Location"
    }
}

enum ServiceError: LocalizedError, Equatable {
    case photoServiceNotReady
    case locationServiceNotReady
    case apiLimitExceeded
    case photoCaptureFailed(Error)
    case photoSelectionFailed(Error)
    case photoValidationFailed(PhotoError)
    case locationRetrievalFailed(Error)
    case locationGeocodingFailed(Error)
    case locationError(LocationError)
    case ocrServiceNotReady
    case aiAnalysisFailed(Error)
    case apiKeyManagementFailed(Error)
    case keychainError(Error)
    
    var errorDescription: String? {
        switch self {
        case .photoServiceNotReady:
            return "Photo service is not ready"
        case .locationServiceNotReady:
            return "Location service is not ready"
        case .apiLimitExceeded:
            return "You've reached the limit for photo uploads. Please try again later."
        case .photoCaptureFailed(let error):
            return "Photo capture failed: \(error.localizedDescription)"
        case .photoSelectionFailed(let error):
            return "Photo selection failed: \(error.localizedDescription)"
        case .photoValidationFailed(let error):
            return "Photo validation failed: \(error.localizedDescription)"
        case .locationRetrievalFailed(let error):
            return "Location retrieval failed: \(error.localizedDescription)"
        case .locationGeocodingFailed(let error):
            return "Location geocoding failed: \(error.localizedDescription)"
        case .locationError(let error):
            return "Location error: \(error.localizedDescription)"
        case .ocrServiceNotReady:
            return "OCR service is not ready"
        case .aiAnalysisFailed(let error):
            return "AI analysis failed: \(error.localizedDescription)"
        case .apiKeyManagementFailed(let error):
            return "API key management failed: \(error.localizedDescription)"
        case .keychainError(let error):
            return "Keychain error: \(error.localizedDescription)"
        }
    }
    
    static func == (lhs: ServiceError, rhs: ServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.photoServiceNotReady, .photoServiceNotReady),
             (.locationServiceNotReady, .locationServiceNotReady),
             (.apiLimitExceeded, .apiLimitExceeded):
            return true
        case (.photoCaptureFailed, .photoCaptureFailed),
             (.photoSelectionFailed, .photoSelectionFailed),
             (.photoValidationFailed, .photoValidationFailed),
             (.locationRetrievalFailed, .locationRetrievalFailed),
             (.locationGeocodingFailed, .locationGeocodingFailed),
             (.locationError, .locationError):
            return true
        case (.ocrServiceNotReady, .ocrServiceNotReady):
            return true
        case (.aiAnalysisFailed, .aiAnalysisFailed):
            return true
        case (.apiKeyManagementFailed, .apiKeyManagementFailed):
            return true
        case (.keychainError, .keychainError):
            return true
        default:
            return false
        }
    }
}

struct ServicesDebugInfo {
    let photoServiceReady: Bool
    let locationServiceReady: Bool
    let apiLimiterReady: Bool
    let keychainServiceReady: Bool
    let ocrServiceReady: Bool
    let photoServiceDebug: String
    let locationServiceDebug: String
    let apiLimiterDebug: APIDebugInfo
    let keychainServiceDebug: String
    let ocrServiceDebug: String
    let serviceErrors: [ServiceError]
    
    var allServicesReady: Bool {
        return photoServiceReady && locationServiceReady && apiLimiterReady && keychainServiceReady && ocrServiceReady
    }
    
    var description: String {
        return """
        Services Manager Debug Info:
        - Photo Service: \(photoServiceReady ? "Ready" : "Not Ready") (\(photoServiceDebug))
        - Location Service: \(locationServiceReady ? "Ready" : "Not Ready") (\(locationServiceDebug))
        - API Limiter: \(apiLimiterReady ? "Ready" : "Not Ready")
        - Keychain Service: \(keychainServiceReady ? "Ready" : "Not Ready") (\(keychainServiceDebug))
        - OCR Service: \(ocrServiceReady ? "Ready" : "Not Ready") (\(ocrServiceDebug))
        - All Services Ready: \(allServicesReady)
        - Service Errors: \(serviceErrors.count)
        
        API Limiter Info:
        \(apiLimiterDebug.description)
        """
    }
} 