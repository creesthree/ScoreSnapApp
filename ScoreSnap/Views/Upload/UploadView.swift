//
//  UploadView.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI
import CoreData
import CoreLocation

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
                if appContext.currentTeam != nil {
                    TabView(selection: $selectedTab) {
                        CameraUploadView(onSwitchToManual: {
                            selectedTab = 1
                        })
                        .tabItem {
                            Image(systemName: "camera.fill")
                            Text("Camera")
                        }
                        .tag(0)
                        
                        ManualEntryView(viewModel: viewModel)
                            .tabItem {
                                Image(systemName: "pencil")
                                Text("Manual")
                            }
                            .tag(1)
                    }
                } else {
                    NoTeamSelectedView()
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
    @EnvironmentObject var appContext: AppContext
    @StateObject private var photoService = PhotoService()
    @StateObject private var uploadViewModel: UploadViewModel
    @State private var capturedImage: UIImage?
    @State private var analysisResult: ScoreboardAnalysis?
    @State private var isAnalyzing = false
    @State private var showingScoreConfirmation = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var uploadState: PhotoUploadState = .initial
    
    let onSwitchToManual: () -> Void
    
    // Score confirmation bindings
    @State private var confirmedTeamScore = 0
    @State private var confirmedOpponentScore = 0
    @State private var confirmedGameResult: GameResult = .win
    @State private var confirmedOpponentName = ""
    @State private var confirmedGameDate = Date()
    @State private var confirmedGameTime = Date()
    @State private var confirmedLocation = ""
    
    init(onSwitchToManual: @escaping () -> Void) {
        self.onSwitchToManual = onSwitchToManual
        self._uploadViewModel = StateObject(wrappedValue: UploadViewModel(viewContext: PersistenceController.shared.container.viewContext))
    }
    
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            switch uploadState {
            case .initial:
                initialCameraView
            case .processing:
                processingView
            case .analysisComplete:
                EmptyView() // Navigation to confirmation view handles this
            case .error:
                errorView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
        .navigationDestination(isPresented: $showingScoreConfirmation) {
            if let result = analysisResult, let image = capturedImage {
                ScoreConfirmationView(
                    analysisResult: result,
                    confirmedTeamScore: $confirmedTeamScore,
                    confirmedOpponentScore: $confirmedOpponentScore,
                    confirmedGameResult: $confirmedGameResult,
                    confirmedOpponentName: $confirmedOpponentName,
                    confirmedGameDate: $confirmedGameDate,
                    confirmedGameTime: $confirmedGameTime,
                    confirmedLocation: $confirmedLocation,
                    originalImage: image,
                    onConfirm: confirmAndSaveGame,
                    onEdit: switchToManualEntry,
                    onRetake: retakePhoto
                )
            }
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("Try Again") {
                uploadState = .initial
            }
            Button("Manual Entry") {
                switchToManualEntry()
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Initial Camera View
    
    private var initialCameraView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Camera Icon and Title
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.Colors.primary)
                
                Text("Photo Upload")
                    .font(Theme.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Text("Take a photo of the scoreboard or select from your photo library")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Action Buttons
            VStack(spacing: Theme.Spacing.md) {
                // Take Photo Button
                Button(action: takePhoto) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "camera")
                            .font(.body)
                        
                        Text("Take Photo")
                            .font(Theme.Typography.body)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Theme.Colors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(Theme.CornerRadius.md)
                }
                .disabled(!photoService.isCameraAvailable)
                
                // Photo Library Button
                Button(action: selectFromLibrary) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.body)
                        
                        Text("Choose from Library")
                            .font(Theme.Typography.body)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Theme.Colors.secondary)
                    .foregroundColor(.white)
                    .cornerRadius(Theme.CornerRadius.md)
                }
                .disabled(!photoService.isPhotoLibraryAvailable)
                
                // Permission Status
                if !photoService.isCameraAvailable || !photoService.isPhotoLibraryAvailable {
                    VStack(spacing: Theme.Spacing.sm) {
                        if !photoService.isCameraAvailable {
                            permissionStatusRow(
                                title: "Camera",
                                status: photoService.cameraPermissionStatus,
                                action: requestCameraPermission
                            )
                        }
                        
                        if !photoService.isPhotoLibraryAvailable {
                            permissionStatusRow(
                                title: "Photo Library",
                                status: photoService.photoLibraryPermissionStatus,
                                action: requestPhotoLibraryPermission
                            )
                        }
                    }
                    .padding()
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(Theme.CornerRadius.md)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Processing View
    
    private var processingView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Processing Animation
            VStack(spacing: Theme.Spacing.md) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primary))
                    .scaleEffect(1.5)
                
                Text("Analyzing Scoreboard...")
                    .font(Theme.Typography.headline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Text("Our AI is reading the score from your photo")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            // Progress Steps
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                progressStep("Processing image...", isComplete: true)
                progressStep("Detecting scoreboard...", isComplete: true)
                progressStep("Reading score...", isComplete: false)
                progressStep("Validating results...", isComplete: false)
            }
            .padding()
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.md)
            
            // Cancel Button
            Button("Cancel") {
                uploadState = .initial
                isAnalyzing = false
            }
            .foregroundColor(Theme.Colors.secondaryText)
        }
        .padding()
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.error)
            
            Text("Analysis Failed")
                .font(Theme.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(Theme.Colors.primaryText)
            
            Text(errorMessage)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: Theme.Spacing.md) {
                Button("Try Again") {
                    uploadState = .initial
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Enter Manually") {
                    switchToManualEntry()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Views
    
    private func permissionStatusRow(title: String, status: Any, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.primaryText)
            
            Spacer()
            
            Button("Allow") {
                action()
            }
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.primary)
        }
    }
    
    private func progressStep(_ title: String, isComplete: Bool) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(isComplete ? Theme.Colors.success : Theme.Colors.secondaryText)
            
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(isComplete ? Theme.Colors.primaryText : Theme.Colors.secondaryText)
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func takePhoto() {
        Task {
            do {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController else {
                    throw PhotoError.cameraNotAvailable
                }
                
                let image = try await photoService.capturePhoto(from: rootViewController)
                await handleCapturedImage(image)
            } catch {
                handlePhotoError(error)
            }
        }
    }
    
    private func selectFromLibrary() {
        Task {
            do {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController else {
                    throw PhotoError.photoLibraryNotAvailable
                }
                
                let image = try await photoService.selectPhotoWithPHPicker(from: rootViewController)
                await handleCapturedImage(image)
            } catch {
                handlePhotoError(error)
            }
        }
    }
    
    private func requestCameraPermission() {
        Task {
            await photoService.requestCameraPermission()
        }
    }
    
    private func requestPhotoLibraryPermission() {
        Task {
            await photoService.requestPhotoLibraryPermission()
        }
    }
    
    @MainActor
    private func handleCapturedImage(_ image: UIImage) async {
        capturedImage = image
        uploadState = .processing
        
        // Validate photo
        let validationResult = photoService.validatePhoto(image)
        switch validationResult {
        case .success(let validatedImage):
            await analyzeImage(validatedImage)
        case .failure(let error):
            handlePhotoError(error)
        }
    }
    
    private func analyzeImage(_ image: UIImage) async {
        do {
            let ocrService = ServicesManager.shared.getOCRService()
            let result = try await ocrService.analyzeScoreboard(image)
            
            await MainActor.run {
                analysisResult = result
                populateConfirmationData(from: result)
                uploadState = .analysisComplete
                showingScoreConfirmation = true
            }
        } catch {
            await MainActor.run {
                handleAnalysisError(error)
            }
        }
    }
    
    private func populateConfirmationData(from result: ScoreboardAnalysis) {
        if let detectedScore = result.detectedScore {
            confirmedTeamScore = detectedScore.homeScore
            confirmedOpponentScore = detectedScore.awayScore
            
            // Determine game result
            if detectedScore.homeScore > detectedScore.awayScore {
                confirmedGameResult = .win
            } else if detectedScore.awayScore > detectedScore.homeScore {
                confirmedGameResult = .loss
            } else {
                confirmedGameResult = .tie
            }
        }
        
        // Set current date/time as defaults
        confirmedGameDate = Date()
        confirmedGameTime = Date()
        
        // Extract location from EXIF if available
        if let image = capturedImage,
           let metadata = photoService.extractEXIFMetadata(from: image),
           let coordinate = metadata.coordinate {
            // Use location service to get readable location
            Task {
                let locationService = ServicesManager.shared.getLocationService()
                if let location = try? await locationService.getLocationName(for: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) {
                    await MainActor.run {
                        confirmedLocation = location
                    }
                }
            }
        }
    }
    
    private func handlePhotoError(_ error: Error) {
        errorMessage = error.localizedDescription
        uploadState = .error
        showingErrorAlert = true
    }
    
    private func handleAnalysisError(_ error: Error) {
        errorMessage = "Failed to analyze the scoreboard image. Please try again or enter the score manually."
        uploadState = .error
    }
    
    private func confirmAndSaveGame() {
        // Update upload view model with confirmed data
        uploadViewModel.teamScore = confirmedTeamScore
        uploadViewModel.opponentScore = confirmedOpponentScore
        uploadViewModel.gameResult = confirmedGameResult
        uploadViewModel.opponentName = confirmedOpponentName
        uploadViewModel.gameDate = confirmedGameDate
        uploadViewModel.gameTime = confirmedGameTime
        uploadViewModel.gameLocation = confirmedLocation
        
        // Save the game
        let success = uploadViewModel.createGame(for: appContext.currentTeam)
        if success {
            // Reset state and return to initial view
            resetUploadState()
        }
    }
    
    private func switchToManualEntry() {
        // Switch to manual entry tab
        onSwitchToManual()
    }
    
    private func retakePhoto() {
        resetUploadState()
    }
    
    private func resetUploadState() {
        capturedImage = nil
        analysisResult = nil
        uploadState = .initial
        showingScoreConfirmation = false
        
        // Reset confirmation data
        confirmedTeamScore = 0
        confirmedOpponentScore = 0
        confirmedGameResult = .win
        confirmedOpponentName = ""
        confirmedGameDate = Date()
        confirmedGameTime = Date()
        confirmedLocation = ""
    }
}

// MARK: - Supporting Types

enum PhotoUploadState {
    case initial
    case processing
    case analysisComplete
    case error
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Theme.Colors.primary)
            .foregroundColor(.white)
            .cornerRadius(Theme.CornerRadius.md)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Theme.Colors.secondaryBackground)
            .foregroundColor(Theme.Colors.primaryText)
            .cornerRadius(Theme.CornerRadius.md)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

#Preview {
    UploadView()
        .environmentObject(AppContext(viewContext: PersistenceController.preview.container.viewContext))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 