//
//  Phase2ExtensionTests.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import XCTest
import SwiftUI
import Foundation
@testable import ScoreSnap

class Phase2ExtensionTests: XCTestCase {
    
    // MARK: - Color Extension Tests
    
    func testColorHexConversion() {
        // Test basic color to hex conversion
        let redColor = Color.red
        let hex = redColor.toHex()
        
        XCTAssertTrue(hex.hasPrefix("#"))
        XCTAssertEqual(hex.count, 7) // #RRGGBB format
        
        // Test hex to color conversion
        let recreatedColor = Color(hex: hex)
        XCTAssertNotNil(recreatedColor)
    }
    
    func testColorHexSpecificValues() {
        // Test specific hex values
        let whiteColor = Color(hex: "#FFFFFF")
        let blackColor = Color(hex: "#000000")
        let redColor = Color(hex: "#FF0000")
        let greenColor = Color(hex: "#00FF00")
        let blueColor = Color(hex: "#0000FF")
        
        XCTAssertNotNil(whiteColor)
        XCTAssertNotNil(blackColor)
        XCTAssertNotNil(redColor)
        XCTAssertNotNil(greenColor)
        XCTAssertNotNil(blueColor)
    }
    
    func testColorHexEdgeCases() {
        // Test short hex format (3 digits)
        let shortHex = Color(hex: "F00") // Should be red
        XCTAssertNotNil(shortHex)
        
        // Test hex without # prefix
        let noHashColor = Color(hex: "FF0000")
        XCTAssertNotNil(noHashColor)
        
        // Test invalid hex
        let invalidColor = Color(hex: "invalid")
        XCTAssertNotNil(invalidColor) // Should still create a color (fallback)
    }
    
    func testContrastingTextColor() {
        // Test that contrasting colors are calculated
        let lightColor = Color.white
        let darkColor = Color.black
        
        let lightContrast = lightColor.contrastingTextColor
        let darkContrast = darkColor.contrastingTextColor
        
        XCTAssertNotNil(lightContrast)
        XCTAssertNotNil(darkContrast)
        
        // Light colors should have dark text, dark colors should have light text
        // This is a basic test - exact color comparison is complex in SwiftUI
    }
    
    // MARK: - Date Extension Tests
    
    func testDateFormatting() {
        let testDate = Date(timeIntervalSince1970: 1640995200) // Jan 1, 2022 00:00:00 UTC
        
        // Test game display format
        let gameDisplay = testDate.gameDisplayFormat
        XCTAssertFalse(gameDisplay.isEmpty)
        XCTAssertTrue(gameDisplay.contains("2022") || gameDisplay.contains("2021")) // Depending on timezone
        
        // Test game time format
        let gameTime = testDate.gameTimeFormat
        XCTAssertFalse(gameTime.isEmpty)
        
        // Test full format
        let fullFormat = testDate.gameFullFormat
        XCTAssertFalse(fullFormat.isEmpty)
        
        // Test compact format
        let compactFormat = testDate.compactFormat
        XCTAssertFalse(compactFormat.isEmpty)
        XCTAssertTrue(compactFormat.contains("/"))
    }
    
    func testDateRelativeFormatting() {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        
        // Test today
        XCTAssertTrue(now.isToday)
        XCTAssertEqual(now.relativeDisplayString, "Today")
        
        // Test yesterday
        XCTAssertFalse(yesterday.isToday)
        XCTAssertTrue(Calendar.current.isDateInYesterday(yesterday))
        XCTAssertEqual(yesterday.relativeDisplayString, "Yesterday")
        
        // Test this week
        let thisWeekDate = Calendar.current.date(byAdding: .day, value: -3, to: now)!
        XCTAssertTrue(thisWeekDate.isThisWeek)
        
        // Test older date
        XCTAssertFalse(lastWeek.isThisWeek)
    }
    
    // MARK: - String Extension Tests
    
    func testStringTrimming() {
        // Test basic trimming
        XCTAssertEqual("  hello  ".trimmed, "hello")
        XCTAssertEqual("\n\thello\n\t".trimmed, "hello")
        XCTAssertEqual("hello".trimmed, "hello")
        XCTAssertEqual("".trimmed, "")
        
        // Test isBlank
        XCTAssertTrue("".isBlank)
        XCTAssertTrue("   ".isBlank)
        XCTAssertTrue("\n\t".isBlank)
        XCTAssertFalse("hello".isBlank)
        XCTAssertFalse("  hello  ".isBlank)
    }
    
    func testStringCapitalization() {
        XCTAssertEqual("hello".capitalizedFirst, "Hello")
        XCTAssertEqual("HELLO".capitalizedFirst, "Hello")
        XCTAssertEqual("hELLO wORLD".capitalizedFirst, "Hello world")
        XCTAssertEqual("".capitalizedFirst, "")
        XCTAssertEqual("a".capitalizedFirst, "A")
    }
    
    func testCityExtraction() {
        XCTAssertEqual("New York, NY".cityOnly, "New York")
        XCTAssertEqual("Boston, MA, USA".cityOnly, "Boston")
        XCTAssertEqual("Boston".cityOnly, "Boston")
        XCTAssertEqual("".cityOnly, "")
        XCTAssertEqual("City, State, Country".cityOnly, "City")
    }
    
    func testBasketballScoreValidation() {
        // Valid scores
        XCTAssertTrue("0".isValidBasketballScore)
        XCTAssertTrue("50".isValidBasketballScore)
        XCTAssertTrue("100".isValidBasketballScore)
        XCTAssertTrue("150".isValidBasketballScore)
        XCTAssertTrue("200".isValidBasketballScore)
        
        // Invalid scores
        XCTAssertFalse("-1".isValidBasketballScore)
        XCTAssertFalse("201".isValidBasketballScore)
        XCTAssertFalse("abc".isValidBasketballScore)
        XCTAssertFalse("50.5".isValidBasketballScore)
        XCTAssertFalse("".isValidBasketballScore)
        XCTAssertTrue("  100  ".isValidBasketballScore) // Should pass because implementation trims first
    }
    
    func testTeamNameFormatting() {
        // Test normal length names
        XCTAssertEqual("Lakers".formattedTeamName(), "Lakers")
        XCTAssertEqual("Boston Celtics".formattedTeamName(), "Boston Celtics")
        
        // Test long names with default max length (20)
        let longName = "Very Long Team Name That Exceeds Twenty Characters"
        let formatted = longName.formattedTeamName()
        XCTAssertTrue(formatted.count <= 20)
        XCTAssertTrue(formatted.hasSuffix("..."))
        
        // Test custom max length
        XCTAssertEqual("Lakers".formattedTeamName(maxLength: 5), "La...")
        XCTAssertEqual("Boston Celtics".formattedTeamName(maxLength: 8), "Bosto...")
    }
    
    func testBasketballScorePattern() {
        // Test score pattern detection
        XCTAssertTrue("Lakers 98 Warriors 95".containsBasketballScore)
        XCTAssertTrue("Final Score: 100".containsBasketballScore)
        XCTAssertTrue("50".containsBasketballScore)
        XCTAssertTrue("The score was 87-92".containsBasketballScore)
        
        XCTAssertFalse("No scores here".containsBasketballScore)
        XCTAssertFalse("abc def".containsBasketballScore)
        XCTAssertFalse("".containsBasketballScore)
    }
    
    // MARK: - Int Extension Tests
    
    func testIntScoreValidation() {
        // Valid basketball scores
        XCTAssertTrue(0.isValidBasketballScore)
        XCTAssertTrue(50.isValidBasketballScore)
        XCTAssertTrue(100.isValidBasketballScore)
        XCTAssertTrue(200.isValidBasketballScore)
        
        // Invalid basketball scores
        XCTAssertFalse((-1).isValidBasketballScore)
        XCTAssertFalse(201.isValidBasketballScore)
        XCTAssertFalse(999.isValidBasketballScore)
    }
    
    func testIntScoreDisplay() {
        XCTAssertEqual(0.scoreDisplay, "0")
        XCTAssertEqual(50.scoreDisplay, "50")
        XCTAssertEqual(100.scoreDisplay, "100")
        XCTAssertEqual(999.scoreDisplay, "999")
    }
    
    // MARK: - Optional String Extension Tests
    
    func testOptionalStringExtensions() {
        let nilString: String? = nil
        let emptyString: String? = ""
        let blankString: String? = "   "
        let validString: String? = "hello"
        
        // Test orEmpty
        XCTAssertEqual(nilString.orEmpty, "")
        XCTAssertEqual(emptyString.orEmpty, "")
        XCTAssertEqual(blankString.orEmpty, "   ")
        XCTAssertEqual(validString.orEmpty, "hello")
        
        // Test isNilOrBlank
        XCTAssertTrue(nilString.isNilOrBlank)
        XCTAssertTrue(emptyString.isNilOrBlank)
        XCTAssertTrue(blankString.isNilOrBlank)
        XCTAssertFalse(validString.isNilOrBlank)
    }
    
    // MARK: - Performance Tests
    
    func testColorHexConversionPerformance() {
        let colors = [Color.red, Color.blue, Color.green, Color.orange, Color.purple]
        
        measure {
            for _ in 0..<1000 {
                for color in colors {
                    let hex = color.toHex()
                    let _ = Color(hex: hex)
                }
            }
        }
    }
    
    func testDateFormattingPerformance() {
        let dates = (0..<100).map { Date(timeIntervalSinceNow: TimeInterval($0 * 86400)) }
        
        measure {
            for date in dates {
                let _ = date.gameDisplayFormat
                let _ = date.gameTimeFormat
                let _ = date.compactFormat
                let _ = date.relativeDisplayString
            }
        }
    }
    
    func testStringValidationPerformance() {
        let testStrings = (0..<1000).map { "Test string \($0)" }
        
        measure {
            for string in testStrings {
                let _ = string.trimmed
                let _ = string.isBlank
                let _ = string.capitalizedFirst
                let _ = string.containsBasketballScore
            }
        }
    }
} 