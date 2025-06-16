import Foundation
import CoreData

extension Player {
    // MARK: - Computed Properties
    
    var teamsArray: [Team] {
        let set = teams as? Set<Team> ?? []
        return set.sorted { $0.displayOrder < $1.displayOrder }
    }
    
    // MARK: - Team Management
    
    func addTeam(_ team: Team) {
        let teams = self.mutableSetValue(forKey: "teams")
        teams.add(team)
        team.displayOrder = Int32(teams.count - 1)
    }
    
    func removeTeam(_ team: Team) {
        let teams = self.mutableSetValue(forKey: "teams")
        teams.remove(team)
        
        // Reorder remaining teams
        for (index, team) in teamsArray.enumerated() {
            team.displayOrder = Int32(index)
        }
    }
    
    func reorderTeams(from source: IndexSet, to destination: Int) {
        var teams = teamsArray
        teams.move(fromOffsets: source, toOffset: destination)
        
        // Update display order
        for (index, team) in teams.enumerated() {
            team.displayOrder = Int32(index)
        }
    }
    
    // MARK: - Validation
    
    func validateName() -> Bool {
        guard let name = name else { return false }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Defaults
    
    static func defaultColor() -> String {
        return "blue"
    }
} 