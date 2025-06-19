//
//  PlayerEditSheet.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI

struct PlayerEditSheet: View {
    let player: Player?
    let onSave: (String, Color, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selectedColor: Color = Constants.Defaults.defaultPlayerColor
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    
    @StateObject private var viewModel: PlayersViewModel
    
    init(player: Player?, onSave: @escaping (String, Color, String) -> Void) {
        self.player = player
        self.onSave = onSave
        self._viewModel = StateObject(wrappedValue: PlayersViewModel(viewContext: PersistenceController.shared.container.viewContext))
        
        // Initialize state with player data if editing
        if let player = player {
            self._name = State(initialValue: player.name ?? "")
            self._selectedColor = State(initialValue: Theme.TeamColors.color(from: player.playerColor))
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
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: Theme.Spacing.sm) {
                        ForEach(Constants.Defaults.playerColors, id: \.self) { color in
                            Button(action: {
                                selectedColor = color
                            }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColor == color ? Theme.Colors.primary : Color.clear, lineWidth: 3)
                                    )
                            }
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
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