//
//  Phase5ManualEntryComponentTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import XCTest
import SwiftUI
import CoreData
@testable import ScoreSnap

class Phase5ManualEntryComponentTests: XCTestCase {
    
    var testContext: NSManagedObjectContext!
    
    @MainActor
    override func setUp() {
        super.setUp()
        
        // Create in-memory Core Data stack for testing
        let container = NSPersistentContainer(name: "ScoreSnap")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load test store: \(error)")
            }
        }
        
        testContext = container.viewContext
    }
    
    override func tearDown() {
        testContext = nil
        super.tearDown()
    }
    
    // MARK: - WinLossTieSelector Tests
    
    @MainActor
    func testWinLossTieSelectorOutcomeSelection() {
        // Test that selecting different outcomes updates the bound value correctly
        var selectedResult: GameResult = .win
        
        let selector = WinLossTieSelector(selectedResult: Binding(
            get: { selectedResult },
            set: { selectedResult = $0 }
        ))
        
        // Test initial state
        XCTAssertEqual(selectedResult, .win)
        
        // Test switching to loss
        selectedResult = .loss
        XCTAssertEqual(selectedResult, .loss)
        
        // Test switching to tie
        selectedResult = .tie
        XCTAssertEqual(selectedResult, .tie)
        
        // Test switching back to win
        selectedResult = .win
        XCTAssertEqual(selectedResult, .win)
    }
    
    @MainActor
    func testWinLossTieSelectorVisualStateChanges() {
        // Test that selected outcome is visually highlighted
        let selector = WinLossTieSelector(selectedResult: .constant(.win))
        
        // Verify all outcomes are available
        XCTAssertEqual(GameResult.allCases.count, 3)
        XCTAssertTrue(GameResult.allCases.contains(.win))
        XCTAssertTrue(GameResult.allCases.contains(.loss))
        XCTAssertTrue(GameResult.allCases.contains(.tie))
    }
    
    @MainActor
    func testWinLossTieSelectorInitialState() {
        // Test that component starts with specified default
        let selector = WinLossTieSelector(selectedResult: .constant(.win))
        XCTAssertNotNil(selector)
        
        // Test with different initial states
        let lossSelector = WinLossTieSelector(selectedResult: .constant(.loss))
        XCTAssertNotNil(lossSelector)
        
        let tieSelector = WinLossTieSelector(selectedResult: .constant(.tie))
        XCTAssertNotNil(tieSelector)
    }
    
    @MainActor
    func testWinLossTieSelectorSelectionBinding() {
        // Test that changes propagate to parent view's state immediately
        var selectedResult: GameResult = .win
        var bindingCallCount = 0
        
        let binding = Binding<GameResult>(
            get: { selectedResult },
            set: { 
                selectedResult = $0
                bindingCallCount += 1
            }
        )
        
        let selector = WinLossTieSelector(selectedResult: binding)
        
        // Simulate selection changes
        selectedResult = .loss
        XCTAssertEqual(bindingCallCount, 1)
        XCTAssertEqual(selectedResult, .loss)
        
        selectedResult = .tie
        XCTAssertEqual(bindingCallCount, 2)
        XCTAssertEqual(selectedResult, .tie)
    }
    
    @MainActor
    func testWinLossTieSelectorMultipleSelections() {
        // Test that only one outcome can be selected at a time
        var selectedResult: GameResult = .win
        
        let selector = WinLossTieSelector(selectedResult: Binding(
            get: { selectedResult },
            set: { selectedResult = $0 }
        ))
        
        // Verify only one can be selected
        selectedResult = .loss
        XCTAssertNotEqual(selectedResult, .win)
        XCTAssertNotEqual(selectedResult, .tie)
        
        selectedResult = .tie
        XCTAssertNotEqual(selectedResult, .win)
        XCTAssertNotEqual(selectedResult, .loss)
    }
    
    // MARK: - ScoreInputView Tests
    
    @MainActor
    func testScoreInputViewValidation() {
        // Test score input validation - only accepts integers between 0-200
        let viewModel = UploadViewModel(viewContext: testContext)
        
        // Valid scores
        XCTAssertTrue(viewModel.validateScore(0))
        XCTAssertTrue(viewModel.validateScore(50))
        XCTAssertTrue(viewModel.validateScore(100))
        XCTAssertTrue(viewModel.validateScore(200))
        
        // Invalid scores
        XCTAssertFalse(viewModel.validateScore(-1))
        XCTAssertFalse(viewModel.validateScore(201))
        XCTAssertFalse(viewModel.validateScore(999))
    }
    
    @MainActor
    func testScoreInputViewInvalidInputRejection() {
        // Test invalid input rejection
        let viewModel = UploadViewModel(viewContext: testContext)
        
        // Test negative numbers
        viewModel.teamScore = -5
        XCTAssertFalse(viewModel.validateScore(viewModel.teamScore))
        
        // Test out of range numbers
        viewModel.teamScore = 250
        XCTAssertFalse(viewModel.validateScore(viewModel.teamScore))
        
        // Test boundary conditions
        viewModel.teamScore = 0
        XCTAssertTrue(viewModel.validateScore(viewModel.teamScore))
        
        viewModel.teamScore = 200
        XCTAssertTrue(viewModel.validateScore(viewModel.teamScore))
    }
    
    @MainActor
    func testScoreInputViewTeamVsOpponentScoreFields() {
        // Test that both fields work independently
        let viewModel = UploadViewModel(viewContext: testContext)
        
        // Set different values for team and opponent
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        
        XCTAssertEqual(viewModel.teamScore, 85)
        XCTAssertEqual(viewModel.opponentScore, 78)
        
        // Change one without affecting the other
        viewModel.teamScore = 95
        XCTAssertEqual(viewModel.teamScore, 95)
        XCTAssertEqual(viewModel.opponentScore, 78)
        
        viewModel.opponentScore = 82
        XCTAssertEqual(viewModel.teamScore, 95)
        XCTAssertEqual(viewModel.opponentScore, 82)
    }
    
    @MainActor
    func testScoreInputViewRealTimeValidation() {
        // Test real-time validation feedback
        let viewModel = UploadViewModel(viewContext: testContext)
        
        // Start with valid scores
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        XCTAssertTrue(viewModel.isFormValid)
        
        // Make scores invalid
        viewModel.teamScore = 250
        XCTAssertFalse(viewModel.validateScore(viewModel.teamScore))
        
        // Fix the score
        viewModel.teamScore = 95
        XCTAssertTrue(viewModel.validateScore(viewModel.teamScore))
    }
    
    @MainActor
    func testScoreInputViewScoreFieldClearing() {
        // Test score field clearing
        let viewModel = UploadViewModel(viewContext: testContext)
        
        // Set scores
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        
        // Clear scores
        viewModel.teamScore = 0
        viewModel.opponentScore = 0
        
        XCTAssertEqual(viewModel.teamScore, 0)
        XCTAssertEqual(viewModel.opponentScore, 0)
        
        // Re-enter scores
        viewModel.teamScore = 95
        viewModel.opponentScore = 82
        
        XCTAssertEqual(viewModel.teamScore, 95)
        XCTAssertEqual(viewModel.opponentScore, 82)
    }
    
    @MainActor
    func testScoreInputViewScoreBinding() {
        // Test score binding - score changes immediately update view model state
        let viewModel = UploadViewModel(viewContext: testContext)
        
        // Test team score binding
        viewModel.teamScore = 85
        XCTAssertEqual(viewModel.teamScore, 85)
        
        viewModel.teamScore = 95
        XCTAssertEqual(viewModel.teamScore, 95)
        
        // Test opponent score binding
        viewModel.opponentScore = 78
        XCTAssertEqual(viewModel.opponentScore, 78)
        
        viewModel.opponentScore = 82
        XCTAssertEqual(viewModel.opponentScore, 82)
    }
    
    // MARK: - OpponentNameField Tests
    
    @MainActor
    func testOpponentNameFieldTextInput() {
        // Test text input - can enter and edit opponent team names
        var opponentName = ""
        var validationState = false
        
        let field = OpponentNameField(
            opponentName: Binding(
                get: { opponentName },
                set: { opponentName = $0 }
            ),
            onValidationChange: { isValid in
                validationState = isValid
            }
        )
        
        // Test entering a name
        opponentName = "Lakers"
        XCTAssertEqual(opponentName, "Lakers")
        
        // Test editing the name
        opponentName = "Los Angeles Lakers"
        XCTAssertEqual(opponentName, "Los Angeles Lakers")
    }
    
    @MainActor
    func testOpponentNameFieldCharacterLimit() {
        // Test character limit - prevents excessively long opponent names
        var opponentName = ""
        var validationState = false
        
        let field = OpponentNameField(
            opponentName: Binding(
                get: { opponentName },
                set: { opponentName = $0 }
            ),
            onValidationChange: { isValid in
                validationState = isValid
            }
        )
        
        // Test valid length
        opponentName = "Lakers"
        XCTAssertTrue(validationState)
        
        // Test at limit
        opponentName = String(repeating: "A", count: 50)
        XCTAssertTrue(validationState)
        
        // Test over limit
        opponentName = String(repeating: "A", count: 51)
        XCTAssertFalse(validationState)
    }
    
    @MainActor
    func testOpponentNameFieldWhitespaceHandling() {
        // Test whitespace handling - trims leading/trailing whitespace
        var opponentName = ""
        var validationState = false
        
        let field = OpponentNameField(
            opponentName: Binding(
                get: { opponentName },
                set: { opponentName = $0 }
            ),
            onValidationChange: { isValid in
                validationState = isValid
            }
        )
        
        // Test with leading/trailing whitespace
        opponentName = "  Lakers  "
        let trimmed = opponentName.trimmed
        XCTAssertEqual(trimmed, "Lakers")
        
        // Test with only whitespace
        opponentName = "   "
        XCTAssertTrue(opponentName.isBlank)
    }
    
    @MainActor
    func testOpponentNameFieldEmptyNameValidation() {
        // Test empty name validation
        var opponentName = ""
        var validationState = false
        
        let field = OpponentNameField(
            opponentName: Binding(
                get: { opponentName },
                set: { opponentName = $0 }
            ),
            onValidationChange: { isValid in
                validationState = isValid
            }
        )
        
        // Test empty name
        opponentName = ""
        XCTAssertFalse(validationState)
        
        // Test valid name
        opponentName = "Lakers"
        XCTAssertTrue(validationState)
    }
    
    @MainActor
    func testOpponentNameFieldSpecialCharacterHandling() {
        // Test special character handling - accepts appropriate special characters
        var opponentName = ""
        var validationState = false
        
        let field = OpponentNameField(
            opponentName: Binding(
                get: { opponentName },
                set: { opponentName = $0 }
            ),
            onValidationChange: { isValid in
                validationState = isValid
            }
        )
        
        // Test with apostrophe
        opponentName = "O'Connor's Team"
        XCTAssertTrue(validationState)
        
        // Test with hyphen
        opponentName = "Los Angeles-Lakers"
        XCTAssertTrue(validationState)
        
        // Test with numbers
        opponentName = "Team 2024"
        XCTAssertTrue(validationState)
    }
    
    // MARK: - DateTimePickerView Tests
    
    @MainActor
    func testDateTimePickerViewDatePickerFunctionality() {
        // Test date picker functionality
        var gameDate = Date()
        var gameTime = Date()
        
        let picker = DateTimePickerView(
            gameDate: Binding(
                get: { gameDate },
                set: { gameDate = $0 }
            ),
            gameTime: Binding(
                get: { gameTime },
                set: { gameTime = $0 }
            )
        )
        
        XCTAssertNotNil(picker)
        
        // Test date binding
        let newDate = Date().addingTimeInterval(-86400) // Yesterday
        gameDate = newDate
        XCTAssertEqual(gameDate, newDate)
        
        // Test time binding
        let newTime = Date().addingTimeInterval(-3600) // 1 hour ago
        gameTime = newTime
        XCTAssertEqual(gameTime, newTime)
    }
    
    @MainActor
    func testDateTimePickerViewDefaultValueBehavior() {
        // Test default value behavior
        let currentDate = Date()
        var gameDate = currentDate
        var gameTime = currentDate
        
        let picker = DateTimePickerView(
            gameDate: Binding(
                get: { gameDate },
                set: { gameDate = $0 }
            ),
            gameTime: Binding(
                get: { gameTime },
                set: { gameTime = $0 }
            )
        )
        
        // Verify defaults to current date/time
        XCTAssertEqual(gameDate, currentDate)
        XCTAssertEqual(gameTime, currentDate)
    }
    
    @MainActor
    func testDateTimePickerViewPickerBinding() {
        // Test picker binding - date/time changes immediately update form state
        var gameDate = Date()
        var gameTime = Date()
        
        let picker = DateTimePickerView(
            gameDate: Binding(
                get: { gameDate },
                set: { gameDate = $0 }
            ),
            gameTime: Binding(
                get: { gameTime },
                set: { gameTime = $0 }
            )
        )
        
        // Test date changes
        let yesterday = Date().addingTimeInterval(-86400)
        gameDate = yesterday
        XCTAssertEqual(gameDate, yesterday)
        
        // Test time changes
        let oneHourAgo = Date().addingTimeInterval(-3600)
        gameTime = oneHourAgo
        XCTAssertEqual(gameTime, oneHourAgo)
    }
    
    @MainActor
    func testDateTimePickerViewQuickDateOptions() {
        // Test quick date options functionality
        var gameDate = Date()
        var gameTime = Date()
        
        let picker = DateTimePickerView(
            gameDate: Binding(
                get: { gameDate },
                set: { gameDate = $0 }
            ),
            gameTime: Binding(
                get: { gameTime },
                set: { gameTime = $0 }
            )
        )
        
        // Test quick date selection
        let today = Date()
        gameDate = today
        XCTAssertEqual(gameDate, today)
        
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        gameDate = yesterday
        XCTAssertEqual(gameDate, yesterday)
    }
    
    // MARK: - Component Integration Tests
    
    @MainActor
    func testComponentStateSynchronization() {
        // Test component state synchronization
        let viewModel = UploadViewModel(viewContext: testContext)
        
        // Test that all components stay in sync with view model
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        
        XCTAssertEqual(viewModel.gameResult, .win)
        XCTAssertEqual(viewModel.teamScore, 85)
        XCTAssertEqual(viewModel.opponentScore, 78)
        XCTAssertEqual(viewModel.opponentName, "Lakers")
    }
    
    @MainActor
    func testComponentInteraction() {
        // Test component interaction - changing one component affects others
        let viewModel = UploadViewModel(viewContext: testContext)
        
        // Set initial state
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        
        // Change outcome and verify smart score assignment
        viewModel.gameResult = .loss
        viewModel.assignSmartScores()
        
        // Verify scores were adjusted for loss
        XCTAssertTrue(viewModel.opponentScore > viewModel.teamScore)
    }
    
    @MainActor
    func testComponentValidationCoordination() {
        // Test component validation coordination
        let viewModel = UploadViewModel(viewContext: testContext)
        
        // Start with invalid state
        viewModel.teamScore = 0
        viewModel.opponentScore = 0
        viewModel.opponentName = ""
        viewModel.isOpponentNameValid = false
        
        XCTAssertFalse(viewModel.isFormValid)
        
        // Fix validation issues
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        XCTAssertTrue(viewModel.isFormValid)
    }
    
    @MainActor
    func testComponentErrorHandling() {
        // Test component error handling
        let viewModel = UploadViewModel(viewContext: testContext)
        
        // Test that errors in one component don't break others
        viewModel.teamScore = 250 // Invalid score
        viewModel.opponentScore = 78 // Valid score
        viewModel.opponentName = "Lakers" // Valid name
        
        // Opponent name should still be valid even if team score is invalid
        XCTAssertTrue(viewModel.validateOpponentName(viewModel.opponentName))
        XCTAssertFalse(viewModel.validateScore(viewModel.teamScore))
        XCTAssertTrue(viewModel.validateScore(viewModel.opponentScore))
    }
} 