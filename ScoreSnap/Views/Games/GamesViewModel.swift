//
//  GamesViewModel.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/20/25.
//

import SwiftUI
import CoreData
import Combine

@MainActor
class GamesViewModel: ObservableObject {
    @Published var teams: [Team] = []
    @Published var games: [UUID: [Game]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let viewContext: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    private var currentPlayer: Player?
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }
    
    // MARK: - Data Loading
    
    func loadData(for player: Player) {
        guard currentPlayer != player else { return }
        
        currentPlayer = player
        isLoading = true
        errorMessage = nil
        
        Task {
            await loadTeamsAndGames(for: player)
        }
    }
    
    private func loadTeamsAndGames(for player: Player) async {
        do {
            // Fetch teams for player, ordered by displayOrder
            let teamRequest: NSFetchRequest<Team> = Team.fetchRequest()
            teamRequest.predicate = NSPredicate(format: "player == %@", player)
            teamRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Team.displayOrder, ascending: true)]
            
            let fetchedTeams = try viewContext.fetch(teamRequest)
            
            // Fetch games for each team
            var gamesDict: [UUID: [Game]] = [:]
            
            for team in fetchedTeams {
                guard let teamId = team.id else { continue }
                
                let gameRequest: NSFetchRequest<Game> = Game.fetchRequest()
                gameRequest.predicate = NSPredicate(format: "team == %@", team)
                gameRequest.sortDescriptors = [
                    NSSortDescriptor(keyPath: \Game.gameDate, ascending: false),
                    NSSortDescriptor(keyPath: \Game.gameEditDate, ascending: false)
                ]
                
                let teamGames = try viewContext.fetch(gameRequest)
                gamesDict[teamId] = teamGames
            }
            
            await MainActor.run {
                self.teams = fetchedTeams
                self.games = gamesDict
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load data: \(error.localizedDescription)"
                self.teams = []
                self.games = [:]
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Game Management
    
    func deleteGame(_ game: Game) {
        viewContext.delete(game)
        
        do {
            try viewContext.save()
            
            // Update local data
            if let team = game.team, let teamId = team.id {
                games[teamId]?.removeAll { $0.id == game.id }
            }
            
        } catch {
            errorMessage = "Failed to delete game: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Team Statistics
    
    func getTeamRecord(for team: Team) -> (wins: Int, losses: Int, ties: Int, totalGames: Int) {
        guard let teamId = team.id,
              let teamGames = games[teamId] else {
            return (0, 0, 0, 0)
        }
        
        let wins = teamGames.filter { $0.isWin }.count
        let losses = teamGames.filter { !$0.isWin && !$0.isTie }.count
        let ties = teamGames.filter { $0.isTie }.count
        
        return (wins, losses, ties, teamGames.count)
    }
    
    func getRecentStreak(for team: Team, limit: Int = 5) -> (type: StreakType, count: Int) {
        guard let teamId = team.id,
              let teamGames = games[teamId] else {
            return (.none, 0)
        }
        
        let recentGames = Array(teamGames.prefix(limit))
        return calculateStreak(from: recentGames)
    }
    
    private func calculateStreak(from games: [Game]) -> (type: StreakType, count: Int) {
        guard !games.isEmpty else { return (.none, 0) }
        
        let firstGame = games[0]
        var streakType: StreakType
        
        if firstGame.isWin {
            streakType = .win
        } else if firstGame.isTie {
            streakType = .tie
        } else {
            streakType = .loss
        }
        
        var count = 1
        
        for game in games.dropFirst() {
            let gameType: StreakType
            if game.isWin {
                gameType = .win
            } else if game.isTie {
                gameType = .tie
            } else {
                gameType = .loss
            }
            
            if gameType == streakType {
                count += 1
            } else {
                break
            }
        }
        
        return (streakType, count)
    }
    
    // MARK: - Analytics
    
    func getTeamAnalytics(for team: Team) -> TeamAnalytics {
        let record = getTeamRecord(for: team)
        let currentStreak = getRecentStreak(for: team)
        
        return TeamAnalytics(
            wins: record.wins,
            losses: record.losses,
            ties: record.ties,
            totalGames: record.totalGames,
            currentStreak: currentStreak
        )
    }
    
    // MARK: - Helper Functions
    
    func hasGames(for team: Team) -> Bool {
        guard let teamId = team.id else { return false }
        return !(games[teamId]?.isEmpty ?? true)
    }
    
    func getGamesCount(for team: Team) -> Int {
        guard let teamId = team.id else { return 0 }
        return games[teamId]?.count ?? 0
    }
    
    func refreshData() {
        guard let player = currentPlayer else { return }
        loadData(for: player)
    }
}

// MARK: - Supporting Types

struct TeamAnalytics {
    let wins: Int
    let losses: Int
    let ties: Int
    let totalGames: Int
    let currentStreak: (type: StreakType, count: Int)
    
    init(wins: Int, losses: Int, ties: Int, totalGames: Int, currentStreak: (type: StreakType, count: Int)) {
        self.wins = wins
        self.losses = losses
        self.ties = ties
        self.totalGames = totalGames
        self.currentStreak = currentStreak
    }
} 