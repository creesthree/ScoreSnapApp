//
//  ContentView.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/16/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @EnvironmentObject var appContext: AppContext
    
    var body: some View {
        Group {
            if appContext.needsSetup {
                SetupView()
            } else {
                MainTabView()
            }
        }
        .onAppear {
            // AppContext automatically checks setup status on init
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppContext(viewContext: PersistenceController.preview.container.viewContext))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
