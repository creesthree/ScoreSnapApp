//
//  SettingsView.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/19/25.
//

import SwiftUI
import CoreData
import AVFoundation
import PhotosUI
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject var appContext: AppContext
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var servicesManager = ServicesManager()
    @State private var showingResetAlert = false
    @State private var showingPermissionSettings = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile Section
                Section("Profile") {
                    if let player = appContext.currentPlayer {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundColor(Theme.Colors.primary)
                            
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(player.name ?? "Unknown Player")
                                    .font(Theme.Typography.headline)
                                    .foregroundColor(Theme.Colors.primaryText)
                                
                                if let team = appContext.currentTeam {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        Circle()
                                            .fill(Theme.TeamColors.color(from: team.teamColor))
                                            .frame(width: 12, height: 12)
                                        Text(team.name ?? "Unknown Team")
                                            .font(Theme.Typography.caption)
                                            .foregroundColor(Theme.Colors.secondaryText)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                    }
                }
                
                // Permissions Section
                Section("Permissions") {
                    PermissionRow(
                        title: "Camera",
                        description: "Take photos of scoreboards",
                        status: getPermissionStatusText(servicesManager.photoService.cameraPermissionStatus),
                        isGranted: servicesManager.photoService.cameraPermissionStatus == .authorized
                    ) {
                        showingPermissionSettings = true
                    }
                    
                    PermissionRow(
                        title: "Photo Library",
                        description: "Select existing photos",
                        status: getPhotoLibraryStatusText(servicesManager.photoService.photoLibraryPermissionStatus),
                        isGranted: servicesManager.photoService.photoLibraryPermissionStatus == .authorized || servicesManager.photoService.photoLibraryPermissionStatus == .limited
                    ) {
                        showingPermissionSettings = true
                    }
                    
                    PermissionRow(
                        title: "Location",
                        description: "Record game locations",
                        status: getLocationStatusText(servicesManager.locationService.authorizationStatus),
                        isGranted: servicesManager.locationService.authorizationStatus == .authorizedWhenInUse || servicesManager.locationService.authorizationStatus == .authorizedAlways
                    ) {
                        showingPermissionSettings = true
                    }
                }
                
                // App Management Section
                Section("App Management") {
                    Button("Reset Setup") {
                        showingResetAlert = true
                    }
                    .foregroundColor(.red)
                }
                
                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Reset Setup", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetSetup()
            }
        } message: {
            Text("This will reset your setup and you'll need to go through the onboarding process again. This action cannot be undone.")
        }
        .sheet(isPresented: $showingPermissionSettings) {
            PermissionSettingsView(servicesManager: servicesManager)
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
    
    private func getPhotoLibraryStatusText(_ status: PHAuthorizationStatus) -> String {
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
    
    private func getLocationStatusText(_ status: CLAuthorizationStatus) -> String {
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
    
    private func resetSetup() {
        appContext.resetSetup()
        dismiss()
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let status: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.primaryText)
                    
                    Text(description)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                    Text(status)
                        .font(Theme.Typography.caption)
                        .foregroundColor(isGranted ? .green : Theme.Colors.secondaryText)
                    
                    if isGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PermissionSettingsView: View {
    @ObservedObject var servicesManager: ServicesManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: Theme.Spacing.xl) {
                Image(systemName: "gear")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.primary)
                
                VStack(spacing: Theme.Spacing.md) {
                    Text("Permission Settings")
                        .font(Theme.Typography.title1)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.primaryText)
                    
                    Text("To change permissions, go to Settings > ScoreSnap and adjust the permissions there.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                Button("Open Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .padding(Theme.Spacing.xl)
            .navigationTitle("Permission Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppContext(viewContext: PersistenceController.preview.container.viewContext))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 