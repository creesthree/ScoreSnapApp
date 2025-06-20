//
//  APILimiter.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import Foundation
import Combine

@MainActor
class APILimiter: ObservableObject {
    @Published var currentUsage: APIUsage = APIUsage()
    @Published var isLimitExceeded = false
    
    // Default limits (3 per minute, 20 per hour, 40 per day)
    @Published var limits: APILimits = APILimits(
        perMinute: 3,
        perHour: 20,
        perDay: 40
    )
    
    private let userDefaults = UserDefaults.standard
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // UserDefaults keys
    private let usageKey = "APILimiter.Usage"
    private let limitsKey = "APILimiter.Limits"
    
    init() {
        loadPersistedData()
        setupTimer()
        checkLimits()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - API Call Tracking
    
    func recordAPICall() -> Bool {
        // Check if we can make the call
        guard canMakeAPICall() else {
            return false
        }
        
        // Record the call
        let now = Date()
        currentUsage.calls.append(APICall(timestamp: now))
        
        // Update usage counts
        updateUsageCounts()
        
        // Check limits after recording
        checkLimits()
        
        // Persist the updated usage
        persistUsage()
        
        return true
    }
    
    func canMakeAPICall() -> Bool {
        // Reset expired periods
        resetExpiredPeriods()
        
        // Check if any limit is exceeded
        return currentUsage.callsInLastMinute < limits.perMinute &&
               currentUsage.callsInLastHour < limits.perHour &&
               currentUsage.callsInLastDay < limits.perDay
    }
    
    // MARK: - Limit Management
    
    func updateLimits(_ newLimits: APILimits) {
        limits = newLimits
        persistLimits()
        checkLimits()
    }
    
    func resetLimits() {
        limits = APILimits(perMinute: 3, perHour: 20, perDay: 40)
        persistLimits()
        checkLimits()
    }
    
    func resetUsage() {
        currentUsage = APIUsage()
        persistUsage()
        checkLimits()
    }
    
    func forceReset() {
        resetExpiredPeriods()
        persistUsage()
        checkLimits()
    }
    
    // MARK: - Usage Analysis (Internal Only)
    
    func getUsageStats() -> APIUsageStats {
        let now = Date()
        let calendar = Calendar.current
        
        // Calculate usage patterns
        let callsInLast24Hours = currentUsage.calls.filter { 
            calendar.isDate($0.timestamp, inSameDayAs: now) || 
            calendar.isDateInYesterday($0.timestamp)
        }
        
        let callsInLast7Days = currentUsage.calls.filter {
            calendar.dateInterval(of: .day, for: now)?.contains($0.timestamp) == true ||
            calendar.dateInterval(of: .day, for: calendar.date(byAdding: .day, value: -1, to: now)!)?.contains($0.timestamp) == true ||
            calendar.dateInterval(of: .day, for: calendar.date(byAdding: .day, value: -2, to: now)!)?.contains($0.timestamp) == true ||
            calendar.dateInterval(of: .day, for: calendar.date(byAdding: .day, value: -3, to: now)!)?.contains($0.timestamp) == true ||
            calendar.dateInterval(of: .day, for: calendar.date(byAdding: .day, value: -4, to: now)!)?.contains($0.timestamp) == true ||
            calendar.dateInterval(of: .day, for: calendar.date(byAdding: .day, value: -5, to: now)!)?.contains($0.timestamp) == true ||
            calendar.dateInterval(of: .day, for: calendar.date(byAdding: .day, value: -6, to: now)!)?.contains($0.timestamp) == true
        }
        
        return APIUsageStats(
            totalCalls: currentUsage.calls.count,
            callsInLast24Hours: callsInLast24Hours.count,
            callsInLast7Days: callsInLast7Days.count,
            averageCallsPerDay: callsInLast7Days.count / 7,
            peakUsageTime: findPeakUsageTime(),
            mostActiveDay: findMostActiveDay()
        )
    }
    
    // MARK: - Private Methods
    
    private func updateUsageCounts() {
        let now = Date()
        let calendar = Calendar.current
        
        // Count calls in last minute
        let oneMinuteAgo = calendar.date(byAdding: .minute, value: -1, to: now) ?? now
        currentUsage.callsInLastMinute = currentUsage.calls.filter { $0.timestamp > oneMinuteAgo }.count
        
        // Count calls in last hour
        let oneHourAgo = calendar.date(byAdding: .hour, value: -1, to: now) ?? now
        currentUsage.callsInLastHour = currentUsage.calls.filter { $0.timestamp > oneHourAgo }.count
        
        // Count calls in last day
        let oneDayAgo = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        currentUsage.callsInLastDay = currentUsage.calls.filter { $0.timestamp > oneDayAgo }.count
    }
    
    private func resetExpiredPeriods() {
        let now = Date()
        let calendar = Calendar.current
        
        // Remove calls older than 24 hours
        let oneDayAgo = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        currentUsage.calls = currentUsage.calls.filter { $0.timestamp > oneDayAgo }
        
        // Update counts
        updateUsageCounts()
    }
    
    private func checkLimits() {
        isLimitExceeded = !canMakeAPICall()
    }
    
    private func setupTimer() {
        // Update every 10 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.resetExpiredPeriods()
                self?.checkLimits()
            }
        }
    }
    
    private func findPeakUsageTime() -> Date? {
        guard !currentUsage.calls.isEmpty else { return nil }
        
        // Group calls by hour and find the hour with most calls
        let calendar = Calendar.current
        var hourlyCounts: [Int: Int] = [:]
        
        for call in currentUsage.calls {
            let hour = calendar.component(.hour, from: call.timestamp)
            hourlyCounts[hour, default: 0] += 1
        }
        
        let peakHour = hourlyCounts.max(by: { $0.value < $1.value })?.key ?? 0
        
        // Create a date with the peak hour
        let now = Date()
        return calendar.date(bySettingHour: peakHour, minute: 0, second: 0, of: now)
    }
    
    private func findMostActiveDay() -> Date? {
        guard !currentUsage.calls.isEmpty else { return nil }
        
        let calendar = Calendar.current
        var dailyCounts: [Date: Int] = [:]
        
        for call in currentUsage.calls {
            let day = calendar.startOfDay(for: call.timestamp)
            dailyCounts[day, default: 0] += 1
        }
        
        return dailyCounts.max(by: { $0.value < $1.value })?.key
    }
    
    // MARK: - Persistence
    
    private func persistUsage() {
        if let data = try? JSONEncoder().encode(currentUsage) {
            userDefaults.set(data, forKey: usageKey)
        }
    }
    
    private func persistLimits() {
        if let data = try? JSONEncoder().encode(limits) {
            userDefaults.set(data, forKey: limitsKey)
        }
    }
    
    private func loadPersistedData() {
        // Load usage
        if let data = userDefaults.data(forKey: usageKey),
           let usage = try? JSONDecoder().decode(APIUsage.self, from: data) {
            currentUsage = usage
        }
        
        // Load limits
        if let data = userDefaults.data(forKey: limitsKey),
           let savedLimits = try? JSONDecoder().decode(APILimits.self, from: data) {
            limits = savedLimits
        }
        
        // Reset expired periods on load
        resetExpiredPeriods()
    }
}

// MARK: - Supporting Types

struct APILimits: Codable {
    var perMinute: Int
    var perHour: Int
    var perDay: Int
    
    init(perMinute: Int, perHour: Int, perDay: Int) {
        self.perMinute = max(1, perMinute)
        self.perHour = max(perMinute, perHour)
        self.perDay = max(perHour, perDay)
    }
}

struct APIUsage: Codable {
    var calls: [APICall] = []
    var callsInLastMinute: Int = 0
    var callsInLastHour: Int = 0
    var callsInLastDay: Int = 0
}

struct APICall: Codable {
    let timestamp: Date
    let id: UUID
    
    init(timestamp: Date) {
        self.timestamp = timestamp
        self.id = UUID()
    }
}

struct APIUsageStats {
    let totalCalls: Int
    let callsInLast24Hours: Int
    let callsInLast7Days: Int
    let averageCallsPerDay: Int
    let peakUsageTime: Date?
    let mostActiveDay: Date?
    
    var usageIntensity: String {
        let dailyAverage = averageCallsPerDay
        switch dailyAverage {
        case 0...5: return "Low"
        case 6...15: return "Medium"
        case 16...30: return "High"
        default: return "Very High"
        }
    }
}

// MARK: - Developer Interface

extension APILimiter {
    func setDeveloperMode(_ enabled: Bool) {
        if enabled {
            // Set very high limits for development
            updateLimits(APILimits(perMinute: 100, perHour: 1000, perDay: 10000))
        } else {
            // Reset to normal limits
            resetLimits()
        }
    }
    
    func getDebugInfo() -> APIDebugInfo {
        return APIDebugInfo(
            currentUsage: currentUsage,
            limits: limits,
            usageStats: getUsageStats(),
            isLimitExceeded: isLimitExceeded
        )
    }
    
    func simulateAPICalls(_ count: Int) {
        for _ in 0..<count {
            _ = recordAPICall()
        }
    }
}

struct APIDebugInfo {
    let currentUsage: APIUsage
    let limits: APILimits
    let usageStats: APIUsageStats
    let isLimitExceeded: Bool
    
    var description: String {
        return """
        API Limiter Debug Info:
        - Current Usage: \(currentUsage.calls.count) total calls
        - Last Minute: \(currentUsage.callsInLastMinute)/\(limits.perMinute)
        - Last Hour: \(currentUsage.callsInLastHour)/\(limits.perHour)
        - Last Day: \(currentUsage.callsInLastDay)/\(limits.perDay)
        - Limit Exceeded: \(isLimitExceeded)
        - Usage Intensity: \(usageStats.usageIntensity)
        """
    }
} 