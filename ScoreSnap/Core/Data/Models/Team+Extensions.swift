import Foundation
import CoreData

extension Team {
    // MARK: - Computed Properties
    
    var wins: Int {
        let set = games as? Set<Game> ?? []
        return set.filter { $0.isWin }.count
    }
    
    var losses: Int {
        let set = games as? Set<Game> ?? []
        return set.filter { !$0.isWin && !$0.isTie }.count
    }
    
    var ties: Int {
        let set = games as? Set<Game> ?? []
        return set.filter { $0.isTie }.count
    }
    
    var gamesArray: [Game] {
        let set = games as? Set<Game> ?? []
        return set.sorted { 
            guard let date1 = $0.gameDate, let date2 = $1.gameDate else { return false }
            return date1 > date2
        }
    }
    
    var recentGames: [Game] {
        Array(gamesArray.prefix(5))
    }
    
    var averageScore: Double {
        let set = games as? Set<Game> ?? []
        guard !set.isEmpty else { return 0 }
        let total = set.reduce(0) { $0 + Int($1.teamScore) }
        return Double(total) / Double(set.count)
    }
    
    var pointDifferential: Int {
        let set = games as? Set<Game> ?? []
        return set.reduce(0) { $0 + (Int($1.teamScore) - Int($1.opponentScore)) }
    }
    
    // MARK: - Game Management
    
    func addGame(_ game: Game) {
        let games = self.mutableSetValue(forKey: "games")
        games.add(game)
        game.team = self
    }
    
    func removeGame(_ game: Game) {
        let games = self.mutableSetValue(forKey: "games")
        games.remove(game)
        game.team = nil
    }
    
    // MARK: - Display
    
    var recordDisplay: String {
        "\(wins)-\(losses)-\(ties)"
    }
} 