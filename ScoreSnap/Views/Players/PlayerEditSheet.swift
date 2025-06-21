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
    let onDelete: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selectedColor: TeamColor = Constants.Defaults.defaultPlayerColor
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @State private var showingDeleteConfirmation = false
    
    @StateObject private var viewModel: PlayersViewModel
    
    init(player: Player?, onSave: @escaping (String, TeamColor, String) -> Void, onDelete: (() -> Void)? = nil) {
        self.player = player
        self.onSave = onSave
        self.onDelete = onDelete
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
                    }
                }
                
                // Delete section - only show when editing existing player
                if player != nil {
                    Section {
                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Player")
                            }
                            .foregroundColor(.red)
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
            .alert("Delete Player", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this player? This will also delete all associated teams and games. This action cannot be undone.")
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