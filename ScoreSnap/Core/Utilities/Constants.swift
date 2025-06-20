//
//  Constants.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI

// MARK: - Team Color Enum

enum TeamColor: String, CaseIterable {
    case red = "red"
    case blue = "blue"
    case green = "green"
    case orange = "orange"
    case purple = "purple"
    case pink = "pink"
    case teal = "teal"
    case indigo = "indigo"
    case yellow = "yellow"
    case gray = "gray"
    case brown = "brown"
    case black = "black"
    
    var color: Color {
        switch self {
        case .red: return .red
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        case .pink: return .pink
        case .teal: return .teal
        case .indigo: return .indigo
        case .yellow: return .yellow
        case .gray: return .gray
        case .brown: return .brown
        case .black: return .black
        }
    }
    
    var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - App Constants

struct Constants {
    
    // MARK: - Basketball Constants
    struct Basketball {
        static let minScore: Int = 0
        static let maxReasonableScore: Int = 200
        static let defaultSport: String = "Basketball"
        static let gameClockEndTime: String = "00:00"
        static let overtimePeriods: [String] = ["OT", "2OT", "3OT"]
    }
    
    // MARK: - UI Constants
    struct UI {
        // Spacing
        static let smallSpacing: CGFloat = 8
        static let mediumSpacing: CGFloat = 16
        static let largeSpacing: CGFloat = 24
        static let extraLargeSpacing: CGFloat = 32
        
        // Corner Radius
        static let smallCornerRadius: CGFloat = 8
        static let mediumCornerRadius: CGFloat = 12
        static let largeCornerRadius: CGFloat = 16
        
        // Button Sizes
        static let floatingActionButtonSize: CGFloat = 56
        static let standardButtonHeight: CGFloat = 44
        static let compactButtonHeight: CGFloat = 32
        
        // Icon Sizes
        static let smallIconSize: CGFloat = 16
        static let mediumIconSize: CGFloat = 24
        static let largeIconSize: CGFloat = 32
        
        // Padding
        static let screenPadding: CGFloat = 16
        static let cardPadding: CGFloat = 16
        static let sectionPadding: CGFloat = 20
        
        // Animation
        static let standardAnimationDuration: Double = 0.3
        static let quickAnimationDuration: Double = 0.15
        static let slowAnimationDuration: Double = 0.5
    }
    
    // MARK: - Tab Bar
    struct TabBar {
        static let homeTitle = "Home"
        static let gamesTitle = "Games"
        static let playersTitle = "Players"
        
        static let homeIcon = "house"
        static let gamesIcon = "list.bullet"
        static let playersIcon = "person.fill"
        
        static let cameraIcon = "camera.fill"
    }
    
    // MARK: - Game States
    struct GameState {
        static let win = "Win"
        static let loss = "Loss"
        static let tie = "Tie"
    }
    
    // MARK: - API Limits
    struct API {
        static let defaultDailyCallLimit: Int = 50
        static let maxRetryAttempts: Int = 3
        static let requestTimeoutInterval: TimeInterval = 30.0
    }
    
    // MARK: - UserDefaults Keys
    struct UserDefaultsKeys {
        static let hasCompletedSetup = "hasCompletedSetup"
        static let lastViewedPlayerID = "lastViewedPlayerID"
        static let lastViewedTeamID = "lastViewedTeamID"
        static let apiCallCount = "apiCallCount"
        static let lastAPICallReset = "lastAPICallReset"
    }
    
    // MARK: - Error Messages
    struct ErrorMessages {
        static let networkError = "Cannot connect to network for image analysis"
        static let jsonError = "JSON error"
        static let rateLimitError = "Rate limit error"
        static let photoAccessError = "No access to photos"
        static let cameraAccessError = "No access to camera"
        static let invalidImageError = "Invalid image format"
        static let noScoreFoundError = "No score found in image"
    }
    
    // MARK: - Default Values
    struct Defaults {
        static let teamColors: [TeamColor] = TeamColor.allCases
        static let defaultTeamColor: TeamColor = .blue
        static let defaultPlayerColor: TeamColor = .red
    }
} 