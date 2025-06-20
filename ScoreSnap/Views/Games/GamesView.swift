//
//  GamesView.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/20/25.
//

import SwiftUI
import CoreData

struct GamesView: View {
    @EnvironmentObject var appContext: AppContext
    @Environment(\.managedObjectContext) private var viewContext
    
    @StateObject private var viewModel: GamesViewModel
    @State private var showingGameEdit = false
    @State private var selectedGame: Game?
    @State private var expandedTeams: Set<UUID> = []
    
    init() {
        self._viewModel = StateObject(wrappedValue: GamesViewModel(viewContext: PersistenceController.shared.container.viewContext))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()
                
                if appContext.needsSetup {
                    SetupPlaceholderView()
                } else if let currentPlayer = appContext.currentPlayer {
                    GamesContentView(
                        viewModel: viewModel,
                        currentPlayer: currentPlayer,
                        expandedTeams: $expandedTeams,
                        onGameTap: { game in
                            selectedGame = game
                            showingGameEdit = true
                        }
                    )
                } else {
                    NoPlayerSelectedView()
                }
            }
            .navigationTitle(Constants.TabBar.gamesTitle)
            .onAppear {
                if let player = appContext.currentPlayer {
                    viewModel.loadData(for: player)
                }
            }
            .onChange(of: appContext.currentPlayer) { _, newPlayer in
                if let player = newPlayer {
                    viewModel.loadData(for: player)
                    expandedTeams.removeAll()
                }
            }
            .sheet(isPresented: $showingGameEdit) {
                if let game = selectedGame {
                    GameEditView(game: game) {
                        // Refresh data after game edit
                        if let player = appContext.currentPlayer {
                            viewModel.loadData(for: player)
                        }
                    }
                }
            }
        }
    }
}

struct GamesContentView: View {
    @EnvironmentObject var appContext: AppContext
    @ObservedObject var viewModel: GamesViewModel
    let currentPlayer: Player
    @Binding var expandedTeams: Set<UUID>
    let onGameTap: (Game) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Player Selection Header
                PlayerTeamSelectionView()
                
                // Teams and Games List
                if viewModel.isLoading {
                    LoadingView()
                } else if viewModel.teams.isEmpty {
                    EmptyTeamsView()
                } else {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        ForEach(viewModel.teams, id: \.id) { team in
                            TeamGamesSection(
                                team: team,
                                games: viewModel.games[team.id ?? UUID()] ?? [],
                                isExpanded: expandedTeams.contains(team.id ?? UUID()),
                                onToggleExpanded: {
                                    toggleTeamExpansion(team)
                                },
                                onGameTap: onGameTap
                            )
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                }
                
                // Error Message
                if let errorMessage = viewModel.errorMessage {
                    ErrorMessageView(message: errorMessage)
                        .padding(.horizontal, Theme.Spacing.md)
                }
            }
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xxl) // Extra space for FAB
        }
        .refreshable {
            viewModel.loadData(for: currentPlayer)
        }
    }
    
    private func toggleTeamExpansion(_ team: Team) {
        guard let teamId = team.id else { return }
        
        if expandedTeams.contains(teamId) {
            expandedTeams.remove(teamId)
        } else {
            expandedTeams.insert(teamId)
        }
    }
}

struct TeamGamesSection: View {
    let team: Team
    let games: [Game]
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onGameTap: (Game) -> Void
    
    private var teamRecord: (wins: Int, losses: Int, ties: Int) {
        let wins = games.filter { $0.isWin }.count
        let losses = games.filter { !$0.isWin && !$0.isTie }.count
        let ties = games.filter { $0.isTie }.count
        return (wins, losses, ties)
    }
    
    private var winPercentage: Double {
        guard !games.isEmpty else { return 0.0 }
        let adjustedWins = Double(teamRecord.wins) + (Double(teamRecord.ties) * 0.5)
        return adjustedWins / Double(games.count)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Team Header
            Button(action: onToggleExpanded) {
                VStack(spacing: Theme.Spacing.sm) {
                    HStack {
                        // Team Color Indicator
                        Circle()
                            .fill(Theme.TeamColors.color(from: team.teamColor))
                            .frame(width: 16, height: 16)
                        
                        // Team Name
                        Text(team.name ?? "Unknown Team")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.primaryText)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        // Games Count
                        Text("\(games.count) games")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                        
                        // Expand/Collapse Icon
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    
                    // Team Record Summary
                    HStack {
                        // W-L-T Record
                        Text("\(teamRecord.wins)-\(teamRecord.losses)-\(teamRecord.ties)")
                            .font(Theme.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.Colors.primaryText)
                        
                        Spacer()
                        
                        // Win Percentage
                        if !games.isEmpty {
                            Text("\(Int(winPercentage * 100))%")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.cardBackground)
                .cornerRadius(Theme.CornerRadius.md)
                .cardStyle()
            }
            .buttonStyle(PlainButtonStyle())
            
            // Games List (Expandable)
            if isExpanded {
                VStack(spacing: Theme.Spacing.sm) {
                    if games.isEmpty {
                        EmptyGamesForTeamView(team: team)
                            .padding(.top, Theme.Spacing.sm)
                    } else {
                        ForEach(games, id: \.id) { game in
                            GameRowView(game: game) {
                                onGameTap(game)
                            }
                        }
                        .padding(.top, Theme.Spacing.sm)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: isExpanded)
            }
        }
    }
}

struct EmptyGamesForTeamView: View {
    let team: Team
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "sportscourt")
                .font(.title3)
                .foregroundColor(Theme.Colors.secondaryText)
            
            Text("No games for \(team.name ?? "this team")")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
            
            Text("Start adding games to track this team's performance")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Theme.Spacing.md)
        .padding(.horizontal, Theme.Spacing.lg)
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.sm)
    }
}

struct NoPlayerSelectedView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 64))
                .foregroundColor(Theme.Colors.secondaryText)
            
            Text("No Player Selected")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.primaryText)
            
            Text("Please select a player from the Players tab to view games")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)
        }
        .padding(Theme.Spacing.xl)
    }
}

struct EmptyTeamsView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 64))
                .foregroundColor(Theme.Colors.secondaryText)
            
            Text("No Teams Yet")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.primaryText)
            
            Text("Create your first team in the Players tab to start tracking games")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)
        }
        .padding(Theme.Spacing.xl)
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            
            Text("Loading games...")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .padding(.vertical, Theme.Spacing.xl)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    return GamesView()
        .environmentObject(AppContext(viewContext: context))
        .environment(\.managedObjectContext, context)
} 