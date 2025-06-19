//
//  MainTabView.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appContext: AppContext
    @State private var selectedTab = 0
    @State private var showingUploadView = false
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Image(systemName: Constants.TabBar.homeIcon)
                        Text(Constants.TabBar.homeTitle)
                    }
                    .tag(0)
                
                GamesView()
                    .tabItem {
                        Image(systemName: Constants.TabBar.gamesIcon)
                        Text(Constants.TabBar.gamesTitle)
                    }
                    .tag(1)
                
                PlayersView()
                    .tabItem {
                        Image(systemName: Constants.TabBar.playersIcon)
                        Text(Constants.TabBar.playersTitle)
                    }
                    .tag(2)
            }
            .accentColor(Theme.Colors.primary)
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    FloatingActionButton(
                        showingUploadView: $showingUploadView
                    )
                    .padding(.trailing, Theme.Spacing.md)
                    .padding(.bottom, 100) // Above tab bar
                }
            }
        }
        .sheet(isPresented: $showingUploadView) {
            UploadView()
        }
    }
}

struct FloatingActionButton: View {
    @Binding var showingUploadView: Bool
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            showingUploadView = true
        }) {
            Image(systemName: Constants.TabBar.cameraIcon)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .fabStyle()
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(Theme.Animation.quick) {
                    isPressed = pressing
                }
            },
            perform: {
                // Long press action - same as tap for now
                showingUploadView = true
            }
        )
    }
}

// MARK: - Placeholder Views

// HomeView is now implemented in Views/Home/HomeView.swift
// PlayersView is now implemented in Views/Players/PlayersView.swift

struct GamesView: View {
    @EnvironmentObject var appContext: AppContext
    
    var body: some View {
        NavigationView {
            VStack {
                if appContext.needsSetup {
                    SetupPlaceholderView()
                } else {
                    Text("Games View - Coming Soon")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                Spacer()
            }
            .navigationTitle(Constants.TabBar.gamesTitle)
            .background(Theme.Colors.background)
        }
    }
}

// MARK: - Helper Views

// SetupPlaceholderView is now implemented in Views/Home/HomeView.swift

struct PlayerTeamHeaderView: View {
    let player: Player
    let team: Team?
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(player.name ?? "Unknown Player")
                .font(Theme.Typography.title2)
            
            if let team = team {
                HStack {
                    Circle()
                        .fill(Theme.TeamColors.color(from: team.teamColor))
                        .frame(width: 12, height: 12)
                    
                    Text(team.name ?? "Unknown Team")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }
}

struct TeamRecordCardView: View {
    let team: Team
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Team Record")
                .font(Theme.Typography.headline)
            
            // TODO: Calculate actual record from games
            HStack(spacing: Theme.Spacing.lg) {
                RecordStatView(title: "Wins", value: "0", color: Theme.Colors.primaryText)
                RecordStatView(title: "Losses", value: "0", color: Theme.Colors.primaryText)
                RecordStatView(title: "Ties", value: "0", color: Theme.Colors.primaryText)
            }
        }
        .padding(Theme.Spacing.md)
        .cardStyle()
        .padding(.horizontal, Theme.Spacing.md)
    }
}

struct RecordStatView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(value)
                .font(Theme.Typography.recordDisplay)
                .foregroundColor(color)
            
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppContext(viewContext: PersistenceController.preview.container.viewContext))
} 