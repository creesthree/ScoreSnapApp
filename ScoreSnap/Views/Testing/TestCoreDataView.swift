import SwiftUI
import CoreData

struct TestCoreDataView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var testResults: [String] = []
    @State private var testRun = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Core Data Integration Tests")
                .font(.title2)
                .padding(.bottom)
            Button("Run Tests") {
                runTests()
            }
            .padding(.bottom)
            ForEach(testResults, id: \.self) { result in
                Text(result)
                    .font(.system(size: 15, weight: .regular, design: .monospaced))
                    .foregroundColor(result.contains("PASS") ? .green : .red)
            }
            Spacer()
        }
        .padding()
    }

//      Cursor-written runTests
    private func runTests() {
        testResults.removeAll()
        // 1. Core Data Test: Can create Player with Team with Game
        let player = Player(context: viewContext)
        player.id = UUID()
        player.name = "Test Player"
        player.playerColor = "blue"
        player.displayOrder = 0
        player.sport = "Basketball"

        let team = Team(context: viewContext)
        team.id = UUID()
        team.name = "Test Team"
        team.teamColor = "red"
        team.displayOrder = 0
        team.sport = "Basketball"
        team.player = player

        let game = Game(context: viewContext)
        game.id = UUID()
        game.gameDate = Date()
        game.gameTime = Date()
        game.gameLocation = "Test Gym"
        game.teamScore = 100
        game.opponentScore = 90
        game.isWin = true
        game.isTie = false
        game.opponentName = "Opponent"
        game.notes = "Test game"
        game.gameEditDate = Date()
        game.gameEditTime = Date()
        game.team = team

        do {
            try viewContext.save()
            testResults.append("Core Data Test: PASS - Created Player, Team, Game")
        } catch {
            testResults.append("Core Data Test: FAIL - \(error.localizedDescription)")
            return
        }

        // 2. Relationship Test: Player.teams contains created teams
        let fetchRequest: NSFetchRequest<Player> = Player.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", player.id! as CVarArg)
        if let fetchedPlayer = (try? viewContext.fetch(fetchRequest))?.first,
           let teams = fetchedPlayer.teams as? Set<Team>,
           teams.contains(where: { $0.id == team.id }) {
            testResults.append("Relationship Test: PASS - Player.teams contains created team")
        } else {
            testResults.append("Relationship Test: FAIL - Player.teams does not contain created team")
        }

        // 3. Cascade Test: Deleting player deletes teams and games
        // Store IDs before deletion for verification
        guard let teamId = team.id, let gameId = game.id else {
            testResults.append("Cascade Test: FAIL - Team or Game ID is nil before deletion")
            return
        }
        
        viewContext.delete(player)
        do {
            try viewContext.save()
        } catch {
            testResults.append("Cascade Test: FAIL - Could not delete player: \(error.localizedDescription)")
            return
        }
        
        // Check if team and game were deleted by searching for their IDs
        let teamFetch: NSFetchRequest<Team> = Team.fetchRequest()
        teamFetch.predicate = NSPredicate(format: "id == %@", teamId as CVarArg)
        let gameFetch: NSFetchRequest<Game> = Game.fetchRequest()
        gameFetch.predicate = NSPredicate(format: "id == %@", gameId as CVarArg)
        
        let teamExists = ((try? viewContext.fetch(teamFetch))?.first != nil)
        let gameExists = ((try? viewContext.fetch(gameFetch))?.first != nil)
        
        if !teamExists && !gameExists {
            testResults.append("Cascade Test: PASS - Deleting player deleted team and game")
        } else {
            testResults.append("Cascade Test: FAIL - Team or Game still exists after deleting player")
        }

        // 4. Persistence Test: Data survives app restart
        // We'll create a new player and team, save, then fetch again
        let persistentPlayer = Player(context: viewContext)
        persistentPlayer.id = UUID()
        persistentPlayer.name = "Persistent Player"
        persistentPlayer.playerColor = "green"
        persistentPlayer.displayOrder = 1
        persistentPlayer.sport = "Basketball"
        do {
            try viewContext.save()
        } catch {
            testResults.append("Persistence Test: FAIL - Could not save persistent player: \(error.localizedDescription)")
            return
        }
        // Simulate app restart by resetting the context
        viewContext.reset()
        let persistentFetch: NSFetchRequest<Player> = Player.fetchRequest()
        persistentFetch.predicate = NSPredicate(format: "name == %@", "Persistent Player")
        let persistentExists = ((try? viewContext.fetch(persistentFetch))?.first != nil)
        if persistentExists {
            testResults.append("Persistence Test: PASS - Data survives app restart (context reset)")
        } else {
            testResults.append("Persistence Test: FAIL - Data did not survive app restart (context reset)")
        }
    }

    
//  claude-written run tests, simpler.
//    private func runTests() {
//        let viewContext = PersistenceController.shared.container.viewContext
//        
//        // Clear existing data
//        testResults.removeAll()
//        
//        // 1. Create Player
//        let player = Player(context: viewContext)
//        player.id = UUID()
//        player.name = "Test Player"
//        player.playerColor = "#FF0000"
//        player.displayOrder = 1
//        player.sport = "Basketball"
//        
//        // 2. Create Team
//        let team = Team(context: viewContext)
//        team.id = UUID()  // ← Ensure ID is set
//        team.name = "Test Team"
//        team.teamColor = "#0000FF"
//        team.displayOrder = 1
//        team.sport = "Basketball"
//        team.player = player
//        
//        // Save and check for errors
//        do {
//            try viewContext.save()
//            testResults.append("Creation Test: PASS - Player and Team created")
//        } catch {
//            testResults.append("Creation Test: FAIL - \(error.localizedDescription)")
//            return  // Don't continue if creation failed
//        }
//        
//        // 3. Verify IDs exist before using them
//        guard let playerId = player.id, let teamId = team.id else {
//            testResults.append("ID Test: FAIL - Player or Team ID is nil")
//            return
//        }
//        
//        // 4. Test relationships with safe unwrapping
//        let fetchedPlayer = try? viewContext.fetch(Player.fetchRequest()).first
//        if let fetchedPlayer = fetchedPlayer,
//           let teams = fetchedPlayer.teams as? Set<Team>,
//           teams.contains(where: { $0.id == teamId }) {
//            testResults.append("Relationship Test: PASS")
//        } else {
//            testResults.append("Relationship Test: FAIL")
//        }
//        
//        // 5. Cascade test with safe unwrapping
//        do {
//            viewContext.delete(player)
//            try viewContext.save()
//            
//            // Check if team was deleted
//            let teamFetch: NSFetchRequest<Team> = Team.fetchRequest()
//            teamFetch.predicate = NSPredicate(format: "id == %@", teamId as CVarArg)
//            let remainingTeams = try? viewContext.fetch(teamFetch)
//            
//            if remainingTeams?.isEmpty == true {
//                testResults.append("Cascade Test: PASS")
//            } else {
//                testResults.append("Cascade Test: FAIL - Team still exists")
//            }
//        } catch {
//            testResults.append("Cascade Test: FAIL - \(error.localizedDescription)")
//        }
//    }
}


