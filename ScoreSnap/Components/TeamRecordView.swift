//
//  TeamRecordView.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI
import CoreData

struct TeamRecordView: View {
    let team: Team
    
    @FetchRequest
    private var games: FetchedResults<Game>
    
    init(team: Team) {
        self.team = team
        self._games = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Game.gameDate, ascending: false)],
            predicate: NSPredicate(format: "team == %@", team),
            animation: .default
        )
    }
    
    private var record: (wins: Int, losses: Int, ties: Int) {
        let wins = games.filter { $0.isWin }.count
        let losses = games.filter { !$0.isWin && !$0.isTie }.count
        let ties = games.filter { $0.isTie }.count
        return (wins, losses, ties)
    }
    
    private var winPercentage: Double {
        let totalGames = games.count
        guard totalGames > 0 else { return 0.0 }
        let wins = record.wins
        let ties = record.ties
        // Ties count as half wins for win percentage
        return Double(wins) + (Double(ties) * 0.5) / Double(totalGames)
    }
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Text("Team Record")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Spacer()
                
                if games.count > 0 {
                    Text("\(Int(winPercentage * 100))%")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
            
            if games.isEmpty {
                EmptyRecordView()
            } else {
                RecordStatsView(record: record, totalGames: games.count)
            }
        }
        .padding(Theme.Spacing.md)
        .cardStyle()
    }
}

struct EmptyRecordView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "chart.bar.fill")
                .font(.title2)
                .foregroundColor(Theme.Colors.secondaryText)
            
            Text("No Games Played")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
            
            Text("Start tracking games to see your team's record")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Theme.Spacing.sm)
    }
}

struct RecordStatsView: View {
    let record: (wins: Int, losses: Int, ties: Int)
    let totalGames: Int
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Main W-L-T Display
            HStack(spacing: Theme.Spacing.lg) {
                RecordStatItem(
                    label: "W",
                    value: record.wins,
                    color: Theme.Colors.win
                )
                
                Text("-")
                    .font(Theme.Typography.recordDisplay)
                    .foregroundColor(Theme.Colors.secondaryText)
                
                RecordStatItem(
                    label: "L",
                    value: record.losses,
                    color: Theme.Colors.loss
                )
                
                if record.ties > 0 {
                    Text("-")
                        .font(Theme.Typography.recordDisplay)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    RecordStatItem(
                        label: "T",
                        value: record.ties,
                        color: Theme.Colors.tie
                    )
                }
            }
            
            // Games Played
            Text("Games Played: \(totalGames)")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
            
            // Visual Progress Bar
            RecordProgressBar(record: record, totalGames: totalGames)
        }
    }
}

struct RecordStatItem: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(color)
                .fontWeight(.semibold)
            
            Text("\(value)")
                .font(Theme.Typography.recordDisplay)
                .foregroundColor(Theme.Colors.primaryText)
        }
    }
}

struct RecordProgressBar: View {
    let record: (wins: Int, losses: Int, ties: Int)
    let totalGames: Int
    
    private var winPercentage: Double {
        guard totalGames > 0 else { return 0.0 }
        return Double(record.wins) / Double(totalGames)
    }
    
    private var lossPercentage: Double {
        guard totalGames > 0 else { return 0.0 }
        return Double(record.losses) / Double(totalGames)
    }
    
    private var tiePercentage: Double {
        guard totalGames > 0 else { return 0.0 }
        return Double(record.ties) / Double(totalGames)
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Wins
                Rectangle()
                    .fill(Theme.Colors.win)
                    .frame(width: geometry.size.width * winPercentage)
                
                // Ties
                if record.ties > 0 {
                    Rectangle()
                        .fill(Theme.Colors.tie)
                        .frame(width: geometry.size.width * tiePercentage)
                }
                
                // Losses
                Rectangle()
                    .fill(Theme.Colors.loss)
                    .frame(width: geometry.size.width * lossPercentage)
            }
        }
        .frame(height: 6)
        .cornerRadius(3)
        .background(Theme.Colors.divider)
    }
}

#Preview {
    TeamRecordView(team: Team())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .padding()
} 