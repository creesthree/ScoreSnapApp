//
//  GameEditView.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/20/25.
//

import SwiftUI
import CoreData

struct GameEditView: View {
    let game: Game
    let onSave: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    // Editable game properties
    @State private var teamScore: Int
    @State private var opponentScore: Int
    @State private var opponentName: String
    @State private var gameDate: Date
    @State private var gameTime: Date
    @State private var gameLocation: String
    @State private var notes: String
    @State private var gameResult: GameResult
    
    // Score input text fields
    @State private var teamScoreText: String
    @State private var opponentScoreText: String
    
    // UI State
    @State private var showingDeleteConfirmation = false
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @State private var hasUnsavedChanges = false
    @State private var showingDiscardAlert = false
    
    init(game: Game, onSave: (() -> Void)? = nil) {
        self.game = game
        self.onSave = onSave
        
        // Initialize state with current game values
        let teamScore = Int(game.teamScore)
        let opponentScore = Int(game.opponentScore)
        
        self._teamScore = State(initialValue: teamScore)
        self._opponentScore = State(initialValue: opponentScore)
        self._teamScoreText = State(initialValue: String(teamScore))
        self._opponentScoreText = State(initialValue: String(opponentScore))
        self._opponentName = State(initialValue: game.opponentName ?? "")
        self._gameDate = State(initialValue: game.gameDate ?? Date())
        self._gameTime = State(initialValue: game.gameTime ?? Date())
        self._gameLocation = State(initialValue: game.gameLocation ?? "")
        self._notes = State(initialValue: game.notes ?? "")
        
        // Determine game result from scores
        let result: GameResult
        if game.isTie {
            result = .tie
        } else if game.isWin {
            result = .win
        } else {
            result = .loss
        }
        self._gameResult = State(initialValue: result)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Game Info Header
                    gameInfoHeader
                    
                    // Game Result Selection
                    gameResultSection
                    
                    // Score Input Section
                    scoreInputSection
                    
                    // Opponent Name
                    opponentNameSection
                    
                    // Date & Time Section
                    dateTimeSection
                    
                    // Location and Notes
                    locationNotesSection
                    
                    // Delete Game Section
                    deleteGameSection
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .navigationTitle("Edit Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showingDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveGame()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValidGame)
                }
            }
            .alert("Validation Error", isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
            .alert("Delete Game", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteGame()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this game? This action cannot be undone.")
            }
            .alert("Discard Changes", isPresented: $showingDiscardAlert) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .onChange(of: teamScore) { _, _ in checkForChanges() }
            .onChange(of: opponentScore) { _, _ in checkForChanges() }
            .onChange(of: opponentName) { _, _ in checkForChanges() }
            .onChange(of: gameDate) { _, _ in checkForChanges() }
            .onChange(of: gameTime) { _, _ in checkForChanges() }
            .onChange(of: gameLocation) { _, _ in checkForChanges() }
            .onChange(of: notes) { _, _ in checkForChanges() }
            .onChange(of: gameResult) { _, _ in 
                adjustScoresForResult()
                checkForChanges() 
            }
        }
    }
    
    // MARK: - Game Info Header
    
    private var gameInfoHeader: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Text("Game Information")
                    .font(Theme.Typography.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Spacer()
                
                if let gameDate = game.gameDate {
                    Text(gameDate, style: .date)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
            
            if let team = game.team {
                HStack {
                    Circle()
                        .fill(Theme.TeamColors.color(from: team.teamColor))
                        .frame(width: 12, height: 12)
                    
                    Text(team.name ?? "Unknown Team")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .cardStyle()
    }
    
    // MARK: - Game Result Selection
    
    private var gameResultSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Game Result")
                .font(Theme.Typography.body)
                .fontWeight(.bold)
                .foregroundColor(Theme.Colors.primaryText)
            
            HStack(spacing: Theme.Spacing.md) {
                ForEach(GameResult.allCases, id: \.self) { result in
                    RadioButtonRow(
                        result: result,
                        isSelected: gameResult == result
                    ) {
                        gameResult = result
                    }
                }
            }
        }
        .padding()
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .cardStyle()
    }
    
    // MARK: - Score Input Section
    
    private var scoreInputSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Score")
                .font(Theme.Typography.body)
                .fontWeight(.bold)
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
                }
            }
        }
        .padding()
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .cardStyle()
    }
    
    // MARK: - Opponent Name Section
    
    private var opponentNameSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Opponent")
                .font(Theme.Typography.body)
                .fontWeight(.bold)
                .foregroundColor(Theme.Colors.primaryText)
            
            TextField("Enter opponent name", text: $opponentName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding()
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .cardStyle()
    }
    
    // MARK: - Date & Time Section
    
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Game Date & Time")
                .font(Theme.Typography.body)
                .fontWeight(.bold)
                .foregroundColor(Theme.Colors.primaryText)
            
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Date")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    DatePicker(
                        "Game Date",
                        selection: $gameDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(CompactDatePickerStyle())
                    .labelsHidden()
                }
                
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Time")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    DatePicker(
                        "Game Time",
                        selection: $gameTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(CompactDatePickerStyle())
                    .labelsHidden()
                }
            }
        }
        .padding()
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .cardStyle()
    }
    
    // MARK: - Location and Notes Section
    
    private var locationNotesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Additional Details")
                .font(Theme.Typography.body)
                .fontWeight(.bold)
                .foregroundColor(Theme.Colors.primaryText)
            
            VStack(spacing: Theme.Spacing.md) {
                // Location
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Location")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    TextField("Enter game location", text: $gameLocation)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Notes
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Notes")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    TextField("Add game notes...", text: $notes, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
            }
        }
        .padding()
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .cardStyle()
    }
    
    // MARK: - Delete Game Section
    
    private var deleteGameSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            Button(action: {
                showingDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                        .font(.body)
                    
                    Text("Delete Game")
                        .font(Theme.Typography.body)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Theme.Colors.destructiveButton)
                .cornerRadius(Theme.CornerRadius.md)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("This action cannot be undone")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .cardStyle()
    }
    
    // MARK: - Score Input Helpers
    
    private func updateTeamScore(_ text: String) {
        guard let score = Int(text) else {
            teamScore = 0
            return
        }
        
        if validateScore(score) {
            teamScore = score
        } else {
            validationMessage = "Team score must be between 0 and \(Constants.Basketball.maxReasonableScore)"
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
        } else {
            validationMessage = "Opponent score must be between 0 and \(Constants.Basketball.maxReasonableScore)"
            showingValidationAlert = true
            // Reset to previous valid value
            opponentScoreText = String(opponentScore)
        }
    }
    
    private func validateScore(_ score: Int) -> Bool {
        return score >= Constants.Basketball.minScore && score <= Constants.Basketball.maxReasonableScore
    }
    
    // MARK: - Validation
    
    private var isValidGame: Bool {
        return !opponentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               teamScore >= 0 &&
               opponentScore >= 0 &&
               teamScore <= Constants.Basketball.maxReasonableScore &&
               opponentScore <= Constants.Basketball.maxReasonableScore
    }
    
    // MARK: - Actions
    
    private func adjustScoresForResult() {
        switch gameResult {
        case .win:
            if teamScore <= opponentScore {
                teamScore = max(opponentScore + 1, 1)
                teamScoreText = String(teamScore)
            }
        case .loss:
            if teamScore >= opponentScore {
                opponentScore = max(teamScore + 1, 1)
                opponentScoreText = String(opponentScore)
            }
        case .tie:
            if teamScore != opponentScore {
                opponentScore = teamScore
                opponentScoreText = String(opponentScore)
            }
        }
    }
    
    private func checkForChanges() {
        let currentGameResult: GameResult
        if game.isTie {
            currentGameResult = .tie
        } else if game.isWin {
            currentGameResult = .win
        } else {
            currentGameResult = .loss
        }
        
        hasUnsavedChanges = 
            teamScore != Int(game.teamScore) ||
            opponentScore != Int(game.opponentScore) ||
            opponentName != (game.opponentName ?? "") ||
            gameDate != (game.gameDate ?? Date()) ||
            gameTime != (game.gameTime ?? Date()) ||
            gameLocation != (game.gameLocation ?? "") ||
            notes != (game.notes ?? "") ||
            gameResult != currentGameResult
    }
    
    private func saveGame() {
        guard validateGame() else { return }
        
        // Update game properties
        game.teamScore = Int32(teamScore)
        game.opponentScore = Int32(opponentScore)
        game.opponentName = opponentName.trimmingCharacters(in: .whitespacesAndNewlines)
        game.gameDate = gameDate
        game.gameTime = gameTime
        game.gameLocation = gameLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        game.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        game.gameEditDate = Date()
        game.gameEditTime = Date()
        
        // Update game result flags
        switch gameResult {
        case .win:
            game.isWin = true
            game.isTie = false
        case .loss:
            game.isWin = false
            game.isTie = false
        case .tie:
            game.isWin = false
            game.isTie = true
        }
        
        do {
            try viewContext.save()
            onSave?()
            dismiss()
        } catch {
            validationMessage = "Failed to save game: \(error.localizedDescription)"
            showingValidationAlert = true
        }
    }
    
    private func validateGame() -> Bool {
        let trimmedOpponentName = opponentName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedOpponentName.isEmpty {
            validationMessage = "Please enter an opponent name"
            showingValidationAlert = true
            return false
        }
        
        if teamScore < 0 || opponentScore < 0 {
            validationMessage = "Scores cannot be negative"
            showingValidationAlert = true
            return false
        }
        
        if teamScore > Constants.Basketball.maxReasonableScore || opponentScore > Constants.Basketball.maxReasonableScore {
            validationMessage = "Scores seem unreasonably high. Please check your input."
            showingValidationAlert = true
            return false
        }
        
        return true
    }
    
    private func deleteGame() {
        viewContext.delete(game)
        
        do {
            try viewContext.save()
            onSave?()
            dismiss()
        } catch {
            validationMessage = "Failed to delete game: \(error.localizedDescription)"
            showingValidationAlert = true
        }
    }
}

// RadioButtonRow is defined in UploadView.swift and reused here

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    // Create sample game for preview
    let game = Game(context: context)
    game.id = UUID()
    game.teamScore = 85
    game.opponentScore = 78
    game.opponentName = "Lakers"
    game.gameDate = Date()
    game.gameTime = Date()
    game.gameLocation = "Home Court"
    game.notes = "Great game!"
    game.isWin = true
    game.isTie = false
    game.gameEditDate = Date()
    game.gameEditTime = Date()
    
    return GameEditView(game: game)
        .environment(\.managedObjectContext, context)
} 