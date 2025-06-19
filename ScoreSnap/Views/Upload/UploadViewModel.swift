//
//  UploadViewModel.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI
import CoreData
import Combine

@MainActor
class UploadViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // Manual Entry Form Data
    @Published var gameResult: GameResult = .win
    @Published var teamScore: Int = 0
    @Published var opponentScore: Int = 0
    @Published var opponentName: String = ""
    @Published var gameDate: Date = Date()
    @Published var gameTime: Date = Date()
    @Published var gameLocation: String = ""
    @Published var gameNotes: String = ""
    
    // Validation States
    @Published var isOpponentNameValid = false
    @Published var isFormValid = false
    
    private let viewContext: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        setupValidation()
    }
    
    // MARK: - Validation Setup
    
    private func setupValidation() {
        // Combine validation publishers - use CombineLatest3 for 3 publishers
        Publishers.CombineLatest3($isOpponentNameValid, $teamScore, $opponentScore)
            .map { isOpponentValid, teamScore, opponentScore in
                isOpponentValid && 
                teamScore >= Constants.Basketball.minScore && 
                teamScore <= Constants.Basketball.maxReasonableScore &&
                opponentScore >= Constants.Basketball.minScore && 
                opponentScore <= Constants.Basketball.maxReasonableScore
            }
            .assign(to: &$isFormValid)
    }
    
    // MARK: - Smart Score Assignment
    
    func assignSmartScores() {
        switch gameResult {
        case .win:
            // Ensure team score is higher than opponent
            if teamScore <= opponentScore {
                teamScore = opponentScore + 7
            }
        case .loss:
            // Ensure opponent score is higher than team
            if opponentScore <= teamScore {
                opponentScore = teamScore + 7
            }
        case .tie:
            // For ties, make scores equal
            let averageScore = (teamScore + opponentScore) / 2
            teamScore = averageScore
            opponentScore = averageScore
        }
    }
    
    // MARK: - Game Creation
    
    func createGame(for team: Team?) -> Bool {
        guard let team = team else {
            errorMessage = "No team selected"
            return false
        }
        
        guard isFormValid else {
            errorMessage = "Please fix validation errors"
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let game = Game(context: viewContext)
            game.id = UUID()
            game.gameDate = gameDate
            game.gameTime = gameTime
            game.gameLocation = gameLocation.isEmpty ? nil : gameLocation
            game.teamScore = Int32(teamScore)
            game.opponentScore = Int32(opponentScore)
            game.isWin = gameResult.isWin
            game.isTie = gameResult.isTie
            game.opponentName = opponentName.trimmed
            game.notes = gameNotes.isEmpty ? nil : gameNotes
            game.gameEditDate = Date()
            game.gameEditTime = Date()
            game.team = team
            
            try viewContext.save()
            
            successMessage = "Game saved successfully!"
            resetForm()
            
            isLoading = false
            return true
            
        } catch {
            isLoading = false
            errorMessage = "Failed to save game: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Form Management
    
    func resetForm() {
        gameResult = .win
        teamScore = 0
        opponentScore = 0
        opponentName = ""
        gameDate = Date()
        gameTime = Date()
        gameLocation = ""
        gameNotes = ""
        isOpponentNameValid = false
        isFormValid = false
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
    
    // MARK: - Validation Methods
    
    func validateOpponentName(_ name: String) -> Bool {
        let trimmed = name.trimmed
        return !trimmed.isEmpty && trimmed.count <= 50
    }
    
    func validateScore(_ score: Int) -> Bool {
        return score >= Constants.Basketball.minScore && score <= Constants.Basketball.maxReasonableScore
    }
    
    // MARK: - Helper Methods
    
    func getGameSummary() -> String {
        let resultText = gameResult.displayText
        let scoreText = "\(teamScore)-\(opponentScore)"
        let opponentText = opponentName.isEmpty ? "Unknown" : opponentName
        return "\(resultText) vs \(opponentText) (\(scoreText))"
    }
    
    func getFormattedGameDate() -> String {
        return gameDate.gameDisplayFormat
    }
    
    func getFormattedGameTime() -> String {
        return gameTime.gameTimeFormat
    }
} 