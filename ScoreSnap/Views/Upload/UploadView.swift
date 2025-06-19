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
                .padding()
                
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
            VStack(spacing: Theme.Spacing.lg) {
                // Team Selection Header
                if let currentTeam = appContext.currentTeam {
                    TeamSelectionHeader(team: currentTeam)
                } else {
                    NoTeamSelectedView()
                }
                
                // Manual Entry Form
                if appContext.currentTeam != nil {
                    ManualEntryForm(viewModel: viewModel)
                }
            }
            .padding()
        }
        .background(Theme.Colors.background)
    }
}

struct TeamSelectionHeader: View {
    let team: Team
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Circle()
                    .fill(Theme.TeamColors.color(from: team.teamColor))
                    .frame(width: 24, height: 24)
                
                Text(team.name ?? "Unknown Team")
                    .font(Theme.Typography.title3)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text("Adding game for this team")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .padding()
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .cardStyle()
    }
}

struct NoTeamSelectedView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.secondaryText)
            
            Text("No Team Selected")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.primaryText)
            
            Text("Please select a team from the Players tab before adding a game")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
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
        VStack(spacing: Theme.Spacing.lg) {
            // Game Result Selection
            WinLossTieSelector(selectedResult: $viewModel.gameResult)
                .onChange(of: viewModel.gameResult) { _, _ in
                    viewModel.assignSmartScores()
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
            
            // Date & Time
            DateTimePickerView(
                gameDate: $viewModel.gameDate,
                gameTime: $viewModel.gameTime
            )
            
            // Location (Optional)
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Location (Optional)")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                
                TextField("Enter game location", text: $viewModel.gameLocation)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Notes (Optional)
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Notes (Optional)")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                
                TextField("Add game notes", text: $viewModel.gameNotes, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
            }
            
            // Save Button
            Button(action: {
                viewModel.createGame(for: appContext.currentTeam)
            }) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    
                    Text(viewModel.isLoading ? "Saving..." : "Save Game")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: Constants.UI.standardButtonHeight)
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

struct CameraUploadView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "camera.fill")
                .font(.system(size: 64))
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