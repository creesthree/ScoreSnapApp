import Foundation
import CoreData

extension Game {
    // MARK: - Computed Properties
    
    var isWin: Bool {
        teamScore > opponentScore
    }
    
    var isLoss: Bool {
        teamScore < opponentScore
    }
    
    var isTie: Bool {
        teamScore == opponentScore
    }
    
    var gameResult: String {
        if isWin { return "W" }
        if isLoss { return "L" }
        return "T"
    }
    
    var scoreDisplay: String {
        "\(teamScore)-\(opponentScore)"
    }
    
    var dateDisplay: String {
        guard let date = gameDate else { return "No date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // MARK: - Validation
    
    func validate() -> Bool {
        guard let _ = gameDate,
              let _ = opponentName,
              teamScore >= 0,
              opponentScore >= 0 else {
            return false
        }
        return true
    }
    
    // MARK: - Image Management
    
    func setScoreboardImage(_ imageData: Data?) {
        self.scoreboardImage = imageData
        self.lastModified = Date()
    }
    
    func clearScoreboardImage() {
        self.scoreboardImage = nil
        self.lastModified = Date()
    }
    
    // MARK: - Team Management
    
    func setTeam(_ team: Team?) {
        if let oldTeam = self.team {
            oldTeam.removeGame(self)
        }
        if let newTeam = team {
            newTeam.addGame(self)
        }
    }
} 