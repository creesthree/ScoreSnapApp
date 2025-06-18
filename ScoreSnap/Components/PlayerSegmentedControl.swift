//
//  PlayerSegmentedControl.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI
import CoreData

struct PlayerSegmentedControl: View {
    @EnvironmentObject var appContext: AppContext
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Player.displayOrder, ascending: true)],
        animation: .default
    )
    private var players: FetchedResults<Player>
    
    @State private var showingPlayerPicker = false
    
    private var visiblePlayers: [Player] {
        Array(players.prefix(3))
    }
    
    private var hasMorePlayers: Bool {
        players.count > 3
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(visiblePlayers, id: \.id) { player in
                PlayerSegmentButton(
                    player: player,
                    isSelected: player == appContext.currentPlayer
                ) {
                    appContext.switchToPlayer(player)
                }
            }
            
            if hasMorePlayers {
                Button(action: {
                    showingPlayerPicker = true
                }) {
                    Text("More")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.Colors.secondaryBackground)
                        .cornerRadius(Theme.CornerRadius.sm)
                }
            }
        }
        .sheet(isPresented: $showingPlayerPicker) {
            PlayerPickerSheet(players: Array(players))
        }
    }
}

struct PlayerSegmentButton: View {
    let player: Player
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(player.name ?? "Unknown")
                .font(Theme.Typography.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? Theme.Colors.buttonText : Theme.Colors.primaryText)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(
                    isSelected ? 
                    Theme.TeamColors.color(from: player.playerColor) : 
                    Theme.Colors.secondaryBackground
                )
                .cornerRadius(Theme.CornerRadius.sm)
        }
        .animation(Theme.Animation.quick, value: isSelected)
    }
}

struct PlayerPickerSheet: View {
    @EnvironmentObject var appContext: AppContext
    @Environment(\.dismiss) private var dismiss
    
    let players: [Player]
    
    var body: some View {
        NavigationView {
            List(players, id: \.id) { player in
                HStack {
                    Circle()
                        .fill(Theme.TeamColors.color(from: player.playerColor))
                        .frame(width: 12, height: 12)
                    
                    Text(player.name ?? "Unknown")
                        .font(Theme.Typography.body)
                    
                    Spacer()
                    
                    if player == appContext.currentPlayer {
                        Image(systemName: "checkmark")
                            .foregroundColor(Theme.Colors.primary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    appContext.switchToPlayer(player)
                    dismiss()
                }
            }
            .navigationTitle("Select Player")
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

#Preview {
    PlayerSegmentedControl()
        .environmentObject(AppContext(viewContext: PersistenceController.preview.container.viewContext))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 