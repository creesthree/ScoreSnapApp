//
//  WinLossTieSelector.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI

struct WinLossTieSelector: View {
    @Binding var selectedResult: GameResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Game Result")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
            
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(GameResult.allCases, id: \.self) { result in
                    ResultButton(
                        result: result,
                        isSelected: selectedResult == result
                    ) {
                        selectedResult = result
                    }
                }
            }
        }
    }
}

struct ResultButton: View {
    let result: GameResult
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: result.iconName)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text(result.displayText)
                    .font(Theme.Typography.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : result.color)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(isSelected ? result.color : result.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .stroke(result.color, lineWidth: isSelected ? 0 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(Theme.Animation.quick, value: isSelected)
    }
}

enum GameResult: CaseIterable {
    case win, loss, tie
    
    var displayText: String {
        switch self {
        case .win: return "Win"
        case .loss: return "Loss"
        case .tie: return "Tie"
        }
    }
    
    var iconName: String {
        switch self {
        case .win: return "checkmark.circle.fill"
        case .loss: return "xmark.circle.fill"
        case .tie: return "minus.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .win: return Theme.Colors.win
        case .loss: return Theme.Colors.loss
        case .tie: return Theme.Colors.tie
        }
    }
    
    var isWin: Bool {
        self == .win
    }
    
    var isTie: Bool {
        self == .tie
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.lg) {
        WinLossTieSelector(selectedResult: .constant(.win))
        WinLossTieSelector(selectedResult: .constant(.loss))
        WinLossTieSelector(selectedResult: .constant(.tie))
    }
    .padding()
} 