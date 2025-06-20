//
//  HomeView.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI
import CoreData

struct HomeView: View {
    @EnvironmentObject var appContext: AppContext
    @Environment(\.managedObjectContext) private var viewContext
    
    @StateObject private var viewModel: HomeViewModel
    @State private var showingGameEdit = false
    @State private var selectedGame: Game?
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    
    init() {
        // We'll initialize with a placeholder context, but it will be replaced by the environment
        self._viewModel = StateObject(wrappedValue: HomeViewModel(viewContext: PersistenceController.shared.container.viewContext))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()
                
                if appContext.needsSetup {
                    SetupPlaceholderView()
                } else {
                    HomeContentView(viewModel: viewModel)
                }
            }
            .navigationTitle(Constants.TabBar.homeTitle)
            .onAppear {
                viewModel.refreshData(for: appContext.currentTeam)
            }
            .onChange(of: appContext.currentTeam) { _, newTeam in
                viewModel.refreshData(for: newTeam)
            }
            .sheet(isPresented: $showingGameEdit) {
                if let game = selectedGame {
                    GameEditView(game: game) {
                        // Refresh data after game edit
                        viewModel.refreshData(for: appContext.currentTeam)
                    }
                }
            }
            .alert("Validation Error", isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
        }
    }
}

struct HomeContentView: View {
    @EnvironmentObject var appContext: AppContext
    @ObservedObject var viewModel: HomeViewModel
    @State private var selectedGame: Game?
    @State private var showingGameEdit = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Player Selection Header
                if !appContext.needsSetup {
                    PlayerTeamSelectionView()
                }
                
                // Team Record Card
                if let currentTeam = appContext.currentTeam {
                    TeamRecordView(team: currentTeam)
                        .padding(.horizontal, Theme.Spacing.md)
                }
                
                // Recent Games Section
                RecentGamesSection(
                    viewModel: viewModel,
                    onGameTap: { game in
                        selectedGame = game
                        showingGameEdit = true
                    }
                )
            }
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xxl) // Extra space for FAB
        }
        .refreshable {
            viewModel.refreshData(for: appContext.currentTeam)
        }
        .sheet(isPresented: $showingGameEdit) {
            if let game = selectedGame {
                GameEditView(game: game) {
                    // Refresh data after game edit
                    viewModel.refreshData(for: appContext.currentTeam)
                }
            }
        }
    }
}

struct PlayerTeamSelectionView: View {
    @EnvironmentObject var appContext: AppContext
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Player Segmented Control
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Player")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                
                PlayerSegmentedControl()
                    .padding(.horizontal, Theme.Spacing.md)
            }
            
            // Team Dropdown
            if let currentPlayer = appContext.currentPlayer {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Team")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .padding(.horizontal, Theme.Spacing.md)
                    
                    TeamDropdown(player: currentPlayer)
                        .padding(.horizontal, Theme.Spacing.md)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.lg)
        .padding(.horizontal, Theme.Spacing.md)
        .cardStyle()
    }
}

struct RecentGamesSection: View {
    @ObservedObject var viewModel: HomeViewModel
    let onGameTap: (Game) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Section Header
            HStack {
                Text("Recent Games")
                    .font(Theme.Typography.title3)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Spacer()
                
                if !viewModel.recentGames.isEmpty {
                    Button("View All") {
                        // TODO: Navigate to Games tab
                        print("View all games tapped")
                    }
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.primary)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            
            // Games List or Empty State
            if viewModel.isLoading {
                LoadingGamesView()
            } else if viewModel.recentGames.isEmpty {
                EmptyGamesView()
            } else {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(viewModel.recentGames, id: \.id) { game in
                        GameRowView(game: game) {
                            onGameTap(game)
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }
                }
            }
            
            // Error Message
            if let errorMessage = viewModel.errorMessage {
                ErrorMessageView(message: errorMessage)
                    .padding(.horizontal, Theme.Spacing.md)
            }
        }
    }
}

struct LoadingGamesView: View {
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

struct EmptyGamesView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "sportscourt.fill")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.secondaryText)
            
            Text("No Games Yet")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.primaryText)
            
            Text("Start tracking your team's games by tapping the camera button")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)
            
            Button("Add First Game") {
                // TODO: Trigger camera action
                print("Add first game tapped")
            }
            .primaryButtonStyle()
            .padding(.top, Theme.Spacing.sm)
        }
        .padding(.vertical, Theme.Spacing.xl)
        .padding(.horizontal, Theme.Spacing.md)
    }
}

struct ErrorMessageView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Theme.Colors.error)
            
            Text(message)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.error)
            
            Spacer()
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.error.opacity(0.1))
        .cornerRadius(Theme.CornerRadius.sm)
    }
}

// MARK: - Placeholder Views

struct SetupPlaceholderView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(Theme.Colors.primary)
            
            Text("Welcome to ScoreSnap!")
                .font(Theme.Typography.title1)
                .foregroundColor(Theme.Colors.primaryText)
            
            Text("Let's get you set up by creating your first player and team")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)
            
            Button("Get Started") {
                // TODO: Navigate to setup flow
                print("Get Started tapped")
            }
            .primaryButtonStyle()
        }
        .padding(Theme.Spacing.xl)
    }
}

// GameEditView is now implemented in Views/Games/GameEditView.swift

#Preview {
    HomeView()
        .environmentObject(AppContext(viewContext: PersistenceController.preview.container.viewContext))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 