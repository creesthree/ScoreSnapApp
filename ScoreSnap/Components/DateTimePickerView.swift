//
//  DateTimePickerView.swift
//  ScoreSnap
//
//  Created by CHRISTOPHER LAU on 6/18/25.
//

import SwiftUI

struct DateTimePickerView: View {
    @Binding var gameDate: Date
    @Binding var gameTime: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Game Date & Time")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
            
            VStack(spacing: Theme.Spacing.sm) {
                // Date Picker
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
                
                // Time Picker
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
    }
}

struct QuickDateOptions: View {
    let onDateSelected: (Date) -> Void
    
    private var quickDates: [(label: String, date: Date)] {
        let now = Date()
        let calendar = Calendar.current
        
        return [
            ("Today", now),
            ("Yesterday", calendar.date(byAdding: .day, value: -1, to: now) ?? now),
            ("Last Week", calendar.date(byAdding: .day, value: -7, to: now) ?? now),
            ("Last Month", calendar.date(byAdding: .month, value: -1, to: now) ?? now)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Quick Select")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
            
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(quickDates, id: \.label) { quickDate in
                    Button(action: {
                        onDateSelected(quickDate.date)
                    }) {
                        Text(quickDate.label)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.primary)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                                    .fill(Theme.Colors.primary.opacity(0.1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

#Preview {
    DateTimePickerView(
        gameDate: .constant(Date()),
        gameTime: .constant(Date())
    )
    .padding()
} 