//
//  Extensions.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI
import Foundation

// MARK: - Color Extensions
extension Color {
    /// Convert Color to hex string for storage
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb: Int = (Int)(red * 255) << 16 | (Int)(green * 255) << 8 | (Int)(blue * 255) << 0
        return String(format: "#%06x", rgb)
    }
    
    /// Initialize Color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Get contrasting text color (black or white) for readability
    var contrastingTextColor: Color {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        
        // Calculate luminance
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance > 0.5 ? .black : .white
    }
    
    /// Get RGB components as a tuple
    var rgbComponents: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return (red: red, green: green, blue: blue)
    }
}

// MARK: - Date Extensions
extension Date {
    /// Format date for game display (e.g., "Mar 15, 2024")
    var gameDisplayFormat: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    /// Format time for game display (e.g., "7:30 PM")
    var gameTimeFormat: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// Format date and time for game display (e.g., "Mar 15, 2024 at 7:30 PM")
    var gameFullFormat: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// Format for compact display (e.g., "3/15")
    var compactFormat: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: self)
    }
    
    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Check if date is within current week
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    /// Get relative display string (e.g., "Today", "Yesterday", "Mar 15")
    var relativeDisplayString: String {
        if isToday {
            return "Today"
        } else if Calendar.current.isDateInYesterday(self) {
            return "Yesterday"
        } else if isThisWeek {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Day of week
            return formatter.string(from: self)
        } else {
            return gameDisplayFormat
        }
    }
}

// MARK: - String Extensions
extension String {
    /// Trim whitespace and newlines
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Check if string is empty after trimming
    var isBlank: Bool {
        trimmed.isEmpty
    }
    
    /// Capitalize first letter only
    var capitalizedFirst: String {
        guard !isEmpty else { return self }
        return prefix(1).uppercased() + dropFirst().lowercased()
    }
    
    /// Extract city from location string (removes state/country)
    var cityOnly: String {
        let components = self.components(separatedBy: ",")
        return components.first?.trimmed ?? self
    }
    
    /// Validate if string represents a valid basketball score
    var isValidBasketballScore: Bool {
        guard let score = Int(self.trimmed) else { return false }
        return score >= Constants.Basketball.minScore && score <= Constants.Basketball.maxReasonableScore
    }
    
    /// Format team name for display (limit length if needed)
    func formattedTeamName(maxLength: Int = 20) -> String {
        if count <= maxLength {
            return self
        }
        return String(prefix(maxLength - 3)) + "..."
    }
    
    /// Check if string contains basketball score pattern
    var containsBasketballScore: Bool {
        let pattern = "\\b\\d{1,3}\\b" // 1-3 digits
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: utf16.count)
        return regex?.firstMatch(in: self, options: [], range: range) != nil
    }
}

// MARK: - Int Extensions
extension Int {
    /// Format score for display with proper styling
    var scoreDisplay: String {
        return String(self)
    }
    
    /// Check if score is within valid basketball range
    var isValidBasketballScore: Bool {
        return self >= Constants.Basketball.minScore && self <= Constants.Basketball.maxReasonableScore
    }
}

// MARK: - Optional Extensions
extension Optional where Wrapped == String {
    /// Safe unwrap with default empty string
    var orEmpty: String {
        return self ?? ""
    }
    
    /// Check if optional string is nil or blank
    var isNilOrBlank: Bool {
        return self?.isBlank ?? true
    }
} 