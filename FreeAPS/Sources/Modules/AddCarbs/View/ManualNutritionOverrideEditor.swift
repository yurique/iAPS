import Foundation
import SwiftUI

struct ManualNutritionOverrideEditor: View {
    @ObservedObject var state: FoodSearchStateModel
    @Environment(\.dismiss) private var dismiss

    @State private var editedCarbs: String = ""
    @State private var editedProtein: String = ""
    @State private var editedFat: String = ""
    @State private var editedFiber: String = ""
    @State private var editedSugars: String = ""

    @FocusState private var focusedField: NutritionField?

    enum NutritionField {
        case carbs
        case protein
        case fat
        case fiber
        case sugars
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 0) {
                            NutritionOverrideRow(
                                label: "Carbs",
                                text: $editedCarbs,
                                unit: "g",
                                placeholder: formatDecimal(state.searchResultsState.baseTotalCarbs),
                                focusedField: $focusedField,
                                fieldTag: .carbs
                            )
                            Divider()
                            NutritionOverrideRow(
                                label: "Protein",
                                text: $editedProtein,
                                unit: "g",
                                placeholder: formatDecimal(state.searchResultsState.baseTotalProtein),
                                focusedField: $focusedField,
                                fieldTag: .protein
                            )
                            Divider()
                            NutritionOverrideRow(
                                label: "Fat",
                                text: $editedFat,
                                unit: "g",
                                placeholder: formatDecimal(state.searchResultsState.baseTotalFat),
                                focusedField: $focusedField,
                                fieldTag: .fat
                            )
                            Divider()
                            NutritionOverrideRow(
                                label: "Fiber",
                                text: $editedFiber,
                                unit: "g",
                                placeholder: formatDecimal(state.searchResultsState.baseTotalFiber),
                                focusedField: $focusedField,
                                fieldTag: .fiber
                            )
                            Divider()
                            NutritionOverrideRow(
                                label: "Sugars",
                                text: $editedSugars,
                                unit: "g",
                                placeholder: formatDecimal(state.searchResultsState.baseTotalSugars),
                                focusedField: $focusedField,
                                fieldTag: .sugars
                            )
                        }
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)

                        Button(role: .destructive) {
                            // Reset all overrides to nil
                            state.searchResultsState.carbsOverride = nil
                            state.searchResultsState.proteinOverride = nil
                            state.searchResultsState.fatOverride = nil
                            state.searchResultsState.fiberOverride = nil
                            state.searchResultsState.sugarsOverride = nil
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                }

                // Action buttons at bottom
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)

                    Button("Save") {
                        saveChanges()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
            }
            .navigationTitle("Edit Totals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button {
                            focusedField = nil
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .onAppear {
            initializeValues()
        }
        .onDisappear {
            focusedField = nil
        }
    }

    // Calculate calories from current macro values (4 cal/g for carbs and protein, 9 cal/g for fat)
    private var calculatedCalories: Decimal {
        let carbs = parseDecimal(editedCarbs) ?? state.searchResultsState.baseTotalCarbs
        let protein = parseDecimal(editedProtein) ?? state.searchResultsState.baseTotalProtein
        let fat = parseDecimal(editedFat) ?? state.searchResultsState.baseTotalFat

        return (carbs * 4) + (protein * 4) + (fat * 9)
    }

    private func initializeValues() {
        // Only populate fields if user has already set overrides (non-nil)
        // Otherwise leave empty to show placeholder
        if let override = state.searchResultsState.carbsOverride {
            let total = state.searchResultsState.baseTotalCarbs + override
            editedCarbs = formatDecimal(total)
        }
        if let override = state.searchResultsState.proteinOverride {
            let total = state.searchResultsState.baseTotalProtein + override
            editedProtein = formatDecimal(total)
        }
        if let override = state.searchResultsState.fatOverride {
            let total = state.searchResultsState.baseTotalFat + override
            editedFat = formatDecimal(total)
        }
        if let override = state.searchResultsState.fiberOverride {
            let total = state.searchResultsState.baseTotalFiber + override
            editedFiber = formatDecimal(total)
        }
        if let override = state.searchResultsState.sugarsOverride {
            let total = state.searchResultsState.baseTotalSugars + override
            editedSugars = formatDecimal(total)
        }
    }

    private func formatDecimal(_ value: Decimal) -> String {
        let nsNumber = NSDecimalNumber(decimal: value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false // Don't use thousands separators
        return formatter.string(from: nsNumber) ?? "0"
    }

    private func parseDecimal(_ text: String) -> Decimal? {
        // If text is empty, return nil
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            return nil
        }

        // Remove any grouping separators (spaces, commas in some locales)
        let cleaned = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "\u{202F}", with: "") // non-breaking space
            .replacingOccurrences(of: "\u{00A0}", with: "") // narrow no-break space

        return Decimal(string: cleaned)
    }

    private func saveChanges() {
        // Parse the user-entered values (nil if empty)
        let newCarbs = parseDecimal(editedCarbs)
        let newProtein = parseDecimal(editedProtein)
        let newFat = parseDecimal(editedFat)
        let newFiber = parseDecimal(editedFiber)
        let newSugars = parseDecimal(editedSugars)

        // Calculate overrides as deltas from base
        // If user value is nil (empty field), set override to nil
        state.searchResultsState.carbsOverride = newCarbs.map { $0 - state.searchResultsState.baseTotalCarbs }
        state.searchResultsState.proteinOverride = newProtein.map { $0 - state.searchResultsState.baseTotalProtein }
        state.searchResultsState.fatOverride = newFat.map { $0 - state.searchResultsState.baseTotalFat }
        state.searchResultsState.fiberOverride = newFiber.map { $0 - state.searchResultsState.baseTotalFiber }
        state.searchResultsState.sugarsOverride = newSugars.map { $0 - state.searchResultsState.baseTotalSugars }

        // Calories are automatically calculated from macros in totalCalories computed property
        // No need to set anything here - the state handles it automatically

        dismiss()
    }
}

private struct NutritionOverrideRow: View {
    let label: String
    @Binding var text: String
    let unit: String
    let placeholder: String
    @FocusState.Binding var focusedField: ManualNutritionOverrideEditor.NutritionField?
    let fieldTag: ManualNutritionOverrideEditor.NutritionField

    var body: some View {
        HStack(spacing: 8) {
            Text(NSLocalizedString(label, comment: ""))
                .font(.subheadline)
                .foregroundColor(.primary.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Custom text field with more visible placeholder
            ZStack(alignment: .trailing) {
                // Background for the text field
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color(.separator), lineWidth: 0.5)
                    )

                if text.isEmpty {
                    Text(placeholder)
                        .font(.subheadline)
                        .foregroundColor(.primary.opacity(0.5))
                        .padding(.trailing, 8)
                }

                TextField("", text: $text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: fieldTag)
                    .padding(.horizontal, 8)
                    .background(Color.clear)
            }
            .frame(width: 100, height: 32)

            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
                .frame(width: 28, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
