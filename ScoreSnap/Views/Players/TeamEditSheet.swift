//
//  TeamEditSheet.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI

struct TeamEditSheet: View {
    let team: Team?
    let player: Player
    let onSave: (String, Color, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selectedColor: Color = Constants.Defaults.defaultTeamColor
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    
    @StateObject private var viewModel: PlayersViewModel
    
    init(team: Team?, player: Player, onSave: @escaping (String, Color, String) -> Void) {
        self.team = team
        self.player = player
        self.onSave = onSave
        self._viewModel = StateObject(wrappedValue: PlayersViewModel(viewContext: PersistenceController.shared.container.viewContext))
        
        // Initialize state with team data if editing
        if let team = team {
            self._name = State(initialValue: team.name ?? "")
            self._selectedColor = State(initialValue: Theme.TeamColors.color(from: team.teamColor))
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Team Details") {
                    // Player info
                    HStack {
                        Circle()
                            .fill(viewModel.getPlayerColor(player))
                            .frame(width: 20, height: 20)
                        
                        Text("Player: \(player.name ?? "Unknown")")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                    
                    TextField("Team Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Team Color")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                        
                        ColorPicker("Select Color", selection: $selectedColor, supportsOpacity: false)
                            .labelsHidden()
                        
                        // Color preview
                        HStack {
                            Circle()
                                .fill(selectedColor)
                                .frame(width: 30, height: 30)
                            
                            Text("Preview")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                            
                            Spacer()
                        }
                    }
                }
                
                Section("Available Colors") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: Theme.Spacing.sm) {
                        ForEach(Constants.Defaults.teamColors, id: \.self) { color in
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
            .navigationTitle(team == nil ? "Add Team" : "Edit Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTeam()
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
    
    private func saveTeam() {
        let trimmedName = name.trimmed
        
        // Validate name using the same logic as PlayersViewModel
        guard viewModel.validateTeamName(trimmedName) else {
            validationMessage = "Team name must be between 1 and 50 characters."
            showingValidationAlert = true
            return
        }
        
        // Check for duplicate names within the same player using the same logic as PlayersViewModel
        guard viewModel.isTeamNameUnique(trimmedName, for: player, excluding: team) else {
            validationMessage = "A team with this name already exists for this player."
            showingValidationAlert = true
            return
        }
        
        // Save the team, always use 'Basketball' as sport
        onSave(trimmedName, selectedColor, "Basketball")
        dismiss()
    }
}

#Preview {
    let player = Player()
    player.name = "Sample Player"
    player.playerColor = "#FF0000"
    
    return TeamEditSheet(team: nil, player: player) { name, color, sport in
        print("Creating team: \(name)")
    }
} 