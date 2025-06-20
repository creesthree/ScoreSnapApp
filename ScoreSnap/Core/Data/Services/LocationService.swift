//
//  LocationService.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import Foundation
import CoreLocation
import Combine

@MainActor
class LocationService: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var lastKnownLocation: CLLocation?
    @Published var isLocationEnabled = false
    @Published var locationError: LocationError?
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var locationCache: [String: CachedLocation] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // Cache configuration
    private let cacheExpirationInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private let maxCacheSize = 100
    
    override init() {
        super.init()
        setupLocationManager()
        checkLocationServices()
    }
    
    // MARK: - Setup
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update location when user moves 10 meters
    }
    
    func checkLocationServices() {
        isLocationEnabled = CLLocationManager.locationServicesEnabled()
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Permission Management
    
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // User has denied permission, we can't request it again
            locationError = .permissionDenied
        case .authorizedWhenInUse, .authorizedAlways:
            // Already authorized, start location updates
            startLocationUpdates()
        @unknown default:
            locationError = .unknown
        }
    }
    
    func requestAlwaysLocationPermission() {
        locationManager.requestAlwaysAuthorization()
    }
    
    // MARK: - Location Updates
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            locationError = .permissionDenied
            return
        }
        
        guard isLocationEnabled else {
            locationError = .locationServicesDisabled
            return
        }
        
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    func requestSingleLocation() async throws -> CLLocation {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            throw LocationError.permissionDenied
        }
        
        guard isLocationEnabled else {
            throw LocationError.locationServicesDisabled
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // Set up a one-time location request
            let singleLocationHandler: (CLLocation) -> Void = { [weak self] location in
                self?.locationManager.stopUpdatingLocation()
                continuation.resume(returning: location)
            }
            
            // Start location updates and capture the first valid location
            locationManager.startUpdatingLocation()
            
            // Set up a timer to handle timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                self.locationManager.stopUpdatingLocation()
                continuation.resume(throwing: LocationError.timeout)
            }
        }
    }
    
    // MARK: - Reverse Geocoding
    
    func reverseGeocode(location: CLLocation) async throws -> CLPlacemark {
        // Check cache first
        let cacheKey = createCacheKey(for: location)
        if let cachedLocation = locationCache[cacheKey], !cachedLocation.isExpired {
            return cachedLocation.placemark
        }
        
        // Perform reverse geocoding
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        
        guard let placemark = placemarks.first else {
            throw LocationError.geocodingFailed
        }
        
        // Cache the result
        let cachedLocation = CachedLocation(
            placemark: placemark,
            timestamp: Date(),
            expirationInterval: cacheExpirationInterval
        )
        locationCache[cacheKey] = cachedLocation
        
        // Clean up cache if it gets too large
        cleanupCache()
        
        return placemark
    }
    
    func reverseGeocodeCurrentLocation() async throws -> CLPlacemark {
        guard let location = currentLocation else {
            throw LocationError.noLocationAvailable
        }
        
        return try await reverseGeocode(location: location)
    }
    
    func getLocationName(for location: CLLocation) async throws -> String {
        let placemark = try await reverseGeocode(location: location)
        return formatPlacemark(placemark)
    }
    
    func getCurrentLocationName() async throws -> String {
        let placemark = try await reverseGeocodeCurrentLocation()
        return formatPlacemark(placemark)
    }
    
    // MARK: - Location Formatting
    
    private func formatPlacemark(_ placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        // City
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        // State/Province
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        
        // Country
        if let country = placemark.country {
            components.append(country)
        }
        
        // If we have no components, try to use the name
        if components.isEmpty {
            if let name = placemark.name {
                components.append(name)
            } else {
                components.append("Unknown Location")
            }
        }
        
        return components.joined(separator: ", ")
    }
    
    // MARK: - Cache Management
    
    private func createCacheKey(for location: CLLocation) -> String {
        // Round coordinates to reduce cache entries for nearby locations
        let lat = round(location.coordinate.latitude * 1000) / 1000
        let lon = round(location.coordinate.longitude * 1000) / 1000
        return "\(lat),\(lon)"
    }
    
    private func cleanupCache() {
        guard locationCache.count > maxCacheSize else { return }
        
        // Remove expired entries first
        let now = Date()
        locationCache = locationCache.filter { !$0.value.isExpired }
        
        // If still too large, remove oldest entries
        if locationCache.count > maxCacheSize {
            let sortedEntries = locationCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let entriesToRemove = sortedEntries.prefix(locationCache.count - maxCacheSize)
            
            for entry in entriesToRemove {
                locationCache.removeValue(forKey: entry.key)
            }
        }
    }
    
    func clearCache() {
        locationCache.removeAll()
    }
    
    // MARK: - Location Validation
    
    func isValidLocation(_ location: CLLocation) -> Bool {
        // Check if location is recent (within last 5 minutes)
        let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)
        guard location.timestamp > fiveMinutesAgo else {
            return false
        }
        
        // Check if accuracy is reasonable (within 100 meters)
        guard location.horizontalAccuracy <= 100 else {
            return false
        }
        
        // Check if coordinates are valid
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        guard lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 else {
            return false
        }
        
        return true
    }
    
    // MARK: - Distance Calculations
    
    func distance(from location1: CLLocation, to location2: CLLocation) -> CLLocationDistance {
        return location1.distance(from: location2)
    }
    
    func isNearby(_ location1: CLLocation, to location2: CLLocation, within meters: CLLocationDistance) -> Bool {
        return distance(from: location1, to: location2) <= meters
    }
    
    // MARK: - Location History
    
    func saveLocationToHistory(_ location: CLLocation, withName name: String? = nil) {
        let locationHistory = LocationHistory(
            location: location,
            name: name,
            timestamp: Date()
        )
        
        // Save to UserDefaults (in a real app, you might use Core Data)
        saveLocationHistory(locationHistory)
    }
    
    private func saveLocationHistory(_ history: LocationHistory) {
        var histories = loadLocationHistories()
        histories.append(history)
        
        // Keep only last 50 locations
        if histories.count > 50 {
            histories = Array(histories.suffix(50))
        }
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(histories) {
            UserDefaults.standard.set(data, forKey: "LocationHistory")
        }
    }
    
    private func loadLocationHistories() -> [LocationHistory] {
        guard let data = UserDefaults.standard.data(forKey: "LocationHistory") else {
            return []
        }
        
        return (try? JSONDecoder().decode([LocationHistory].self, from: data)) ?? []
    }
    
    func getRecentLocations(limit: Int = 10) -> [LocationHistory] {
        let histories = loadLocationHistories()
        return Array(histories.suffix(limit))
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    @MainActor
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Validate location
        guard isValidLocation(location) else { return }
        
        currentLocation = location
        lastKnownLocation = location
        locationError = nil
    }
    
    @MainActor
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationError = .permissionDenied
            case .locationUnknown:
                locationError = .locationUnavailable
            case .network:
                locationError = .networkError
            default:
                locationError = .unknown
            }
        } else {
            locationError = .unknown
        }
    }
    
    @MainActor
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            locationError = .permissionDenied
        case .notDetermined:
            break
        @unknown default:
            locationError = .unknown
        }
    }
    
    @MainActor
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}

// MARK: - Supporting Types

enum LocationError: LocalizedError {
    case permissionDenied
    case locationServicesDisabled
    case locationUnavailable
    case noLocationAvailable
    case geocodingFailed
    case networkError
    case timeout
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission is required to access your location"
        case .locationServicesDisabled:
            return "Location services are disabled on this device"
        case .locationUnavailable:
            return "Unable to determine your current location"
        case .noLocationAvailable:
            return "No location data is available"
        case .geocodingFailed:
            return "Failed to convert location to address"
        case .networkError:
            return "Network error occurred while getting location"
        case .timeout:
            return "Location request timed out"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

struct CachedLocation {
    let placemark: CLPlacemark
    let timestamp: Date
    let expirationInterval: TimeInterval
    
    var isExpired: Bool {
        return Date().timeIntervalSince(timestamp) > expirationInterval
    }
}

struct LocationHistory: Codable {
    let latitude: Double
    let longitude: Double
    let name: String?
    let timestamp: Date
    
    init(location: CLLocation, name: String?, timestamp: Date) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.name = name
        self.timestamp = timestamp
    }
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var location: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
} 