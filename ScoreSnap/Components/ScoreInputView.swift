//
//  ScoreInputView.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI

struct ScoreInputView: View {
    @Binding var teamScore: Int
    @Binding var opponentScore: Int
    let gameResult: GameResult
    let onScoreChange: () -> Void
    
    @State private var teamScoreText: String = ""
    @State private var opponentScoreText: String = ""
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Score")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
            
            HStack(spacing: Theme.Spacing.lg) {
                // Team Score
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Your Team")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    TextField("0", text: $teamScoreText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: teamScoreText) { _, newValue in
                            updateTeamScore(newValue)
                        }
                        .onAppear {
                            teamScoreText = String(teamScore)
                        }
                }
                
                // VS Label
                VStack {
                    Spacer()
                    Text("vs")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .padding(.top, Theme.Spacing.lg)
                }
                
                // Opponent Score
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Opponent")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    TextField("0", text: $opponentScoreText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: opponentScoreText) { _, newValue in
                            updateOpponentScore(newValue)
                        }
                        .onAppear {
                            opponentScoreText = String(opponentScore)
                        }
                }
            }
            
            // Smart Score Suggestions
            if gameResult != .tie {
                SmartScoreSuggestions(
                    gameResult: gameResult,
                    onSuggestionTapped: { suggestedTeam, suggestedOpponent in
                        teamScore = suggestedTeam
                        opponentScore = suggestedOpponent
                        teamScoreText = String(suggestedTeam)
                        opponentScoreText = String(suggestedOpponent)
                        onScoreChange()
                    }
                )
            }
        }
        .alert("Invalid Score", isPresented: $showingValidationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(validationMessage)
        }
    }
    
    private func updateTeamScore(_ text: String) {
        guard let score = Int(text) else {
            teamScore = 0
            return
        }
        
        if validateScore(score) {
            teamScore = score
            onScoreChange()
        } else {
            validationMessage = "Team score must be between 0 and 200"
            showingValidationAlert = true
            // Reset to previous valid value
            teamScoreText = String(teamScore)
        }
    }
    
    private func updateOpponentScore(_ text: String) {
        guard let score = Int(text) else {
            opponentScore = 0
            return
        }
        
        if validateScore(score) {
            opponentScore = score
            onScoreChange()
        } else {
            validationMessage = "Opponent score must be between 0 and 200"
            showingValidationAlert = true
            // Reset to previous valid value
            opponentScoreText = String(opponentScore)
        }
    }
    
    private func validateScore(_ score: Int) -> Bool {
        return score >= Constants.Basketball.minScore && score <= Constants.Basketball.maxReasonableScore
    }
}

struct SmartScoreSuggestions: View {
    let gameResult: GameResult
    let onSuggestionTapped: (Int, Int) -> Void
    
    private var suggestions: [(team: Int, opponent: Int, label: String)] {
        switch gameResult {
        case .win:
            return [
                (85, 78, "Close Win"),
                (95, 82, "Solid Win"),
                (105, 75, "Big Win")
            ]
        case .loss:
            return [
                (78, 85, "Close Loss"),
                (82, 95, "Solid Loss"),
                (75, 105, "Big Loss")
            ]
        case .tie:
            return []
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Quick Suggestions")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
            
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(suggestions, id: \.label) { suggestion in
                    Button(action: {
                        onSuggestionTapped(suggestion.team, suggestion.opponent)
                    }) {
                        VStack(spacing: 2) {
                            Text("\(suggestion.team)-\(suggestion.opponent)")
                                .font(Theme.Typography.caption)
                                .fontWeight(.medium)
                            
                            Text(suggestion.label)
                                .font(Theme.Typography.caption2)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                .fill(Theme.Colors.secondaryBackground)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.lg) {
        ScoreInputView(
            teamScore: .constant(85),
            opponentScore: .constant(78),
            gameResult: .win
        ) {
            print("Score changed")
        }
        
        ScoreInputView(
            teamScore: .constant(75),
            opponentScore: .constant(82),
            gameResult: .loss
        ) {
            print("Score changed")
        }
    }
    .padding()
} 