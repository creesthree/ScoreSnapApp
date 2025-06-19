//
//  OpponentNameField.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI

struct OpponentNameField: View {
    @Binding var opponentName: String
    let onValidationChange: (Bool) -> Void
    
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    
    private var isValid: Bool {
        let trimmed = opponentName.trimmed
        return !trimmed.isEmpty && trimmed.count <= 50
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Opponent Team")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
            
            TextField("Enter opponent team name", text: $opponentName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: opponentName) { _, newValue in
                    validateInput(newValue)
                }
            
            // Character count
            HStack {
                Spacer()
                Text("\(opponentName.count)/50")
                    .font(Theme.Typography.caption2)
                    .foregroundColor(opponentName.count > 45 ? Theme.Colors.warning : Theme.Colors.secondaryText)
            }
        }
        .alert("Invalid Opponent Name", isPresented: $showingValidationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(validationMessage)
        }
    }
    
    private func validateInput(_ input: String) {
        let trimmed = input.trimmed
        
        if trimmed.isEmpty {
            validationMessage = "Opponent name cannot be empty"
            showingValidationAlert = true
            onValidationChange(false)
        } else if trimmed.count > 50 {
            validationMessage = "Opponent name must be 50 characters or less"
            showingValidationAlert = true
            onValidationChange(false)
        } else {
            onValidationChange(true)
        }
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.lg) {
        OpponentNameField(
            opponentName: .constant("Lakers")
        ) { isValid in
            print("Validation: \(isValid)")
        }
        
        OpponentNameField(
            opponentName: .constant("")
        ) { isValid in
            print("Validation: \(isValid)")
        }
    }
    .padding()
} 