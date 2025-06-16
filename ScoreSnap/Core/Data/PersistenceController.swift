import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        // Create sample data for previews
        let viewContext = controller.container.viewContext
        
        // Create a sample player
        let player = Player(context: viewContext)
        player.id = UUID()
        player.name = "Sample Player"
        player.playerColor = "blue"
        player.displayOrder = 0
        player.sport = "Basketball"
        
        // Create a sample team
        let team = Team(context: viewContext)
        team.id = UUID()
        team.name = "Sample Team"
        team.teamColor = "red"
        team.displayOrder = 0
        team.sport = "Basketball"
        team.player = player
        
        // Create a sample game
        let game = Game(context: viewContext)
        game.id = UUID()
        game.gameDate = Date()
        game.gameTime = Date()
        game.gameLocation = "Sample Gym"
        game.teamScore = 72
        game.opponentScore = 65
        game.isWin = true
        game.isTie = false
        game.opponentName = "Opponent Team"
        game.notes = "Sample game"
        game.gameEditDate = Date()
        game.gameEditTime = Date()
        game.team = team
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        
        return controller
    }()

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ScoreSnap")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Helper Methods
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Error saving context: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        return container.newBackgroundContext()
    }
} 