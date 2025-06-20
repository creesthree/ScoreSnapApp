//
//  SetupView.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import SwiftUI
import CoreData
import AVFoundation
import PhotosUI
import CoreLocation

struct SetupView: View {
    @EnvironmentObject var appContext: AppContext
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: SetupViewModel
    
    init() {
        self._viewModel = StateObject(wrappedValue: SetupViewModel(
            viewContext: PersistenceController.shared.container.viewContext,
            servicesManager: ServicesManager.shared
        ))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress Indicator
                    SetupProgressView(currentStep: viewModel.currentStep)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.md)
                    
                    // Content
                    ScrollView {
                        VStack(spacing: Theme.Spacing.xl) {
                            switch viewModel.currentStep {
                            case .welcome:
                                WelcomeStepView(viewModel: viewModel)
                            case .playerCreation:
                                PlayerCreationStepView(viewModel: viewModel)
                            case .teamCreation:
                                TeamCreationStepView(viewModel: viewModel)
                            case .permissions:
                                PermissionsStepView(viewModel: viewModel)
                            case .completion:
                                CompletionStepView(viewModel: viewModel)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xl)
                    }
                    
                    // Navigation Buttons
                    SetupNavigationView(viewModel: viewModel)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.bottom, Theme.Spacing.md)
                }
            }
            .navigationBarHidden(true)
        }
        .onChange(of: viewModel.isSetupComplete) { isComplete in
            if isComplete {
                // Update AppContext with the created player and team
                if let player = viewModel.selectedPlayer, let team = viewModel.selectedTeam {
                    appContext.completeSetup(with: player, and: team)
                }
                dismiss()
            }
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $viewModel.showingPermissionExplanation) {
            if let permissionType = viewModel.currentPermissionRequest {
                PermissionExplanationView(
                    permissionType: permissionType,
                    viewModel: viewModel
                )
            }
        }
    }
}

// MARK: - Progress Indicator

struct SetupProgressView: View {
    let currentStep: SetupStep
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(SetupStep.allCases, id: \.self) { step in
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Theme.Colors.primary : Theme.Colors.secondaryText.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            Text("\(currentStep.rawValue + 1) of \(SetupStep.allCases.count)")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
        }
    }
}

// MARK: - Welcome Step

struct WelcomeStepView: View {
    @ObservedObject var viewModel: SetupViewModel
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            // App Icon/Logo
            Image(systemName: "basketball.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.Colors.primary)
            
            // Welcome Text
            VStack(spacing: Theme.Spacing.md) {
                Text("Welcome to ScoreSnap")
                    .font(Theme.Typography.title1)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.Colors.primaryText)
                    .multilineTextAlignment(.center)
                
                Text("Track your basketball games with ease")
                    .font(Theme.Typography.title3)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            // Features List
            VStack(spacing: Theme.Spacing.md) {
                FeatureRow(icon: "camera.fill", title: "Photo Scoreboards", description: "Take photos of scoreboards to record games")
                FeatureRow(icon: "chart.bar.fill", title: "Game Statistics", description: "Track wins, losses, and performance over time")
                FeatureRow(icon: "location.fill", title: "Game Locations", description: "Record where your games are played")
            }
            .padding(.vertical, Theme.Spacing.lg)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Theme.Colors.primary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Text(description)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            
            Spacer()
        }
    }
}

// MARK: - Player Creation Step

struct PlayerCreationStepView: View {
    @ObservedObject var viewModel: SetupViewModel
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            // Header
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "person.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.primary)
                
                Text("Create Your Profile")
                    .font(Theme.Typography.title1)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Text("Tell us about yourself")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            
            // Player Name Input
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Player Name")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                
                TextField("Enter your name", text: $viewModel.playerName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(Theme.Typography.body)
            }
            
            Spacer()
        }
    }
}

// MARK: - Team Creation Step

struct TeamCreationStepView: View {
    @ObservedObject var viewModel: SetupViewModel
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            // Header
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.primary)
                
                Text("Create Your Team")
                    .font(Theme.Typography.title1)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Text("Set up your basketball team")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            
            // Team Name Input
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Team Name")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                
                TextField("Enter team name", text: $viewModel.teamName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(Theme.Typography.body)
            }
            
            // Team Color Selection
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Team Color")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Theme.Spacing.md) {
                    ForEach(TeamColor.allCases, id: \.self) { color in
                        TeamColorButton(
                            color: color,
                            isSelected: viewModel.teamColor == color,
                            action: { viewModel.teamColor = color }
                        )
                    }
                }
            }
            
            Spacer()
        }
    }
}

struct TeamColorButton: View {
    let color: TeamColor
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.color)
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Theme.Colors.primary : Color.clear, lineWidth: 3)
                )
        }
    }
}

// MARK: - Permissions Step

struct PermissionsStepView: View {
    @ObservedObject var viewModel: SetupViewModel
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            // Header
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.primary)
                
                Text("App Permissions")
                    .font(Theme.Typography.title1)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Text("Enable features for the best experience")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            
            // Permission Cards
            VStack(spacing: Theme.Spacing.md) {
                ForEach(PermissionType.allCases, id: \.self) { permissionType in
                    PermissionCard(
                        permissionType: permissionType,
                        viewModel: viewModel
                    )
                }
            }
            
            // Optional Note
            Text("All permissions are optional. You can change these later in Settings.")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, Theme.Spacing.md)
            
            Spacer()
        }
    }
}

struct PermissionCard: View {
    let permissionType: PermissionType
    @ObservedObject var viewModel: SetupViewModel
    
    private var permissionStatus: String {
        switch permissionType {
        case .camera:
            return getPermissionStatusText(viewModel.cameraPermissionStatus)
        case .photoLibrary:
            return getPermissionStatusText(viewModel.photoLibraryPermissionStatus)
        case .location:
            return getLocationPermissionStatusText(viewModel.locationPermissionStatus)
        }
    }
    
    private var isGranted: Bool {
        switch permissionType {
        case .camera:
            return viewModel.cameraPermissionStatus == .authorized
        case .photoLibrary:
            return viewModel.photoLibraryPermissionStatus == .authorized || viewModel.photoLibraryPermissionStatus == .limited
        case .location:
            return viewModel.locationPermissionStatus == .authorizedWhenInUse || viewModel.locationPermissionStatus == .authorizedAlways
        }
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Icon
            Image(systemName: permissionType.icon)
                .font(.title2)
                .foregroundColor(isGranted ? .green : Theme.Colors.primary)
                .frame(width: 30)
            
            // Content
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(permissionType.title)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Text(permissionType.description)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                
                Text(permissionStatus)
                    .font(Theme.Typography.caption)
                    .foregroundColor(isGranted ? .green : Theme.Colors.secondaryText)
            }
            
            Spacer()
            
            // Action Button
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Button("Enable") {
                    viewModel.requestPermission(permissionType)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surfaceBackground)
        .cornerRadius(Theme.CornerRadius.md)
        .onTapGesture {
            if !isGranted {
                viewModel.showPermissionExplanation(for: permissionType)
            }
        }
    }
    
    private func getPermissionStatusText(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not requested"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorized:
            return "Granted"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func getPermissionStatusText(_ status: PHAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not requested"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorized:
            return "Granted"
        case .limited:
            return "Limited access"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func getLocationPermissionStatusText(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not requested"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedWhenInUse:
            return "When in use"
        case .authorizedAlways:
            return "Always"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - Completion Step

struct CompletionStepView: View {
    @ObservedObject var viewModel: SetupViewModel
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            // Success Animation/Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .scaleEffect(1.2)
            
            // Completion Text
            VStack(spacing: Theme.Spacing.md) {
                Text("You're All Set!")
                    .font(Theme.Typography.title1)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Text("You're ready to start tracking games!")
                    .font(Theme.Typography.title3)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            // Created Profile Summary
            if let player = viewModel.selectedPlayer, let team = viewModel.selectedTeam {
                VStack(spacing: Theme.Spacing.md) {
                    Text("Your Profile")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primaryText)
                    
                    VStack(spacing: Theme.Spacing.sm) {
                        HStack {
                            Text("Player:")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.secondaryText)
                            Text(player.name ?? "Unknown")
                                .font(Theme.Typography.body)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.Colors.primaryText)
                            Spacer()
                        }
                        
                        HStack {
                            Text("Team:")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.secondaryText)
                            HStack(spacing: Theme.Spacing.xs) {
                                Circle()
                                    .fill(Theme.TeamColors.color(from: team.teamColor))
                                    .frame(width: 12, height: 12)
                                Text(team.name ?? "Unknown")
                                    .font(Theme.Typography.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Theme.Colors.primaryText)
                            }
                            Spacer()
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.surfaceBackground)
                    .cornerRadius(Theme.CornerRadius.md)
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Navigation

struct SetupNavigationView: View {
    @ObservedObject var viewModel: SetupViewModel
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Back Button
            if viewModel.currentStep != .welcome {
                Button("Back") {
                    viewModel.previousStep()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            // Skip Button (only show on welcome for returning users)
            if viewModel.currentStep == .welcome && viewModel.canSkipSetup {
                Button("Skip") {
                    viewModel.skipSetup()
                }
                .buttonStyle(.bordered)
            }
            
            // Next/Complete Button
            Button(viewModel.currentStep == .completion ? "Get Started" : "Next") {
                viewModel.nextStep()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canProceed)
        }
    }
    
    private var canProceed: Bool {
        switch viewModel.currentStep {
        case .welcome:
            return true
        case .playerCreation:
            return viewModel.canProceedFromPlayerCreation
        case .teamCreation:
            return viewModel.canProceedFromTeamCreation
        case .permissions:
            return true
        case .completion:
            return viewModel.canCompleteSetup
        }
    }
}

// MARK: - Permission Explanation Sheet

struct PermissionExplanationView: View {
    let permissionType: PermissionType
    @ObservedObject var viewModel: SetupViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: Theme.Spacing.xl) {
                // Icon
                Image(systemName: permissionType.icon)
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.primary)
                
                // Content
                VStack(spacing: Theme.Spacing.md) {
                    Text(permissionType.title)
                        .font(Theme.Typography.title1)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.primaryText)
                    
                    Text(permissionType.explanation)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: Theme.Spacing.md) {
                    Button("Enable \(permissionType.rawValue)") {
                        viewModel.requestPermission(permissionType)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    
                    Button("Not Now") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(Theme.Spacing.xl)
            .navigationTitle("Permission Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SetupView()
        .environmentObject(AppContext(viewContext: PersistenceController.preview.container.viewContext))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 