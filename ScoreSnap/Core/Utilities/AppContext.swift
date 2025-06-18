//
//  AppContext.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI
import CoreData
import Combine

@MainActor
class AppContext: ObservableObject {
    @Published var currentPlayer: Player?
    @Published var currentTeam: Team?
    
    private let viewContext: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    // UserDefaults keys
    private let lastViewedPlayerIDKey = "lastViewedPlayerID"
    private let lastViewedTeamIDKey = "lastViewedTeamID"
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        loadPersistedContext()
        setupContextObservers()
    }
    
    // MARK: - Context Loading
    
    private func loadPersistedContext() {
        // Load last viewed player
        if let playerIDString = UserDefaults.standard.string(forKey: lastViewedPlayerIDKey),
           let playerID = UUID(uuidString: playerIDString) {
            currentPlayer = fetchPlayer(by: playerID)
        }
        
        // If no persisted player or player not found, default to first player
        if currentPlayer == nil {
            currentPlayer = fetchFirstPlayer()
        }
        
        // Load last viewed team for current player
        if let currentPlayer = currentPlayer {
            if let teamIDString = UserDefaults.standard.string(forKey: lastViewedTeamIDKey),
               let teamID = UUID(uuidString: teamIDString),
               let team = fetchTeam(by: teamID, for: currentPlayer) {
                currentTeam = team
            } else {
                // Default to first team for current player
                currentTeam = fetchFirstTeam(for: currentPlayer)
            }
        }
    }
    
    private func setupContextObservers() {
        // Save context when currentPlayer changes
        $currentPlayer
            .compactMap { $0?.id?.uuidString }
            .sink { [weak self] playerIDString in
                UserDefaults.standard.set(playerIDString, forKey: self?.lastViewedPlayerIDKey ?? "")
            }
            .store(in: &cancellables)
        
        // Save context when currentTeam changes
        $currentTeam
            .compactMap { $0?.id?.uuidString }
            .sink { [weak self] teamIDString in
                UserDefaults.standard.set(teamIDString, forKey: self?.lastViewedTeamIDKey ?? "")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Context Switching Methods
    
    func switchToPlayer(_ player: Player) {
        currentPlayer = player
        // When switching players, default to their first team
        currentTeam = fetchFirstTeam(for: player)
    }
    
    func switchToTeam(_ team: Team) {
        // Ensure team belongs to current player
        if team.player == currentPlayer {
            currentTeam = team
        }
    }
    
    func switchToPlayerAndTeam(_ player: Player, _ team: Team) {
        currentPlayer = player
        if team.player == player {
            currentTeam = team
        } else {
            currentTeam = fetchFirstTeam(for: player)
        }
    }
    
    // MARK: - Cascade Logic for Deletions
    
    func handlePlayerDeletion(_ deletedPlayer: Player) {
        if currentPlayer == deletedPlayer {
            // Default to first remaining player
            currentPlayer = fetchFirstPlayer()
            if let newCurrentPlayer = currentPlayer {
                currentTeam = fetchFirstTeam(for: newCurrentPlayer)
            } else {
                currentTeam = nil
            }
        }
    }
    
    func handleTeamDeletion(_ deletedTeam: Team) {
        if currentTeam == deletedTeam {
            // Default to first remaining team for current player
            if let currentPlayer = currentPlayer {
                currentTeam = fetchFirstTeam(for: currentPlayer)
            }
        }
    }
    
    // MARK: - Core Data Fetch Helpers
    
    private func fetchPlayer(by id: UUID) -> Player? {
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }
    
    func fetchFirstPlayer() -> Player? {
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Player.displayOrder, ascending: true)]
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }
    
    private func fetchTeam(by id: UUID, for player: Player) -> Team? {
        let request: NSFetchRequest<Team> = Team.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ AND player == %@", id as CVarArg, player)
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }
    
    private func fetchFirstTeam(for player: Player) -> Team? {
        let request: NSFetchRequest<Team> = Team.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@", player)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Team.displayOrder, ascending: true)]
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }
    
    // MARK: - Setup Workflow Support
    
    var needsSetup: Bool {
        currentPlayer == nil
    }
    
    func completeSetup(with player: Player, and team: Team) {
        currentPlayer = player
        currentTeam = team
    }
} 