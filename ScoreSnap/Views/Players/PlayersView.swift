//
//  PlayersView.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI
import CoreData

struct PlayersView: View {
    @EnvironmentObject var appContext: AppContext
    @Environment(\.managedObjectContext) private var viewContext
    
    @StateObject private var viewModel: PlayersViewModel
    @State private var showingAddPlayer = false
    @State private var showingAddTeam = false
    @State private var selectedPlayerForTeam: Player?
    @State private var editingPlayer: Player?
    @State private var editingTeam: Team?
    @State private var showingDeleteConfirmation = false
    @State private var itemToDelete: Any?
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    
    init() {
        self._viewModel = StateObject(wrappedValue: PlayersViewModel(viewContext: PersistenceController.shared.container.viewContext))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()
                
                if appContext.needsSetup {
                    SetupPlaceholderView()
                } else {
                    PlayersContentView()
                }
            }
            .navigationTitle(Constants.TabBar.playersTitle)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                        .onTapGesture {
                            withAnimation(Theme.Animation.standard) {
                                viewModel.isEditMode.toggle()
                            }
                        }
                }
            }
            .sheet(isPresented: $showingAddPlayer) {
                PlayerEditSheet(
                    player: nil,
                    onSave: { name, color, sport in
                        // Validate before creating
                        if !viewModel.validatePlayerName(name) {
                            validationMessage = "Player name must be between 1 and 50 characters."
                            showingValidationAlert = true
                            return
                        }
                        if !viewModel.isPlayerNameUnique(name) {
                            validationMessage = "A player with this name already exists."
                            showingValidationAlert = true
                            return
                        }
                        viewModel.createPlayer(name: name, color: color, sport: sport)
                    }
                )
            }
            .sheet(isPresented: $showingAddTeam) {
                if let player = selectedPlayerForTeam {
                    TeamEditSheet(
                        team: nil,
                        player: player,
                        onSave: { name, color, sport in
                            // Validate before creating
                            if !viewModel.validateTeamName(name) {
                                validationMessage = "Team name must be between 1 and 50 characters."
                                showingValidationAlert = true
                                return
                            }
                            if !viewModel.isTeamNameUnique(name, for: player) {
                                validationMessage = "A team with this name already exists for this player."
                                showingValidationAlert = true
                                return
                            }
                            viewModel.createTeam(name: name, color: color, player: player, sport: sport)
                        }
                    )
                }
            }
            .sheet(item: $editingPlayer) { player in
                PlayerEditSheet(
                    player: player,
                    onSave: { name, color, sport in
                        // Validate before updating
                        if !viewModel.validatePlayerName(name) {
                            validationMessage = "Player name must be between 1 and 50 characters."
                            showingValidationAlert = true
                            return
                        }
                        if !viewModel.isPlayerNameUnique(name, excluding: player) {
                            validationMessage = "A player with this name already exists."
                            showingValidationAlert = true
                            return
                        }
                        viewModel.updatePlayer(player, name: name, color: color, sport: sport)
                    }
                )
            }
            .sheet(item: $editingTeam) { team in
                TeamEditSheet(
                    team: team,
                    player: team.player!,
                    onSave: { name, color, sport in
                        // Validate before updating
                        if !viewModel.validateTeamName(name) {
                            validationMessage = "Team name must be between 1 and 50 characters."
                            showingValidationAlert = true
                            return
                        }
                        if !viewModel.isTeamNameUnique(name, for: team.player!, excluding: team) {
                            validationMessage = "A team with this name already exists for this player."
                            showingValidationAlert = true
                            return
                        }
                        viewModel.updateTeam(team, name: name, color: color, sport: sport)
                    }
                )
            }
            .alert("Delete Confirmation", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    performDelete()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(deleteConfirmationMessage)
            }
            .alert("Validation Error", isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
        }
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private func PlayersContentView() -> some View {
        if viewModel.isLoading {
            LoadingView()
        } else if viewModel.players.isEmpty {
            EmptyStateView()
        } else {
            List {
                // Players Section
                Section("Players") {
                    ForEach(viewModel.players, id: \.id) { player in
                        PlayerRowView(
                            player: player,
                            isSelected: appContext.currentPlayer?.id == player.id,
                            isEditMode: viewModel.isEditMode,
                            onTap: {
                                appContext.switchToPlayer(player)
                            },
                            onEdit: {
                                editingPlayer = player
                            },
                            onDelete: {
                                itemToDelete = player
                                showingDeleteConfirmation = true
                            }
                        )
                    }
                    .onMove(perform: viewModel.movePlayer)
                    
                    // Add Player Button
                    Button(action: {
                        showingAddPlayer = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Theme.Colors.primary)
                            Text("Add Player")
                                .foregroundColor(Theme.Colors.primary)
                        }
                    }
                    .disabled(viewModel.isEditMode)
                }
                
                // Teams Section
                Section("Teams") {
                    ForEach(viewModel.players, id: \.id) { player in
                        let playerTeams = viewModel.teamsForPlayer(player)
                        if !playerTeams.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                // Player Header
                                HStack {
                                    Circle()
                                        .fill(viewModel.getPlayerColor(player))
                                        .frame(width: 12, height: 12)
                                    
                                    Text(player.name ?? "Unknown Player")
                                        .font(Theme.Typography.headline)
                                        .foregroundColor(Theme.Colors.secondaryText)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, Theme.Spacing.sm)
                                
                                // Teams for this player
                                ForEach(playerTeams, id: \.id) { team in
                                    EditableTeamRowView(
                                        team: team,
                                        isSelected: appContext.currentTeam?.id == team.id,
                                        isEditMode: viewModel.isEditMode,
                                        onTap: {
                                            appContext.switchToPlayerAndTeam(player, team)
                                        },
                                        onEdit: {
                                            editingTeam = team
                                        },
                                        onDelete: {
                                            itemToDelete = team
                                            showingDeleteConfirmation = true
                                        }
                                    )
                                }
                                .onMove { source, destination in
                                    viewModel.moveTeam(from: source, to: destination, for: player)
                                }
                            }
                        }
                    }
                    
                    // Add Team Button
                    Button(action: {
                        if let firstPlayer = viewModel.players.first {
                            selectedPlayerForTeam = firstPlayer
                            showingAddTeam = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Theme.Colors.primary)
                            Text("Add Team")
                                .foregroundColor(Theme.Colors.primary)
                        }
                    }
                    .disabled(viewModel.isEditMode || viewModel.players.isEmpty)
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func LoadingView() -> some View {
        VStack {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading players...")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .padding(.top, Theme.Spacing.md)
        }
    }
    
    @ViewBuilder
    private func EmptyStateView() -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.secondaryText)
            
            Text("No Players Yet")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.primaryText)
            
            Text("Add your first player to get started")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
            
            Button(action: {
                showingAddPlayer = true
            }) {
                Text("Add Player")
                    .font(Theme.Typography.bodyBold)
                    .foregroundColor(Theme.Colors.buttonText)
                    .frame(height: Constants.UI.standardButtonHeight)
                    .frame(maxWidth: .infinity)
                    .background(Theme.Colors.buttonBackground)
                    .cornerRadius(Theme.CornerRadius.md)
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(Theme.Spacing.xl)
    }
    
    // MARK: - Helper Methods
    
    private var deleteConfirmationMessage: String {
        if let player = itemToDelete as? Player {
            return "Are you sure you want to delete '\(player.name ?? "Unknown Player")'? This will also delete all their teams and games."
        } else if let team = itemToDelete as? Team {
            return "Are you sure you want to delete '\(team.name ?? "Unknown Team")'? This will also delete all their games."
        }
        return "Are you sure you want to delete this item?"
    }
    
    private func performDelete() {
        if let player = itemToDelete as? Player {
            viewModel.deletePlayer(player)
            // Handle AppContext if this was the current player
            if appContext.currentPlayer?.id == player.id {
                appContext.handlePlayerDeletion(player)
            }
        } else if let team = itemToDelete as? Team {
            viewModel.deleteTeam(team)
            // Handle AppContext if this was the current team
            if appContext.currentTeam?.id == team.id {
                appContext.handleTeamDeletion(team)
            }
        }
        itemToDelete = nil
    }
}

// MARK: - Player Row View

struct PlayerRowView: View {
    let player: Player
    let isSelected: Bool
    let isEditMode: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @StateObject private var viewModel: PlayersViewModel
    
    init(player: Player, isSelected: Bool, isEditMode: Bool, onTap: @escaping () -> Void, onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.player = player
        self.isSelected = isSelected
        self.isEditMode = isEditMode
        self.onTap = onTap
        self.onEdit = onEdit
        self.onDelete = onDelete
        self._viewModel = StateObject(wrappedValue: PlayersViewModel(viewContext: PersistenceController.shared.container.viewContext))
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Player color indicator
            Circle()
                .fill(viewModel.getPlayerColor(player))
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name ?? "Unknown Player")
                    .font(Theme.Typography.bodyBold)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Text(player.sport ?? "Basketball")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            
            Spacer()
            
            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.Colors.primary)
                    .font(.body.weight(.semibold))
            }
            
            // Edit/Delete buttons in edit mode
            if isEditMode {
                HStack(spacing: Theme.Spacing.sm) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .foregroundColor(Theme.Colors.primary)
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(Theme.Colors.error)
                    }
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditMode {
                onTap()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .fill(isSelected ? Theme.Colors.primary.opacity(0.1) : Color.clear)
        )
    }
}

// MARK: - Team Row View

struct EditableTeamRowView: View {
    let team: Team
    let isSelected: Bool
    let isEditMode: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @StateObject private var viewModel: PlayersViewModel
    
    init(team: Team, isSelected: Bool, isEditMode: Bool, onTap: @escaping () -> Void, onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.team = team
        self.isSelected = isSelected
        self.isEditMode = isEditMode
        self.onTap = onTap
        self.onEdit = onEdit
        self.onDelete = onDelete
        self._viewModel = StateObject(wrappedValue: PlayersViewModel(viewContext: PersistenceController.shared.container.viewContext))
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Indent for team
            Rectangle()
                .fill(Color.clear)
                .frame(width: 20)
            
            // Team color indicator
            Circle()
                .fill(viewModel.getTeamColor(team))
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
            
            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.Colors.primary)
                    .font(.body.weight(.semibold))
            }
            
            // Edit/Delete buttons in edit mode
            if isEditMode {
                HStack(spacing: Theme.Spacing.sm) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .foregroundColor(Theme.Colors.primary)
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(Theme.Colors.error)
                    }
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditMode {
                onTap()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .fill(isSelected ? Theme.Colors.primary.opacity(0.1) : Color.clear)
        )
    }
}

// MARK: - Setup Placeholder View

// SetupPlaceholderView is now defined in Views/Home/HomeView.swift

#Preview {
    PlayersView()
        .environmentObject(AppContext(viewContext: PersistenceController.preview.container.viewContext))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 