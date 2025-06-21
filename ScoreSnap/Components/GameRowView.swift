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
    let isCompact: Bool
    
    init(game: Game, isCompact: Bool = false, onTap: @escaping () -> Void) {
        self.game = game
        self.isCompact = isCompact
        self.onTap = onTap
    }
    
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
    
    private var compactDateText: String {
        guard let gameDate = game.gameDate else { return "" }
        
        if gameDate.isToday {
            return "Today"
        } else if Calendar.current.isDateInYesterday(gameDate) {
            return "Yesterday"
        } else if gameDate.isThisWeek {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Day of week
            return formatter.string(from: gameDate)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: gameDate)
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: isCompact ? Theme.Spacing.xs : Theme.Spacing.sm) {
                // Compact Game Result Indicator
                Text(resultText)
                    .font(isCompact ? .caption2 : Theme.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: isCompact ? 18 : 20, height: isCompact ? 18 : 20)
                    .background(resultColor)
                    .clipShape(Circle())
                
                // Game Details - Single Line Layout
                HStack {
                    // Opponent and Score
                    Text("vs \(game.opponentName ?? "Unknown")")
                        .font(isCompact ? Theme.Typography.caption : Theme.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.Colors.primaryText)
                        .lineLimit(1)
                    
                    Spacer(minLength: Theme.Spacing.xs)
                    
                    // Score
                    Text("\(game.teamScore) - \(game.opponentScore)")
                        .font(isCompact ? Theme.Typography.callout : Theme.Typography.scoreDisplay)
                        .foregroundColor(Theme.Colors.primaryText)
                        .fontWeight(.semibold)
                    
                    Spacer(minLength: Theme.Spacing.xs)
                    
                    // Compact Date
                    Text(compactDateText)
                        .font(.caption2)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .lineLimit(1)
                }
                
                // Chevron
                if !isCompact {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
            .padding(isCompact ? Theme.Spacing.xs : Theme.Spacing.sm)
            .background(isCompact ? Color.clear : Theme.Colors.cardBackground)
            .cornerRadius(isCompact ? 0 : Theme.CornerRadius.sm)
        }
        .buttonStyle(PlainButtonStyle())
    }
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
            
            // Today's game
            GameRowView(game: sampleTodayGame) {
                print("Today's game tapped")
            }
            
            // Yesterday's game
            GameRowView(game: sampleYesterdayGame) {
                print("Yesterday's game tapped")
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
    
    static var sampleTodayGame: Game {
        let context = PersistenceController.preview.container.viewContext
        let game = Game(context: context)
        game.id = UUID()
        game.opponentName = "Heat"
        game.teamScore = 88
        game.opponentScore = 82
        game.isWin = true
        game.isTie = false
        game.gameDate = Date() // Today
        return game
    }
    
    static var sampleYesterdayGame: Game {
        let context = PersistenceController.preview.container.viewContext
        let game = Game(context: context)
        game.id = UUID()
        game.opponentName = "Nets"
        game.teamScore = 91
        game.opponentScore = 87
        game.isWin = true
        game.isTie = false
        game.gameDate = Date().addingTimeInterval(-86400) // Yesterday
        return game
    }
}

#Preview {
    GameRowView_Previews.previews
} 