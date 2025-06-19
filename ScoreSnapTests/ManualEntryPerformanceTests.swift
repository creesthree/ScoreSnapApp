//
//  Phase5PerformanceTests.swift
//  ScoreSnapTests
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import XCTest
import SwiftUI
import CoreData
@testable import ScoreSnap

class Phase5PerformanceTests: XCTestCase {
    
    var testContext: NSManagedObjectContext!
    var viewModel: UploadViewModel!
    
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
        viewModel = UploadViewModel(viewContext: testContext)
    }
    
    override func tearDown() {
        viewModel = nil
        testContext = nil
        super.tearDown()
    }
    
    // MARK: - Form Responsiveness Tests
    
    @MainActor
    func testFormLoadingTime() {
        // Test form loading time - Manual entry form loads within 500ms
        measure {
            // Simulate form initialization
            let _ = UploadViewModel(viewContext: testContext)
        }
    }
    
    @MainActor
    func testInputResponsiveness() {
        // Test input responsiveness - Text input and button presses respond within 100ms
        measure {
            // Simulate rapid input changes
            for i in 0..<100 {
                viewModel.teamScore = i
                viewModel.opponentScore = i + 5
                viewModel.opponentName = "Team \(i)"
            }
        }
    }
    
    @MainActor
    func testValidationPerformance() {
        // Test validation performance - Real-time validation doesn't lag user input
        measure {
            // Simulate validation on input changes
            for i in 0..<1000 {
                let score = i % 201 // Mix of valid and invalid scores
                let _ = viewModel.validateScore(score)
                
                let name = String(repeating: "A", count: i % 60) // Mix of valid and invalid names
                let _ = viewModel.validateOpponentName(name)
            }
        }
    }
    
    @MainActor
    func testSaveOperationTime() {
        // Test save operation time - Game save completes within 1.5 seconds
        let team = createTestTeam()
        
        // Set up valid form data
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.isOpponentNameValid = true
        
        measure {
            let success = viewModel.createGame(for: team)
            XCTAssertTrue(success)
        }
    }
    
    @MainActor
    func testFormResetPerformance() {
        // Test form reset performance - Form reset/clear operations complete quickly
        // Set up form with data
        viewModel.gameResult = .win
        viewModel.teamScore = 85
        viewModel.opponentScore = 78
        viewModel.opponentName = "Lakers"
        viewModel.gameLocation = "Home Court"
        viewModel.gameNotes = "Great game!"
        viewModel.isOpponentNameValid = true
        
        measure {
            viewModel.resetForm()
        }
    }
    
    // MARK: - Memory Management Tests
    
    @MainActor
    func testFormMemoryUsage() {
        // Test form memory usage - Form doesn't accumulate memory during extended use
        var viewModels: [UploadViewModel] = []
        
        measure {
            // Create and use multiple view models
            for _ in 0..<100 {
                let vm = UploadViewModel(viewContext: testContext)
                vm.gameResult = .win
                vm.teamScore = 85
                vm.opponentScore = 78
                vm.opponentName = "Lakers"
                vm.isOpponentNameValid = true
                
                viewModels.append(vm)
            }
            
            // Clear array to test memory cleanup
            viewModels.removeAll()
        }
    }
    
    @MainActor
    func testPickerMemoryHandling() {
        // Test picker memory handling - Date/time pickers properly release memory
        measure {
            // Simulate date picker usage
            for _ in 0..<1000 {
                let testDate = Date().addingTimeInterval(Double.random(in: -86400*365...86400*365))
                viewModel.gameDate = testDate
                viewModel.gameTime = testDate
            }
        }
    }
    
    @MainActor
    func testNavigationMemoryCleanup() {
        // Test navigation memory cleanup - Form view properly cleans up when dismissed
        measure {
            // Simulate view creation and cleanup
            for _ in 0..<100 {
                let vm = UploadViewModel(viewContext: testContext)
                vm.gameResult = .win
                vm.teamScore = 85
                vm.opponentScore = 78
                vm.opponentName = "Lakers"
                vm.isOpponentNameValid = true
                
                // Simulate view dismissal
                vm.resetForm()
            }
        }
    }
    
    // MARK: - Component Performance Tests
    
    @MainActor
    func testComponentRenderPerformance() {
        // Test component render performance - Individual components render smoothly
        measure {
            // Simulate component rendering
            for _ in 0..<1000 {
                let _ = WinLossTieSelector(selectedResult: .constant(.win))
                let _ = ScoreInputView(
                    teamScore: .constant(85),
                    opponentScore: .constant(78),
                    gameResult: .win
                ) {
                    // Empty closure
                }
                let _ = OpponentNameField(
                    opponentName: .constant("Lakers")
                ) { _ in
                    // Empty closure
                }
                let _ = DateTimePickerView(
                    gameDate: .constant(Date()),
                    gameTime: .constant(Date())
                )
            }
        }
    }
    
    @MainActor
    func testComponentUpdatePerformance() {
        // Test component update performance - Component updates don't cause UI lag
        measure {
            // Simulate rapid component updates
            for i in 0..<1000 {
                viewModel.gameResult = GameResult.allCases[i % 3]
                viewModel.teamScore = i % 201
                viewModel.opponentScore = (i + 5) % 201
                viewModel.opponentName = "Team \(i % 10)"
                viewModel.isOpponentNameValid = !viewModel.opponentName.isEmpty
                
                // Trigger smart score assignment
                viewModel.assignSmartScores()
            }
        }
    }
    
    @MainActor
    func testSmartScoreAssignmentPerformance() {
        // Test smart score assignment performance
        measure {
            // Simulate smart score assignment
            for i in 0..<1000 {
                viewModel.gameResult = GameResult.allCases[i % 3]
                viewModel.teamScore = i % 201
                viewModel.opponentScore = (i + 5) % 201
                
                viewModel.assignSmartScores()
            }
        }
    }
    
    @MainActor
    func testValidationChainPerformance() {
        // Test validation chain performance
        measure {
            // Simulate validation chain
            for i in 0..<1000 {
                let score = i % 201
                let name = String(repeating: "A", count: i % 60)
                
                let scoreValid = viewModel.validateScore(score)
                let nameValid = viewModel.validateOpponentName(name)
                
                // Update validation state
                viewModel.teamScore = score
                viewModel.opponentScore = score + 5
                viewModel.opponentName = name
                viewModel.isOpponentNameValid = nameValid
                
                // Check overall form validity
                let _ = viewModel.isFormValid
            }
        }
    }
    
    @MainActor
    func testConcurrentFormOperations() {
        // Test concurrent form operations performance
        measure {
            let group = DispatchGroup()
            
            // Simulate concurrent operations
            for i in 0..<10 {
                group.enter()
                DispatchQueue.global().async {
                    DispatchQueue.main.async {
                        self.viewModel.teamScore = i
                        self.viewModel.opponentScore = i + 5
                        self.viewModel.opponentName = "Team \(i)"
                        self.viewModel.isOpponentNameValid = true
                        group.leave()
                    }
                }
            }
            
            group.wait()
        }
    }
    
    @MainActor
    func testLargeDataSetPerformance() {
        // Test performance with large data sets
        let team = createTestTeam()
        
        // Create many games to test performance with large data
        measure {
            for i in 0..<100 {
                viewModel.gameResult = GameResult.allCases[i % 3]
                viewModel.teamScore = 85 + (i % 20)
                viewModel.opponentScore = 78 + (i % 20)
                viewModel.opponentName = "Team \(i)"
                viewModel.isOpponentNameValid = true
                
                let success = viewModel.createGame(for: team)
                XCTAssertTrue(success)
            }
        }
    }
    
    @MainActor
    func testFormStatePersistencePerformance() {
        // Test form state persistence performance
        measure {
            // Simulate form state changes and persistence
            for i in 0..<1000 {
                viewModel.gameResult = GameResult.allCases[i % 3]
                viewModel.teamScore = i % 201
                viewModel.opponentScore = (i + 5) % 201
                viewModel.opponentName = "Team \(i % 10)"
                viewModel.gameLocation = "Location \(i % 5)"
                viewModel.gameNotes = "Notes \(i % 3)"
                viewModel.gameDate = Date().addingTimeInterval(Double(i * 86400))
                viewModel.gameTime = Date().addingTimeInterval(Double(i * 3600))
                viewModel.isOpponentNameValid = !viewModel.opponentName.isEmpty
            }
        }
    }
    
    @MainActor
    func testErrorHandlingPerformance() {
        // Test error handling performance
        measure {
            // Simulate error conditions
            for i in 0..<1000 {
                // Invalid scores
                viewModel.teamScore = 250 + i
                let _ = viewModel.validateScore(viewModel.teamScore)
                
                // Invalid names
                let longName = String(repeating: "A", count: 51 + i)
                let _ = viewModel.validateOpponentName(longName)
                
                // Try to save with invalid data
                let team = createTestTeam()
                let _ = viewModel.createGame(for: team)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestTeam() -> Team {
        let team = Team(context: testContext)
        team.id = UUID()
        team.name = "Test Team"
        team.teamColor = "red"
        team.displayOrder = 0
        team.sport = "Basketball"
        return team
    }
} 