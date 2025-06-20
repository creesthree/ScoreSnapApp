//
//  ScoreConfirmationView.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI

struct ScoreConfirmationView: View {
    let analysisResult: ScoreboardAnalysis
    @Binding var confirmedTeamScore: Int
    @Binding var confirmedOpponentScore: Int
    @Binding var confirmedGameResult: GameResult
    @Binding var confirmedOpponentName: String
    @Binding var confirmedGameDate: Date
    @Binding var confirmedGameTime: Date
    @Binding var confirmedLocation: String
    
    let originalImage: UIImage
    let onConfirm: () -> Void
    let onEdit: () -> Void
    let onRetake: () -> Void
    
    @State private var showingImagePreview = false
    @State private var isEditing = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Header Section
                headerSection
                
                // Image Preview Section
                imagePreviewSection
                
                // AI Analysis Results
                analysisResultsSection
                
                // Score Confirmation Section
                scoreConfirmationSection
                
                // Game Details Section
                gameDetailsSection
                
                // Action Buttons
                actionButtonsSection
            }
            .padding()
        }
        .navigationTitle("Confirm Score")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingImagePreview) {
            ImagePreviewSheet(image: originalImage)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(Theme.Colors.success)
                
                Text("Score Detected")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Spacer()
            }
            
            HStack {
                Text("Review and confirm the detected information")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                Spacer()
            }
        }
        .padding()
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .cardStyle()
    }
    
    // MARK: - Image Preview Section
    
    private var imagePreviewSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Source Image")
                .font(Theme.Typography.body)
                .fontWeight(.bold)
                .foregroundColor(Theme.Colors.primaryText)
            
            Button(action: { showingImagePreview = true }) {
                Image(uiImage: originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 150)
                    .cornerRadius(Theme.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .stroke(Theme.Colors.border, lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            HStack {
                Image(systemName: "eye.fill")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                Text("Tap to view full size")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                Spacer()
            }
        }
        .padding()
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .cardStyle()
    }
    
    // MARK: - Analysis Results Section
    
    private var analysisResultsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("AI Analysis Results")
                .font(Theme.Typography.body)
                .fontWeight(.bold)
                .foregroundColor(Theme.Colors.primaryText)
            
            VStack(spacing: Theme.Spacing.sm) {
                analysisResultRow(
                    title: "Confidence Level",
                    value: "\(Int(analysisResult.confidence * 100))%",
                    icon: "gauge.medium",
                    color: confidenceColor
                )
                
                if let detectedScore = analysisResult.detectedScore {
                    analysisResultRow(
                        title: "Detected Score",
                        value: "\(detectedScore.homeScore)-\(detectedScore.awayScore)",
                        icon: "sportscourt.fill",
                        color: Theme.Colors.primary
                    )
                }
                
                if let period = analysisResult.period {
                    analysisResultRow(
                        title: "Game Period",
                        value: period,
                        icon: "clock.fill",
                        color: Theme.Colors.secondary
                    )
                }
                
                if let timeRemaining = analysisResult.timeRemaining {
                    analysisResultRow(
                        title: "Time Remaining",
                        value: timeRemaining,
                        icon: "timer",
                        color: Theme.Colors.secondary
                    )
                }
            }
        }
        .padding()
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .cardStyle()
    }
    
    private func analysisResultRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(Theme.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(Theme.Colors.primaryText)
        }
    }
    
    private var confidenceColor: Color {
        let confidence = analysisResult.confidence
        if confidence >= 0.8 {
            return Theme.Colors.success
        } else if confidence >= 0.6 {
            return Theme.Colors.warning
        } else {
            return Theme.Colors.error
        }
    }
    
    // MARK: - Score Confirmation Section
    
    private var scoreConfirmationSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Confirm Score")
                    .font(Theme.Typography.body)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Spacer()
                
                Button(action: { isEditing.toggle() }) {
                    Text(isEditing ? "Done" : "Edit")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.primary)
                }
            }
            
            if isEditing {
                editableScoreSection
            } else {
                readOnlyScoreSection
            }
        }
        .padding()
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .cardStyle()
    }
    
    private var readOnlyScoreSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Game Result Display
            HStack {
                Text("Game Result:")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                
                Spacer()
                
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: confirmedGameResult.iconName)
                        .font(.caption)
                        .foregroundColor(confirmedGameResult.color)
                    
                    Text(confirmedGameResult.displayText)
                        .font(Theme.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(confirmedGameResult.color)
                }
            }
            
            // Score Display
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Your Team")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    Text("\(confirmedTeamScore)")
                        .font(Theme.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Colors.primaryText)
                }
                
                Spacer()
                
                Text("vs")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                    Text("Opponent")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    Text("\(confirmedOpponentScore)")
                        .font(Theme.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Colors.primaryText)
                }
            }
        }
    }
    
    private var editableScoreSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Game Result Selection
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Game Result")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(GameResult.allCases, id: \.self) { result in
                        Button(action: {
                            confirmedGameResult = result
                            adjustScoresForResult()
                        }) {
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: result.iconName)
                                    .font(.caption)
                                Text(result.displayText)
                                    .font(Theme.Typography.caption)
                            }
                            .foregroundColor(confirmedGameResult == result ? .white : result.color)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                    .fill(confirmedGameResult == result ? result.color : result.color.opacity(0.1))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // Score Editing
            HStack(spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Your Team")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    TextField("Score", value: $confirmedTeamScore, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: confirmedTeamScore) { _, _ in
                            updateGameResultFromScores()
                        }
                }
                
                VStack {
                    Spacer()
                    Text("vs")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Opponent")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    TextField("Score", value: $confirmedOpponentScore, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: confirmedOpponentScore) { _, _ in
                            updateGameResultFromScores()
                        }
                }
            }
        }
    }
    
    // MARK: - Game Details Section
    
    private var gameDetailsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Game Details")
                .font(Theme.Typography.body)
                .fontWeight(.bold)
                .foregroundColor(Theme.Colors.primaryText)
            
            VStack(spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Opponent:")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    Spacer()
                    
                    if isEditing {
                        TextField("Opponent Name", text: $confirmedOpponentName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: 150)
                    } else {
                        Text(confirmedOpponentName.isEmpty ? "Not specified" : confirmedOpponentName)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                }
                
                HStack {
                    Text("Date:")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    Spacer()
                    
                    if isEditing {
                        DatePicker("Date", selection: $confirmedGameDate, displayedComponents: .date)
                            .datePickerStyle(CompactDatePickerStyle())
                            .labelsHidden()
                    } else {
                        Text(confirmedGameDate.gameDisplayFormat)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                }
                
                HStack {
                    Text("Time:")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    Spacer()
                    
                    if isEditing {
                        DatePicker("Time", selection: $confirmedGameTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(CompactDatePickerStyle())
                            .labelsHidden()
                    } else {
                        Text(confirmedGameTime.gameTimeFormat)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                }
                
                HStack {
                    Text("Location:")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    Spacer()
                    
                    if isEditing {
                        TextField("Location", text: $confirmedLocation)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: 150)
                    } else {
                        Text(confirmedLocation.isEmpty ? "Not specified" : confirmedLocation)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                }
            }
        }
        .padding()
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .cardStyle()
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Primary Action Button
            Button(action: onConfirm) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                    
                    Text("Save Game")
                        .font(Theme.Typography.body)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Theme.Colors.primary)
                .foregroundColor(.white)
                .cornerRadius(Theme.CornerRadius.md)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Secondary Actions
            HStack(spacing: Theme.Spacing.md) {
                Button(action: onEdit) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "pencil")
                            .font(.caption)
                        
                        Text("Manual Entry")
                            .font(Theme.Typography.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Theme.Colors.secondaryBackground)
                    .foregroundColor(Theme.Colors.primaryText)
                    .cornerRadius(Theme.CornerRadius.md)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onRetake) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "camera.rotate")
                            .font(.caption)
                        
                        Text("Retake Photo")
                            .font(Theme.Typography.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Theme.Colors.secondaryBackground)
                    .foregroundColor(Theme.Colors.primaryText)
                    .cornerRadius(Theme.CornerRadius.md)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func adjustScoresForResult() {
        switch confirmedGameResult {
        case .win:
            if confirmedTeamScore <= confirmedOpponentScore {
                confirmedTeamScore = confirmedOpponentScore + 1
            }
        case .loss:
            if confirmedOpponentScore <= confirmedTeamScore {
                confirmedOpponentScore = confirmedTeamScore + 1
            }
        case .tie:
            let average = (confirmedTeamScore + confirmedOpponentScore) / 2
            confirmedTeamScore = average
            confirmedOpponentScore = average
        }
    }
    
    private func updateGameResultFromScores() {
        if confirmedTeamScore > confirmedOpponentScore {
            confirmedGameResult = .win
        } else if confirmedOpponentScore > confirmedTeamScore {
            confirmedGameResult = .loss
        } else {
            confirmedGameResult = .tie
        }
    }
}

// MARK: - Image Preview Sheet

struct ImagePreviewSheet: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    let sampleAnalysis = ScoreboardAnalysis(
        detectedScore: DetectedScore(homeScore: 85, awayScore: 78),
        confidence: 0.92,
        period: "4th Quarter",
        timeRemaining: "2:45",
        additionalInfo: "Clear scoreboard image"
    )
    
    let sampleImage = UIImage(systemName: "photo") ?? UIImage()
    
    ScoreConfirmationView(
        analysisResult: sampleAnalysis,
        confirmedTeamScore: .constant(85),
        confirmedOpponentScore: .constant(78),
        confirmedGameResult: .constant(.win),
        confirmedOpponentName: .constant("Lakers"),
        confirmedGameDate: .constant(Date()),
        confirmedGameTime: .constant(Date()),
        confirmedLocation: .constant("Home Court"),
        originalImage: sampleImage,
        onConfirm: {},
        onEdit: {},
        onRetake: {}
    )
} 