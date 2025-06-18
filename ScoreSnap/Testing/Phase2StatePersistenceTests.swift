//
//  Phase2StatePersistenceTests.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import XCTest
import SwiftUI
import CoreData
import Combine
@testable import ScoreSnap

class Phase2StatePersistenceTests: XCTestCase {
    
    var testContext: NSManagedObjectContext!
    var appContext: AppContext!
    var cancellables: Set<AnyCancellable>!
    
    // Test UserDefaults suite to isolate test data
    let testSuiteName = "ScoreSnapTestSuite"
    var testUserDefaults: UserDefaults!
    
    @MainActor
    override func setUp() {
        super.setUp()
        
        // Create test UserDefaults suite
        testUserDefaults = UserDefaults(suiteName: testSuiteName)
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        
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
        appContext = AppContext(viewContext: testContext)
        cancellables = Set<AnyCancellable>()
        
        // Clear any existing UserDefaults for clean test state
        clearUserDefaults()
    }
    
    override func tearDown() {
        cancellables?.removeAll()
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        testContext = nil
        appContext = nil
        cancellables = nil
        testUserDefaults = nil
        clearUserDefaults()
        super.tearDown()
    }
    
    private func clearUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "lastViewedPlayerID")
        UserDefaults.standard.removeObject(forKey: "lastViewedTeamID")
    }
    
    // MARK: - Basic Persistence Tests
    
    @MainActor
    func testPlayerPersistence() {
        // Create test player
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        try! testContext.save()
        
        // Set current player
        appContext.switchToPlayer(player)
        
        // Wait for UserDefaults to be updated
        let expectation = XCTestExpectation(description: "UserDefaults updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify persistence
        let savedPlayerID = UserDefaults.standard.string(forKey: "lastViewedPlayerID")
        XCTAssertEqual(savedPlayerID, player.id?.uuidString)
    }
    
    @MainActor
    func testTeamPersistence() {
        // Create test data
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Set current team
        appContext.switchToPlayerAndTeam(player, team)
        
        // Wait for UserDefaults to be updated
        let expectation = XCTestExpectation(description: "UserDefaults updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify persistence
        let savedPlayerID = UserDefaults.standard.string(forKey: "lastViewedPlayerID")
        let savedTeamID = UserDefaults.standard.string(forKey: "lastViewedTeamID")
        
        XCTAssertEqual(savedPlayerID, player.id?.uuidString)
        XCTAssertEqual(savedTeamID, team.id?.uuidString)
    }
    
    // MARK: - State Restoration Tests
    
    @MainActor
    func testStateRestorationOnAppLaunch() {
        // Create test data
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        let team1 = createTestTeam(name: "Team 1", player: player1, displayOrder: 0)
        let team2 = createTestTeam(name: "Team 2", player: player2, displayOrder: 0)
        try! testContext.save()
        
        // Set initial state
        appContext.switchToPlayerAndTeam(player2, team2)
        
        // Wait for persistence
        let saveExpectation = XCTestExpectation(description: "State saved")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            saveExpectation.fulfill()
        }
        wait(for: [saveExpectation], timeout: 1.0)
        
        // Create new AppContext (simulating app restart)
        let newAppContext = AppContext(viewContext: testContext)
        
        // Verify state restoration
        XCTAssertEqual(newAppContext.currentPlayer?.id, player2.id)
        XCTAssertEqual(newAppContext.currentTeam?.id, team2.id)
    }
    
    @MainActor
    func testStateRestorationWithMissingPlayer() {
        // Create and save a player ID to UserDefaults
        let fakePlayerID = UUID().uuidString
        UserDefaults.standard.set(fakePlayerID, forKey: "lastViewedPlayerID")
        
        // Create actual test data
        let realPlayer = createTestPlayer(name: "Real Player", displayOrder: 0)
        try! testContext.save()
        
        // Create new AppContext (simulating app restart with missing player)
        let newAppContext = AppContext(viewContext: testContext)
        
        // Should default to first available player
        XCTAssertEqual(newAppContext.currentPlayer?.id, realPlayer.id)
    }
    
    @MainActor
    func testStateRestorationWithMissingTeam() {
        // Create test data
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Set valid player but invalid team ID
        UserDefaults.standard.set(player.id?.uuidString, forKey: "lastViewedPlayerID")
        UserDefaults.standard.set(UUID().uuidString, forKey: "lastViewedTeamID")
        
        // Create new AppContext
        let newAppContext = AppContext(viewContext: testContext)
        
        // Should restore player and default to their first team
        XCTAssertEqual(newAppContext.currentPlayer?.id, player.id)
        XCTAssertEqual(newAppContext.currentTeam?.id, team.id)
    }
    
    // MARK: - Reactive State Tests
    
    @MainActor
    func testReactiveStateUpdates() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        try! testContext.save()
        
        var receivedPlayerUpdates: [Player?] = []
        
        // Subscribe to player changes
        appContext.$currentPlayer
            .sink { player in
                receivedPlayerUpdates.append(player)
            }
            .store(in: &cancellables)
        
        // Make changes
        appContext.switchToPlayer(player1)
        appContext.switchToPlayer(player2)
        appContext.switchToPlayer(player1)
        
        // Wait for updates
        let expectation = XCTestExpectation(description: "Reactive updates received")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify we received all updates
        XCTAssertEqual(receivedPlayerUpdates.count, 4) // Initial nil + 3 changes
        XCTAssertNil(receivedPlayerUpdates[0]) // Initial state
        XCTAssertEqual(receivedPlayerUpdates[1]?.id, player1.id)
        XCTAssertEqual(receivedPlayerUpdates[2]?.id, player2.id)
        XCTAssertEqual(receivedPlayerUpdates[3]?.id, player1.id)
    }
    
    // MARK: - Persistence Consistency Tests
    
    @MainActor
    func testPersistenceConsistencyAcrossMultipleSwitches() {
        // Create test data
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        let team1 = createTestTeam(name: "Team 1", player: player1, displayOrder: 0)
        let team2 = createTestTeam(name: "Team 2", player: player2, displayOrder: 0)
        try! testContext.save()
        
        // Perform multiple switches
        appContext.switchToPlayerAndTeam(player1, team1)
        
        // Wait and verify first state
        var expectation = XCTestExpectation(description: "First state saved")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(UserDefaults.standard.string(forKey: "lastViewedPlayerID"), player1.id?.uuidString)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "lastViewedTeamID"), team1.id?.uuidString)
        
        // Switch to second state
        appContext.switchToPlayerAndTeam(player2, team2)
        
        // Wait and verify second state
        expectation = XCTestExpectation(description: "Second state saved")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(UserDefaults.standard.string(forKey: "lastViewedPlayerID"), player2.id?.uuidString)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "lastViewedTeamID"), team2.id?.uuidString)
    }
    
    // MARK: - Edge Case Tests
    
    @MainActor
    func testPersistenceWithNilStates() {
        // Create test data
        let player = createTestPlayer(name: "Test Player", displayOrder: 0)
        let team = createTestTeam(name: "Test Team", player: player, displayOrder: 0)
        try! testContext.save()
        
        // Set initial state
        appContext.switchToPlayerAndTeam(player, team)
        
        // Wait for persistence
        let expectation = XCTestExpectation(description: "State saved")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify state is saved
        XCTAssertNotNil(UserDefaults.standard.string(forKey: "lastViewedPlayerID"))
        XCTAssertNotNil(UserDefaults.standard.string(forKey: "lastViewedTeamID"))
        
        // Delete the entities from Core Data
        testContext.delete(player)
        testContext.delete(team)
        try! testContext.save()
        
        // Create new AppContext (simulating restart with deleted entities)
        let newAppContext = AppContext(viewContext: testContext)
        
        // Should handle missing entities gracefully
        XCTAssertNil(newAppContext.currentPlayer)
        XCTAssertNil(newAppContext.currentTeam)
        XCTAssertTrue(newAppContext.needsSetup)
    }
    
    @MainActor
    func testConcurrentStateUpdates() {
        let player1 = createTestPlayer(name: "Player 1", displayOrder: 0)
        let player2 = createTestPlayer(name: "Player 2", displayOrder: 1)
        try! testContext.save()
        
        let group = DispatchGroup()
        
        // Perform concurrent updates
        for i in 0..<10 {
            group.enter()
            DispatchQueue.global().async {
                let player = i % 2 == 0 ? player1 : player2
                DispatchQueue.main.async {
                    self.appContext.switchToPlayer(player)
                    group.leave()
                }
            }
        }
        
        // Wait for all updates to complete
        let expectation = XCTestExpectation(description: "Concurrent updates completed")
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)
        
        // Verify final state is consistent
        let savedPlayerID = UserDefaults.standard.string(forKey: "lastViewedPlayerID")
        XCTAssertNotNil(savedPlayerID)
        XCTAssertTrue(savedPlayerID == player1.id?.uuidString || savedPlayerID == player2.id?.uuidString)
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testStatePersistencePerformance() {
        let players = (0..<10).map { createTestPlayer(name: "Player \($0)", displayOrder: Int32($0)) }
        try! testContext.save()
        
        measure {
            for player in players {
                appContext.switchToPlayer(player)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestPlayer(name: String, displayOrder: Int32) -> Player {
        let player = Player(context: testContext)
        player.id = UUID()
        player.name = name
        player.displayOrder = displayOrder
        player.sport = Constants.Basketball.defaultSport
        player.playerColor = Constants.Defaults.defaultPlayerColor.toHex()
        return player
    }
    
    private func createTestTeam(name: String, player: Player, displayOrder: Int32) -> Team {
        let team = Team(context: testContext)
        team.id = UUID()
        team.name = name
        team.displayOrder = displayOrder
        team.sport = Constants.Basketball.defaultSport
        team.teamColor = Constants.Defaults.defaultTeamColor.toHex()
        team.player = player
        return team
    }
} 
