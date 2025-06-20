//
//  UploadView.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI
import CoreData

struct UploadView: View {
    @EnvironmentObject var appContext: AppContext
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: UploadViewModel
    @State private var selectedTab = 0
    
    init() {
        self._viewModel = StateObject(wrappedValue: UploadViewModel(viewContext: PersistenceController.shared.container.viewContext))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                Picker("Upload Method", selection: $selectedTab) {
                    Text("Camera").tag(0)
                    Text("Manual").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, Theme.Spacing.sm)
                
                // Content based on selected tab
                if selectedTab == 0 {
                    CameraUploadView()
                } else {
                    ManualEntryView(viewModel: viewModel)
                }
            }
            .navigationTitle("Add Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearMessages()
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .alert("Success", isPresented: .constant(viewModel.successMessage != nil)) {
                Button("OK") {
                    viewModel.clearMessages()
                    dismiss()
                }
            } message: {
                if let successMessage = viewModel.successMessage {
                    Text(successMessage)
                }
            }
        }
    }
}

struct ManualEntryView: View {
    @EnvironmentObject var appContext: AppContext
    @ObservedObject var viewModel: UploadViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                // Player & Team Selection
                PlayerSelectionSection()
                
                // Manual Entry Form
                if appContext.currentTeam != nil {
                    ManualEntryForm(viewModel: viewModel)
                } else {
                    NoTeamSelectedView()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .background(Theme.Colors.background)
    }
}

struct PlayerSelectionSection: View {
    @EnvironmentObject var appContext: AppContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Player")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
            }
            
            PlayerSegmentedControl()
            
            // Team Dropdown for selected player
            if let currentPlayer = appContext.currentPlayer {
                HStack {
                    Text("Team")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                    Spacer()
                }
                .padding(.top, Theme.Spacing.sm)
                
                TeamDropdown(player: currentPlayer)
            }
        }
        .padding()
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .cardStyle()
    }
}

struct NoTeamSelectedView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.title3)
                    .foregroundColor(Theme.Colors.secondaryText)
                
                Text("No Team Selected")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Spacer()
            }
            
            HStack {
                Text("Please select a team from above before adding a game")
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
}

struct ManualEntryForm: View {
    @EnvironmentObject var appContext: AppContext
    @ObservedObject var viewModel: UploadViewModel
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Game Result Selection - Radio Button Style
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Game Result")
                        .font(Theme.Typography.body)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Colors.primaryText)
                    Spacer()
                }
                
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(GameResult.allCases, id: \.self) { result in
                        RadioButtonRow(
                            result: result,
                            isSelected: viewModel.gameResult == result
                        ) {
                            viewModel.gameResult = result
                            viewModel.assignSmartScores()
                        }
                    }
                }
            }
            
            // Score Input
            ScoreInputView(
                teamScore: $viewModel.teamScore,
                opponentScore: $viewModel.opponentScore,
                gameResult: viewModel.gameResult
            ) {
                // Score changed callback
            }
            
            // Opponent Name
            OpponentNameField(
                opponentName: $viewModel.opponentName
            ) { isValid in
                viewModel.isOpponentNameValid = isValid
            }
            
            // Date & Time - Left Justified Header
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Game Date & Time")
                        .font(Theme.Typography.body)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Colors.primaryText)
                    Spacer()
                }
                
                // Compact Date and Time Pickers
                VStack(spacing: Theme.Spacing.sm) {
                    HStack(spacing: Theme.Spacing.md) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Date")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                            
                            DatePicker(
                                "Game Date",
                                selection: $viewModel.gameDate,
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
                                selection: $viewModel.gameTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(CompactDatePickerStyle())
                            .labelsHidden()
                        }
                    }
                }
            }
            
            // Location and Notes in compact layout
            HStack(spacing: Theme.Spacing.md) {
                // Location (Optional)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Location")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    TextField("Optional", text: $viewModel.gameLocation)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.caption)
                }
                
                // Notes (Optional)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Notes")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    TextField("Optional", text: $viewModel.gameNotes)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.caption)
                }
            }
            
            // Save Button - Compact
            Button(action: {
                viewModel.createGame(for: appContext.currentTeam)
            }) {
                HStack(spacing: Theme.Spacing.xs) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                    }
                    
                    Text(viewModel.isLoading ? "Saving..." : "Save Game")
                        .font(Theme.Typography.body)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(viewModel.isFormValid ? Theme.Colors.primary : Theme.Colors.secondaryText)
                .foregroundColor(.white)
                .cornerRadius(Theme.CornerRadius.md)
            }
            .disabled(!viewModel.isFormValid || viewModel.isLoading)
            .animation(Theme.Animation.quick, value: viewModel.isFormValid)
            .animation(Theme.Animation.quick, value: viewModel.isLoading)
        }
    }
}

struct RadioButtonRow: View {
    let result: GameResult
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                // Radio button circle
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.Colors.primary : Theme.Colors.secondaryText, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    if isSelected {
                        Circle()
                            .fill(Theme.Colors.primary)
                            .frame(width: 12, height: 12)
                    }
                }
                
                // Result text
                Text(result.displayText)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CameraUploadView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.secondaryText)
            
            Text("Camera Upload")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.primaryText)
            
            Text("Camera functionality coming in Phase 6")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
    }
}

#Preview {
    UploadView()
        .environmentObject(AppContext(viewContext: PersistenceController.preview.container.viewContext))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 