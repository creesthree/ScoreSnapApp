//
//  GameRowView.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI
import CoreData

struct GameRowView: View {
    let game: Game
    let onTap: () -> Void
    
    private var gameResult: GameResult {
        if game.isTie {
            return .tie
        } else if game.isWin {
            return .win
        } else {
            return .loss
        }
    }
    
    private var resultColor: Color {
        switch gameResult {
        case .win: return Theme.Colors.win
        case .loss: return Theme.Colors.loss
        case .tie: return Theme.Colors.tie
        }
    }
    
    private var resultText: String {
        switch gameResult {
        case .win: return "W"
        case .loss: return "L"
        case .tie: return "T"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                // Game Result Indicator
                VStack {
                    Text(resultText)
                        .font(Theme.Typography.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(resultColor)
                        .clipShape(Circle())
                    
                    Spacer()
                }
                
                // Game Details
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack {
                        Text("vs \(game.opponentName ?? "Unknown")")
                            .font(Theme.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.Colors.primaryText)
                        
                        Spacer()
                        
                        // Score
                        Text("\(game.teamScore) - \(game.opponentScore)")
                            .font(Theme.Typography.scoreDisplay)
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                    
                    HStack {
                        // Date
                        if let gameDate = game.gameDate {
                            Text(gameDate.gameDisplayFormat)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                        
                        Spacer()
                        
                        // Location (if available)
                        if let location = game.gameLocation, !location.isEmpty {
                            Text(location)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

enum GameResult {
    case win, loss, tie
}

struct GameRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Win example
            GameRowView(game: sampleWinGame) {
                print("Win game tapped")
            }
            
            // Loss example
            GameRowView(game: sampleLossGame) {
                print("Loss game tapped")
            }
            
            // Tie example
            GameRowView(game: sampleTieGame) {
                print("Tie game tapped")
            }
        }
        .padding()
        .background(Theme.Colors.background)
    }
    
    static var sampleWinGame: Game {
        let context = PersistenceController.preview.container.viewContext
        let game = Game(context: context)
        game.id = UUID()
        game.opponentName = "Lakers"
        game.teamScore = 85
        game.opponentScore = 78
        game.isWin = true
        game.isTie = false
        game.gameDate = Date().addingTimeInterval(-86400) // Yesterday
        game.gameLocation = "Home Court"
        return game
    }
    
    static var sampleLossGame: Game {
        let context = PersistenceController.preview.container.viewContext
        let game = Game(context: context)
        game.id = UUID()
        game.opponentName = "Warriors"
        game.teamScore = 72
        game.opponentScore = 89
        game.isWin = false
        game.isTie = false
        game.gameDate = Date().addingTimeInterval(-172800) // 2 days ago
        game.gameLocation = "Away"
        return game
    }
    
    static var sampleTieGame: Game {
        let context = PersistenceController.preview.container.viewContext
        let game = Game(context: context)
        game.id = UUID()
        game.opponentName = "Celtics"
        game.teamScore = 95
        game.opponentScore = 95
        game.isWin = false
        game.isTie = true
        game.gameDate = Date().addingTimeInterval(-259200) // 3 days ago
        return game
    }
}

#Preview {
    GameRowView_Previews.previews
} 