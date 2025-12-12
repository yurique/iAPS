import SwiftUI

struct FoodItemCard: View {
    let foodItem: AnalysedFoodItem
    let onSelect: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Kopfbereich mit Tap-Gesture für Auswahl
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(foodItem.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    // Expand/Collapse Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(6)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                if let portion = foodItem.portionEstimateSize {
                    HStack(spacing: 8) {
                        PortionSizeBadge(
                            value: portion,
                            unit: foodItem.units.localizedAbbreviation,
                            color: .yellow
                        )

                        if let carbsPer100 = foodItem.carbsPer100 {
                            NutritionBadge(value: carbsPer100 / 100 * portion, unit: "g", label: "Carbs", color: .orange)
                        }
                        if let proteinPer100 = foodItem.proteinPer100, proteinPer100 > 0 {
                            NutritionBadge(value: proteinPer100 / 100 * portion, unit: "g", label: "Protein", color: .green)
                        }

                        if let fatPer100 = foodItem.fatPer100, fatPer100 > 0 {
                            NutritionBadge(value: fatPer100 / 100 * portion, unit: "g", label: "Fat", color: .blue)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let portionEstimate = foodItem.portionEstimate {
                        HStack {
                            Text("Portion:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(portionEstimate)
                                .font(.caption)

                            if let servingSize = foodItem.standardServingSize, let portion = foodItem.portionEstimateSize
                            {
                                Text("\(portion / servingSize, specifier: "%.1f") \(NSLocalizedString("servings", comment: ""))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let standardServingSize = foodItem.standardServingSize {
                        HStack {
                            Text("Standard serving:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(standardServingSize, specifier: "%.0f") \(foodItem.units.localizedAbbreviation)")
                                .font(.caption)
                        }
                        if let standardServing = foodItem.standardServing {
                            HStack {
                                Text(standardServing)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Button(action: onSelect) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                        Text("Add")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

//                if let standardName = foodItem.servingsStandard {
//                    HStack(alignment: .firstTextBaseline, spacing: 4) {
//                        Image(systemName: "text.alignleft")
//                            .font(.footnote)
//                            .foregroundColor(.secondary)
//                        Text(standardName)
//                            .font(.footnote)
//                            .italic()
//                            .foregroundColor(.secondary)
//                    }
//                    .padding(.top, 2)
//                }
            }

            // Erweiterter Bereich (expandable)
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Detaillierte Nährwerte
                    if let portion = foodItem.portionEstimateSize {
                        HStack {
                            if let caloriesPer100 = foodItem.caloriesPer100, caloriesPer100 > 0 {
                                NutritionBadge(
                                    value: caloriesPer100 / 100 * portion,
                                    unit: "kcal",
                                    label: "Calories",
                                    color: .red
                                )
                            }

                            if let fiberPer100 = foodItem.fiberPer100, fiberPer100 > 0 {
                                NutritionBadge(value: fiberPer100 / 100 * portion, unit: "g", label: "Fiber", color: .purple)
                            }

                            if let sugarsPer100 = foodItem.sugarsPer100, sugarsPer100 > 0 {
                                NutritionBadge(
                                    value: sugarsPer100 / 100 * portion,
                                    unit: "g",
                                    label: "Sugars",
                                    color: .purple
                                )
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if let preparation = foodItem.preparationMethod, !preparation.isEmpty {
                            HStack(alignment: .top) {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Preparation: \(preparation)")
                                    .font(.caption)
                            }
                        }

                        if let visualCues = foodItem.visualCues, !visualCues.isEmpty {
                            HStack(alignment: .top) {
                                Image(systemName: "eye.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("Visual Cues: \(visualCues)")
                                    .font(.caption)
                            }
                        }

                        if let notes = foodItem.assessmentNotes, !notes.isEmpty {
                            HStack(alignment: .top) {
                                Image(systemName: "note.text")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                                Text("Notes: \(notes)")
                                    .font(.caption)
                            }
                        }
                    }
                    .foregroundColor(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private struct NutritionBadge: View {
        let value: Double
        let unit: String
        let label: String
        let color: Color
        let icon: String

        init(value: Double, unit: String, label: String, color: Color, icon: String? = nil) {
            self.value = value
            self.unit = unit
            self.label = label
            self.color = color
            self.icon = icon ?? ""
        }

        var body: some View {
            HStack(spacing: 4) {
                if !icon.isEmpty {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                VStack(spacing: 2) {
                    Text("\(value, specifier: "%.1f") \(NSLocalizedString(unit, comment: ""))")
                        .font(.system(size: 12, weight: .bold))
                    Text(NSLocalizedString(label, comment: ""))
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .cornerRadius(8)
        }
    }

    private struct PortionSizeBadge: View {
        let value: Double
        let unit: String
        let color: Color
        let icon: String

        init(value: Double, unit: String, color: Color, icon: String? = nil) {
            self.value = value
            self.unit = unit
            self.color = color
            self.icon = icon ?? ""
        }

        var body: some View {
            HStack(spacing: 4) {
                if !icon.isEmpty {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                VStack(spacing: 2) {
                    Text("\(value, specifier: "%.0f") \(NSLocalizedString(unit, comment: ""))")
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .cornerRadius(8)
        }
    }
}
