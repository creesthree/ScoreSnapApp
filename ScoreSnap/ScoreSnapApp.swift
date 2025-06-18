//
//  ScoreSnapApp.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/16/25.
//

//Stubbed Build Phase 1 teset code
import SwiftUI

@main
struct ScoreSnapApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(AppContext(viewContext: persistenceController.container.viewContext))
        }
    }
}

