//
//  SetupViewModel.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import SwiftUI
import CoreData
import Combine
import AVFoundation
import PhotosUI
import CoreLocation

@MainActor
class SetupViewModel: ObservableObject {
    // MARK: - Setup State
    
    @Published var currentStep: SetupStep = .welcome
    @Published var isSetupComplete = false
    @Published var canSkipSetup = false
    
    // MARK: - User Data
    
    @Published var playerName = ""
    @Published var teamName = ""
    @Published var teamColor: TeamColor = Constants.Defaults.defaultTeamColor
    @Published var selectedPlayer: Player?
    @Published var selectedTeam: Team?
    
    // MARK: - Permission States
    
    @Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    @Published var photoLibraryPermissionStatus: PHAuthorizationStatus = .notDetermined
    @Published var locationPermissionStatus: CLAuthorizationStatus = .notDetermined
    
    @Published var showingPermissionExplanation = false
    @Published var currentPermissionRequest: PermissionType?
    
    // MARK: - Error Handling
    
    @Published var errorMessage: String?
    @Published var showingError = false
    
    // MARK: - Dependencies
    
    private let viewContext: NSManagedObjectContext
    private let servicesManager: ServicesManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - UserDefaults Keys
    
    private let hasCompletedSetupKey = "hasCompletedSetup"
    private let hasSeenOnboardingKey = "hasSeenOnboarding"
    private let setupSkippedKey = "setupSkipped"
    
    // MARK: - Initialization
    
    init(viewContext: NSManagedObjectContext, servicesManager: ServicesManager) {
        self.viewContext = viewContext
        self.servicesManager = servicesManager
        
        checkSetupStatus()
        setupPermissionObservers()
    }
    
    // MARK: - Setup Status
    
    private func checkSetupStatus() {
        let hasCompletedSetup = UserDefaults.standard.bool(forKey: hasCompletedSetupKey)
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: hasSeenOnboardingKey)
        let setupSkipped = UserDefaults.standard.bool(forKey: setupSkippedKey)
        
        isSetupComplete = hasCompletedSetup
        canSkipSetup = hasSeenOnboarding || setupSkipped
        
        if !isSetupComplete {
            currentStep = .welcome
        }
    }
    
    // MARK: - Setup Flow Navigation
    
    func nextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .playerCreation
        case .playerCreation:
            if !playerName.isEmpty {
                currentStep = .teamCreation
            } else {
                showError("Please enter a player name")
            }
        case .teamCreation:
            if !teamName.isEmpty {
                // Create player and team when moving from team creation to permissions
                createPlayerAndTeam()
                currentStep = .permissions
            } else {
                showError("Please enter a team name")
            }
        case .permissions:
            currentStep = .completion
        case .completion:
            completeSetup()
        }
    }
    
    func previousStep() {
        switch currentStep {
        case .welcome:
            break // Can't go back from welcome
        case .playerCreation:
            currentStep = .welcome
        case .teamCreation:
            currentStep = .playerCreation
        case .permissions:
            currentStep = .teamCreation
        case .completion:
            currentStep = .permissions
        }
    }
    
    func skipSetup() {
        UserDefaults.standard.set(true, forKey: setupSkippedKey)
        isSetupComplete = true
    }
    
    // MARK: - Player and Team Creation
    
    func createPlayerAndTeam() {
        guard !playerName.isEmpty && !teamName.isEmpty else {
            showError("Please fill in all required fields")
            return
        }
        
        do {
            // Create player
            let player = Player(context: viewContext)
            player.id = UUID()
            player.name = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
            player.displayOrder = getNextPlayerDisplayOrder()
            player.sport = "Basketball"
            player.playerColor = Constants.Defaults.defaultPlayerColor.rawValue
            
            // Create team
            let team = Team(context: viewContext)
            team.id = UUID()
            team.name = teamName.trimmingCharacters(in: .whitespacesAndNewlines)
            team.teamColor = teamColor.rawValue
            team.displayOrder = 0
            team.sport = "Basketball"
            team.player = player
            
            // Save to Core Data
            try viewContext.save()
            
            selectedPlayer = player
            selectedTeam = team
            
        } catch {
            showError("Failed to create player and team: \(error.localizedDescription)")
        }
    }
    
    private func getNextPlayerDisplayOrder() -> Int32 {
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Player.displayOrder, ascending: false)]
        request.fetchLimit = 1
        
        if let lastPlayer = try? viewContext.fetch(request).first {
            return lastPlayer.displayOrder + 1
        }
        return 0
    }
    
    // MARK: - Permission Management
    
    func requestPermission(_ type: PermissionType) {
        currentPermissionRequest = type
        
        Task {
            do {
                switch type {
                case .camera:
                    let granted = await servicesManager.photoService.requestCameraPermission()
                    await MainActor.run {
                        cameraPermissionStatus = granted ? .authorized : .denied
                        currentPermissionRequest = nil
                    }
                    
                case .photoLibrary:
                    let granted = await servicesManager.photoService.requestPhotoLibraryPermission()
                    await MainActor.run {
                        photoLibraryPermissionStatus = granted ? .authorized : .denied
                        currentPermissionRequest = nil
                    }
                    
                case .location:
                    servicesManager.requestLocationPermission()
                    await MainActor.run {
                        currentPermissionRequest = nil
                    }
                }
            } catch {
                await MainActor.run {
                    showError("Failed to request permission: \(error.localizedDescription)")
                    currentPermissionRequest = nil
                }
            }
        }
    }
    
    func showPermissionExplanation(for type: PermissionType) {
        currentPermissionRequest = type
        showingPermissionExplanation = true
    }
    
    func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func setupPermissionObservers() {
        // Monitor location permission changes
        servicesManager.locationService.$authorizationStatus
            .sink { [weak self] status in
                self?.locationPermissionStatus = status
            }
            .store(in: &cancellables)
        
        // Monitor camera permission changes
        servicesManager.photoService.$cameraPermissionStatus
            .sink { [weak self] status in
                self?.cameraPermissionStatus = status
            }
            .store(in: &cancellables)
        
        // Monitor photo library permission changes
        servicesManager.photoService.$photoLibraryPermissionStatus
            .sink { [weak self] status in
                self?.photoLibraryPermissionStatus = status
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Setup Completion
    
    private func completeSetup() {
        guard selectedPlayer != nil, selectedTeam != nil else {
            showError("Player and team must be created before completing setup")
            return
        }
        
        // Mark setup as complete
        UserDefaults.standard.set(true, forKey: hasCompletedSetupKey)
        UserDefaults.standard.set(true, forKey: hasSeenOnboardingKey)
        
        isSetupComplete = true
    }
    
    // MARK: - Error Handling
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    func clearError() {
        errorMessage = nil
        showingError = false
    }
    
    // MARK: - Validation
    
    var canProceedFromPlayerCreation: Bool {
        !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var canProceedFromTeamCreation: Bool {
        !teamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var canCompleteSetup: Bool {
        selectedPlayer != nil && selectedTeam != nil
    }
}

// MARK: - Supporting Types

enum SetupStep: Int, CaseIterable {
    case welcome = 0
    case playerCreation = 1
    case teamCreation = 2
    case permissions = 3
    case completion = 4
    
    var title: String {
        switch self {
        case .welcome:
            return "Welcome to ScoreSnap"
        case .playerCreation:
            return "Create Your Profile"
        case .teamCreation:
            return "Create Your Team"
        case .permissions:
            return "App Permissions"
        case .completion:
            return "You're All Set!"
        }
    }
    
    var description: String {
        switch self {
        case .welcome:
            return "Let's get you started with ScoreSnap"
        case .playerCreation:
            return "Tell us about yourself"
        case .teamCreation:
            return "Set up your basketball team"
        case .permissions:
            return "Enable features for the best experience"
        case .completion:
            return "You're ready to start tracking games!"
        }
    }
}

enum PermissionType: String, CaseIterable {
    case camera = "Camera"
    case photoLibrary = "Photo Library"
    case location = "Location"
    
    var icon: String {
        switch self {
        case .camera:
            return "camera.fill"
        case .photoLibrary:
            return "photo.fill"
        case .location:
            return "location.fill"
        }
    }
    
    var title: String {
        switch self {
        case .camera:
            return "Camera Access"
        case .photoLibrary:
            return "Photo Library Access"
        case .location:
            return "Location Access"
        }
    }
    
    var description: String {
        switch self {
        case .camera:
            return "Take photos of basketball scoreboards"
        case .photoLibrary:
            return "Select existing photos of scoreboards"
        case .location:
            return "Record where your games are played"
        }
    }
    
    var explanation: String {
        switch self {
        case .camera:
            return "ScoreSnap needs camera access to take photos of basketball scoreboards. This helps us accurately record game scores and statistics."
        case .photoLibrary:
            return "ScoreSnap needs photo library access to select existing photos of basketball scoreboards. This allows you to upload photos you've already taken."
        case .location:
            return "ScoreSnap uses location to record where your basketball games are played. This helps organize your game history and provides useful statistics."
        }
    }
} 