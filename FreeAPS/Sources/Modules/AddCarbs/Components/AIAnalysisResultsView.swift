import SwiftUI

struct AIAnalysisResultsView: View {
    let analysisResult: FoodAnalysisResult
    let onFoodItemSelected: (FoodItem) -> Void
    let onCompleteMealSelected: (FoodItem) -> Void

    private var totalCarbs: Double {
        var totalCarbs: Double = 0
        for item in analysisResult.foodItemsDetailed {
            if let portion = item.portionEstimateSize {
                if let carbsPer100 = item.carbsPer100 {
                    totalCarbs += carbsPer100 / 100 * portion
                }
            }
        }
        return totalCarbs
    }

    private var totalFat: Double {
        var totalFat: Double = 0
        for item in analysisResult.foodItemsDetailed {
            if let portion = item.portionEstimateSize {
                if let fatPer100 = item.fatPer100 {
                    totalFat += fatPer100 / 100 * portion
                }
            }
        }
        return totalFat
    }

    private var totalProtein: Double {
        var totalProtein: Double = 0
        for item in analysisResult.foodItemsDetailed {
            if let portion = item.portionEstimateSize {
                if let proteinPer100 = item.proteinPer100 {
                    totalProtein += proteinPer100 / 100 * portion
                }
            }
        }
        return totalProtein
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("🧠 AI Food analysis")
                    .font(.title2)
                    .fontWeight(.bold)

                if let description = analysisResult.overallDescription {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let confidence = analysisResult.confidence {
                    HStack {
                        Text("Confidence level:")
                        ConfidenceBadge(level: confidence)
                        Spacer()
                        //                    if let portions = analysisResult.totalFoodPortions {
                        //                        Text("\(portions) Portions")
                        //                            .font(.caption)
                        //                    }
                    }
                    .font(.subheadline)
                }
            }
            .padding(.horizontal)

            if analysisResult.foodItemsDetailed.count > 1 {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("📊 Total nutritional values of the meal")
                            .font(.headline)

                        Spacer()

                        Button(action: {
                            let mealName = analysisResult.foodItemsDetailed.count == 1 ?
                                analysisResult.foodItemsDetailed.first?.name ?? "Meal" :
                                "Complete Meal"

                            let totalMeal = FoodItem(
                                name: mealName,
                                carbs: Decimal(totalCarbs),
                                fat: Decimal(totalFat),
                                protein: Decimal(totalProtein),
                                source: "AI overall analysis • \(analysisResult.foodItemsDetailed.count) Food",
                                imageURL: nil
                            )
                            onCompleteMealSelected(totalMeal)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Add all")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("\(analysisResult.foodItemsDetailed.count) Food")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                        NutritionSummaryBadge(
                            value: totalCarbs,
                            unit: "g",
                            label: "Carbs",
                            color: .orange
                        )

                        if totalProtein != 0 {
                            NutritionSummaryBadge(value: totalProtein, unit: "g", label: "Protein", color: .green)
                        }

                        if totalFat != 0 {
                            NutritionSummaryBadge(value: totalFat, unit: "g", label: "Fat", color: .loopRed)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            if analysisResult.foodItemsDetailed.count > 1 {
                Text("🍽️ Separate Foods")
                    .font(.headline)
                    .padding(.horizontal)
            }

            ForEach(analysisResult.foodItemsDetailed, id: \.name) { foodItem in
                FoodItemCard(
                    foodItem: foodItem,
                    onSelect: {
                        var carbs: Double = 0
                        var proteins: Double = 0
                        var fat: Double = 0

                        if let portion = foodItem.portionEstimateSize {
                            if let carbsPer100 = foodItem.carbsPer100 {
                                carbs = carbsPer100 / 100 * portion
                            }
                            if let proteinPer100 = foodItem.proteinPer100 {
                                proteins = proteinPer100 / 100 * portion
                            }
                            if let fatPer100 = foodItem.fatPer100 {
                                fat = fatPer100 / 100 * portion
                            }
                        }

                        let selectedFood = FoodItem(
                            name: foodItem.name ?? "Product without name",
                            carbs: Decimal(carbs),
                            fat: Decimal(fat),
                            protein: Decimal(proteins),
                            source: "AI Analysis",
                            imageURL: nil
                        )
                        onFoodItemSelected(selectedFood)
                    }
                )
            }

            if let diabetesInfo = analysisResult.diabetesConsiderations {
                VStack(alignment: .leading, spacing: 8) {
                    Label("💉 Diabetes recommendations", systemImage: "cross.case.fill")
                        .font(.headline)
                    Text(diabetesInfo)
                        .font(.subheadline)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            if let notes = analysisResult.notes {
                VStack(alignment: .leading, spacing: 8) {
                    Label("📝 Notes", systemImage: "note.text")
                        .font(.headline)
                    Text(notes)
                        .font(.subheadline)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}
