//
//  HomeViewModel.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI
import CoreData
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var recentGames: [Game] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let viewContext: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }
    
    // MARK: - Recent Games Fetching
    
    func fetchRecentGames(for team: Team?, limit: Int = 10) {
        guard let team = team else {
            recentGames = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let request: NSFetchRequest<Game> = Game.fetchRequest()
        request.predicate = NSPredicate(format: "team == %@", team)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Game.gameDate, ascending: false),
            NSSortDescriptor(keyPath: \Game.gameEditDate, ascending: false)
        ]
        request.fetchLimit = limit
        
        do {
            let games = try viewContext.fetch(request)
            recentGames = games
        } catch {
            errorMessage = "Failed to load recent games: \(error.localizedDescription)"
            recentGames = []
        }
        
        isLoading = false
    }
    
    // MARK: - Game Management
    
    func editGame(_ game: Game) {
        // TODO: Navigate to game edit view
        print("Edit game: \(game.opponentName ?? "Unknown") - \(game.teamScore)-\(game.opponentScore)")
    }
    
    func deleteGame(_ game: Game) {
        viewContext.delete(game)
        
        do {
            try viewContext.save()
            // Remove from local array
            recentGames.removeAll { $0.id == game.id }
        } catch {
            errorMessage = "Failed to delete game: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Team Statistics
    
    func getTeamRecord(for team: Team?) -> (wins: Int, losses: Int, ties: Int, totalGames: Int) {
        guard let team = team else {
            return (0, 0, 0, 0)
        }
        
        let request: NSFetchRequest<Game> = Game.fetchRequest()
        request.predicate = NSPredicate(format: "team == %@", team)
        
        do {
            let games = try viewContext.fetch(request)
            let wins = games.filter { $0.isWin }.count
            let losses = games.filter { !$0.isWin && !$0.isTie }.count
            let ties = games.filter { $0.isTie }.count
            return (wins, losses, ties, games.count)
        } catch {
            errorMessage = "Failed to load team record: \(error.localizedDescription)"
            return (0, 0, 0, 0)
        }
    }
    
    func getWinPercentage(for team: Team?) -> Double {
        let record = getTeamRecord(for: team)
        guard record.totalGames > 0 else { return 0.0 }
        
        // Ties count as half wins for win percentage
        let adjustedWins = Double(record.wins) + (Double(record.ties) * 0.5)
        return adjustedWins / Double(record.totalGames)
    }
    
    // MARK: - Recent Game Trends
    
    func getRecentStreak(for team: Team?, limit: Int = 5) -> (type: StreakType, count: Int) {
        guard let team = team else {
            return (.none, 0)
        }
        
        let request: NSFetchRequest<Game> = Game.fetchRequest()
        request.predicate = NSPredicate(format: "team == %@", team)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Game.gameDate, ascending: false)]
        request.fetchLimit = limit
        
        do {
            let games = try viewContext.fetch(request)
            return calculateStreak(from: games)
        } catch {
            return (.none, 0)
        }
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
    
    // MARK: - Data Refresh
    
    func refreshData(for team: Team?) {
        fetchRecentGames(for: team)
    }
}

enum StreakType {
    case win, loss, tie, none
    
    var displayText: String {
        switch self {
        case .win: return "W"
        case .loss: return "L"
        case .tie: return "T"
        case .none: return ""
        }
    }
    
    var color: Color {
        switch self {
        case .win: return Theme.Colors.win
        case .loss: return Theme.Colors.loss
        case .tie: return Theme.Colors.tie
        case .none: return Theme.Colors.secondaryText
        }
    }
} 