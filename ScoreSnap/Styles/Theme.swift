//
//  Theme.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI

struct Theme {
    
    // MARK: - App Colors
    struct Colors {
        // Primary App Colors
        static let primary = Color.blue
        static let secondary = Color.gray
        static let accent = Color.orange
        
        // Background Colors
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let tertiaryBackground = Color(.tertiarySystemBackground)
        
        // Text Colors
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
        static let tertiaryText = Color(.tertiaryLabel)
        
        // System Colors
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
        
        // Game State Colors
        static let win = Color.green
        static let loss = Color.red
        static let tie = Color.orange
        
        // Card and Surface Colors
        static let cardBackground = Color(.systemBackground)
        static let surfaceBackground = Color(.secondarySystemBackground)
        static let divider = Color(.separator)
        static let border = Color(.separator)
        
        // Interactive Colors
        static let buttonBackground = Color.blue
        static let buttonText = Color.white
        static let destructiveButton = Color.red
        
        // Floating Action Button
        static let fabBackground = Color.blue
        static let fabIcon = Color.white
        static let fabShadow = Color.black.opacity(0.3)
    }
    
    // MARK: - Typography
    struct Typography {
        // Titles
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title1 = Font.title.weight(.semibold)
        static let title2 = Font.title2.weight(.medium)
        static let title3 = Font.title3.weight(.medium)
        
        // Headlines
        static let headline = Font.headline
        static let subheadline = Font.subheadline
        
        // Body Text
        static let body = Font.body
        static let bodyBold = Font.body.weight(.semibold)
        static let callout = Font.callout
        static let caption = Font.caption
        static let caption2 = Font.caption2
        
        // Special
        static let scoreDisplay = Font.title.weight(.bold).monospacedDigit()
        static let recordDisplay = Font.headline.weight(.semibold)
        static let gameInfo = Font.subheadline
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }
    
    // MARK: - Shadows
    struct Shadows {
        static let light = Color.black.opacity(0.1)
        static let medium = Color.black.opacity(0.2)
        static let heavy = Color.black.opacity(0.3)
        
        static let cardShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = 
            (color: light, radius: 4, x: 0, y: 2)
        
        static let fabShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = 
            (color: medium, radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Team Color Support
    struct TeamColors {
        /// Get a color from the team's stored color string
        static func color(from colorString: String?) -> Color {
            guard let colorString = colorString, !colorString.isEmpty else {
                return Constants.Defaults.defaultTeamColor.color
            }
            
            // Try to match predefined TeamColor enum
            if let teamColor = TeamColor(rawValue: colorString.lowercased()) {
                return teamColor.color
            }
            
            // Fallback to default color
            return Constants.Defaults.defaultTeamColor.color
        }
        
        /// Get available team colors for picker
        static let availableColors: [TeamColor] = TeamColor.allCases
        
        /// Get color name for storage
        static func colorName(for teamColor: TeamColor) -> String {
            return teamColor.rawValue
        }
        
        /// Get color from TeamColor enum
        static func color(from teamColor: TeamColor) -> Color {
            return teamColor.color
        }
    }
    
    // MARK: - Animation
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        
        static let spring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8)
        static let bouncy = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.6)
    }
}

// MARK: - View Modifiers
extension View {
    /// Apply card styling
    func cardStyle() -> some View {
        self
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.md)
            .shadow(
                color: Theme.Shadows.cardShadow.color,
                radius: Theme.Shadows.cardShadow.radius,
                x: Theme.Shadows.cardShadow.x,
                y: Theme.Shadows.cardShadow.y
            )
    }
    
    /// Apply floating action button styling
    func fabStyle() -> some View {
        self
            .frame(width: Constants.UI.floatingActionButtonSize, height: Constants.UI.floatingActionButtonSize)
            .background(Theme.Colors.fabBackground)
            .foregroundColor(Theme.Colors.fabIcon)
            .cornerRadius(Constants.UI.floatingActionButtonSize / 2)
            .shadow(
                color: Theme.Shadows.fabShadow.color,
                radius: Theme.Shadows.fabShadow.radius,
                x: Theme.Shadows.fabShadow.x,
                y: Theme.Shadows.fabShadow.y
            )
    }
    
    /// Apply button styling
    func primaryButtonStyle() -> some View {
        self
            .frame(height: Constants.UI.standardButtonHeight)
            .background(Theme.Colors.buttonBackground)
            .foregroundColor(Theme.Colors.buttonText)
            .cornerRadius(Theme.CornerRadius.md)
    }
    
    /// Apply team color styling
    func teamColorStyle(_ color: Color) -> some View {
        self
            .foregroundColor(color.contrastingTextColor)
            .background(color)
    }
} 