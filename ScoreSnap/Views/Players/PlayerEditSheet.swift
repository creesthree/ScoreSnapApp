//
//  PlayerEditSheet.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI

struct PlayerEditSheet: View {
    let player: Player?
    let onSave: (String, TeamColor, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selectedColor: TeamColor = Constants.Defaults.defaultPlayerColor
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    
    @StateObject private var viewModel: PlayersViewModel
    
    init(player: Player?, onSave: @escaping (String, TeamColor, String) -> Void) {
        self.player = player
        self.onSave = onSave
        self._viewModel = StateObject(wrappedValue: PlayersViewModel(viewContext: PersistenceController.shared.container.viewContext))
        
        // Initialize state with player data if editing
        if let player = player {
            self._name = State(initialValue: player.name ?? "")
            // For existing players, use the stored TeamColor or default
            if let colorString = player.playerColor, let teamColor = TeamColor(rawValue: colorString) {
                self._selectedColor = State(initialValue: teamColor)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Player Details") {
                    TextField("Player Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section("Available Colors") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Player Color")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Theme.Spacing.md) {
                            ForEach(TeamColor.allCases, id: \.self) { color in
                                TeamColorButton(
                                    color: color,
                                    isSelected: selectedColor == color,
                                    action: { selectedColor = color }
                                )
                            }
                        }
                        // Color preview
                        HStack {
                            Circle()
                                .fill(selectedColor.color)
                                .frame(width: 30, height: 30)
                            Text("Preview")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(player == nil ? "Add Player" : "Edit Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePlayer()
                    }
                    .disabled(name.trimmed.isEmpty)
                }
            }
            .alert("Validation Error", isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
        }
    }
    
    private func savePlayer() {
        let trimmedName = name.trimmed
        
        // Validate name using the same logic as PlayersViewModel
        guard viewModel.validatePlayerName(trimmedName) else {
            validationMessage = "Player name must be between 1 and 50 characters."
            showingValidationAlert = true
            return
        }
        
        // Check for duplicate names using the same logic as PlayersViewModel
        guard viewModel.isPlayerNameUnique(trimmedName, excluding: player) else {
            validationMessage = "A player with this name already exists."
            showingValidationAlert = true
            return
        }
        
        // Save the player, always use 'Basketball' as sport
        onSave(trimmedName, selectedColor, "Basketball")
        dismiss()
    }
}

#Preview {
    PlayerEditSheet(player: nil) { name, color, sport in
        print("Creating player: \(name)")
    }
} 