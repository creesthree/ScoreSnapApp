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
    // MARK: - Services
    
    @Published var photoService: PhotoService
    @Published var locationService: LocationService
    @Published var apiLimiter: APILimiter
    
    // MARK: - Service States
    
    @Published var isPhotoServiceReady = false
    @Published var isLocationServiceReady = false
    @Published var isAPILimiterReady = false
    
    @Published var serviceErrors: [ServiceError] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        self.photoService = PhotoService()
        self.locationService = LocationService()
        self.apiLimiter = APILimiter()
        
        setupServiceObservers()
        checkServiceReadiness()
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
                apiLimiter.recordAPICall()
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
                apiLimiter.recordAPICall()
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
            print("Location not available: \(error.localizedDescription)")
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
            print("Location not available: \(error.localizedDescription)")
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
    }
    
    private func checkServiceReadiness() {
        isPhotoServiceReady = photoService.isCameraAvailable || photoService.isPhotoLibraryAvailable
        isLocationServiceReady = locationService.isLocationEnabled && 
                                (locationService.authorizationStatus == .authorizedWhenInUse || 
                                 locationService.authorizationStatus == .authorizedAlways)
        isAPILimiterReady = true // Always ready after initialization
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
            photoServiceDebug: photoService.isCameraAvailable ? "Camera Available" : "Camera Not Available",
            locationServiceDebug: locationService.isLocationEnabled ? "Location Enabled" : "Location Disabled",
            apiLimiterDebug: apiLimiter.getDebugInfo(),
            serviceErrors: serviceErrors
        )
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
        default:
            return false
        }
    }
}

struct ServicesDebugInfo {
    let photoServiceReady: Bool
    let locationServiceReady: Bool
    let apiLimiterReady: Bool
    let photoServiceDebug: String
    let locationServiceDebug: String
    let apiLimiterDebug: APIDebugInfo
    let serviceErrors: [ServiceError]
    
    var allServicesReady: Bool {
        return photoServiceReady && locationServiceReady && apiLimiterReady
    }
    
    var description: String {
        return """
        Services Manager Debug Info:
        - Photo Service: \(photoServiceReady ? "Ready" : "Not Ready") (\(photoServiceDebug))
        - Location Service: \(locationServiceReady ? "Ready" : "Not Ready") (\(locationServiceDebug))
        - API Limiter: \(apiLimiterReady ? "Ready" : "Not Ready")
        - All Services Ready: \(allServicesReady)
        - Service Errors: \(serviceErrors.count)
        
        API Limiter Info:
        \(apiLimiterDebug.description)
        """
    }
} 