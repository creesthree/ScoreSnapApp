//
//  PlayersViewModel.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI
import CoreData
import Combine

@MainActor
class PlayersViewModel: ObservableObject {
    @Published var players: [Player] = []
    @Published var teams: [Team] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isEditMode = false
    
    private let viewContext: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        setupObservers()
        loadData()
    }
    
    // MARK: - Data Loading
    
    private func setupObservers() {
        // Observe Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: viewContext)
            .sink { [weak self] _ in
                self?.loadData()
            }
            .store(in: &cancellables)
    }
    
    func loadData() {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load players sorted by display order
            let playerRequest: NSFetchRequest<Player> = Player.fetchRequest()
            playerRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Player.displayOrder, ascending: true)]
            players = try viewContext.fetch(playerRequest)
            
            // Load teams sorted by display order
            let teamRequest: NSFetchRequest<Team> = Team.fetchRequest()
            teamRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Team.displayOrder, ascending: true)]
            teams = try viewContext.fetch(teamRequest)
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Player CRUD Operations
    
    func createPlayer(name: String, color: Color, sport: String = "Basketball") {
        // Validate name before creating
        guard validatePlayerName(name) else { return }
        guard isPlayerNameUnique(name) else { return }
        
        let player = Player(context: viewContext)
        player.id = UUID()
        player.name = name.trimmed
        player.playerColor = color.toHex()
        player.sport = sport
        player.displayOrder = Int32(players.count)
        
        saveContext()
    }
    
    func updatePlayer(_ player: Player, name: String, color: Color, sport: String) {
        // Validate name before updating
        guard validatePlayerName(name) else { return }
        guard isPlayerNameUnique(name, excluding: player) else { return }
        
        player.name = name.trimmed
        player.playerColor = color.toHex()
        player.sport = sport
        
        saveContext()
    }
    
    func deletePlayer(_ player: Player) {
        // Delete all teams and games associated with this player
        viewContext.delete(player)
        saveContext()
    }
    
    // MARK: - Team CRUD Operations
    
    func createTeam(name: String, color: Color, player: Player, sport: String = "Basketball") {
        // Validate name before creating
        guard validateTeamName(name) else { return }
        guard isTeamNameUnique(name, for: player) else { return }
        
        let team = Team(context: viewContext)
        team.id = UUID()
        team.name = name.trimmed
        team.teamColor = color.toHex()
        team.sport = sport
        team.player = player
        team.displayOrder = Int32(teams.filter { $0.player == player }.count)
        
        saveContext()
    }
    
    func updateTeam(_ team: Team, name: String, color: Color, sport: String) {
        // Validate name before updating
        guard validateTeamName(name) else { return }
        guard let player = team.player else { return }
        guard isTeamNameUnique(name, for: player, excluding: team) else { return }
        
        team.name = name.trimmed
        team.teamColor = color.toHex()
        team.sport = sport
        
        saveContext()
    }
    
    func deleteTeam(_ team: Team) {
        // Delete all games associated with this team
        viewContext.delete(team)
        saveContext()
    }
    
    // MARK: - Reordering Operations
    
    func movePlayer(from source: IndexSet, to destination: Int) {
        players.move(fromOffsets: source, toOffset: destination)
        updatePlayerDisplayOrders()
        saveContext()
    }
    
    func moveTeam(from source: IndexSet, to destination: Int, for player: Player) {
        let playerTeams = teams.filter { $0.player == player }
        var mutableTeams = playerTeams
        mutableTeams.move(fromOffsets: source, toOffset: destination)
        
        // Update display orders for the moved teams
        for (index, team) in mutableTeams.enumerated() {
            team.displayOrder = Int32(index)
        }
        
        saveContext()
        loadData() // Reload to get updated order
    }
    
    private func updatePlayerDisplayOrders() {
        for (index, player) in players.enumerated() {
            player.displayOrder = Int32(index)
        }
    }
    
    // MARK: - Helper Methods
    
    func teamsForPlayer(_ player: Player) -> [Team] {
        return teams.filter { $0.player == player }
            .sorted { $0.displayOrder < $1.displayOrder }
    }
    
    func getPlayerColor(_ player: Player) -> Color {
        return Theme.TeamColors.color(from: player.playerColor)
    }
    
    func getTeamColor(_ team: Team) -> Color {
        return Theme.TeamColors.color(from: team.teamColor)
    }
    
    func validatePlayerName(_ name: String) -> Bool {
        let trimmedName = name.trimmed
        return !trimmedName.isEmpty && trimmedName.count <= 50
    }
    
    func validateTeamName(_ name: String) -> Bool {
        let trimmedName = name.trimmed
        return !trimmedName.isEmpty && trimmedName.count <= 50
    }
    
    func isPlayerNameUnique(_ name: String, excluding player: Player? = nil) -> Bool {
        let trimmedName = name.trimmed.lowercased()
        return !players.contains { existingPlayer in
            existingPlayer != player && existingPlayer.name?.lowercased() == trimmedName
        }
    }
    
    func isTeamNameUnique(_ name: String, for player: Player, excluding team: Team? = nil) -> Bool {
        let trimmedName = name.trimmed.lowercased()
        let playerTeams = teamsForPlayer(player)
        return !playerTeams.contains { existingTeam in
            existingTeam != team && existingTeam.name?.lowercased() == trimmedName
        }
    }
    
    // MARK: - Context Management
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    func refreshData() {
        loadData()
    }
} 