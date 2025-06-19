//
//  TeamDropdown.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI
import CoreData

struct TeamDropdown: View {
    @EnvironmentObject var appContext: AppContext
    @Environment(\.managedObjectContext) private var viewContext
    
    let player: Player
    
    @FetchRequest
    private var teams: FetchedResults<Team>
    
    @State private var showingTeamPicker = false
    
    init(player: Player) {
        self.player = player
        self._teams = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Team.displayOrder, ascending: true)],
            predicate: NSPredicate(format: "player == %@", player),
            animation: .default
        )
    }
    
    var body: some View {
        Button(action: {
            showingTeamPicker = true
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                // Team color indicator
                Circle()
                    .fill(Theme.TeamColors.color(from: appContext.currentTeam?.teamColor))
                    .frame(width: 16, height: 16)
                
                Text(appContext.currentTeam?.name ?? "Select Team")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.secondaryBackground)
            .cornerRadius(Theme.CornerRadius.md)
        }
        .sheet(isPresented: $showingTeamPicker) {
            TeamPickerSheet(teams: Array(teams))
        }
        .accessibilityLabel("Select team for \(player.name ?? "player")")
        .accessibilityHint("Tap to choose a team")
    }
}

struct TeamPickerSheet: View {
    @EnvironmentObject var appContext: AppContext
    @Environment(\.dismiss) private var dismiss
    
    let teams: [Team]
    
    var body: some View {
        NavigationView {
            List {
                if teams.isEmpty {
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "person.3.fill")
                            .font(.largeTitle)
                            .foregroundColor(Theme.Colors.secondaryText)
                        
                        Text("No Teams Yet")
                            .font(Theme.Typography.title3)
                            .foregroundColor(Theme.Colors.primaryText)
                        
                        Text("Create your first team to get started")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                        
                        Button("Create Team") {
                            // TODO: Navigate to team creation
                            dismiss()
                        }
                        .primaryButtonStyle()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xl)
                } else {
                    ForEach(teams, id: \.id) { team in
                        TeamRowView(team: team) {
                            appContext.switchToTeam(team)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Select Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TeamRowView: View {
    @EnvironmentObject var appContext: AppContext
    let team: Team
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Team color indicator
            Circle()
                .fill(Theme.TeamColors.color(from: team.teamColor))
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(team.name ?? "Unknown Team")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Text(team.sport ?? "Basketball")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            
            Spacer()
            
            if team == appContext.currentTeam {
                Image(systemName: "checkmark")
                    .foregroundColor(Theme.Colors.primary)
                    .font(.body.weight(.semibold))
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}

#Preview {
    TeamDropdown(player: Player())
        .environmentObject(AppContext(viewContext: PersistenceController.preview.container.viewContext))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 