import SwiftUI

struct AIAnalysisResultsView: View {
    let analysisResult: FoodAnalysisResult
    let onFoodItemSelected: (AIFoodItem) -> Void
    let onCompleteMealSelected: (AIFoodItem) -> Void

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

                            let totalMeal = AIFoodItem(
                                name: mealName,
                                brand: nil,
                                calories: analysisResult.totalCalories,
                                carbs: analysisResult.totalCarbs,
                                protein: analysisResult.totalProtein,
                                fat: analysisResult.totalFat,
                                imageURL: analysisResult.foodItemsDetailed.count == 1 ? analysisResult.foodItemsDetailed.first?
                                    .imageURL : nil,
                                source: analysisResult.source
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
                            value: analysisResult.totalCarbs,
                            unit: "g",
                            label: "Carbs",
                            color: .orange
                        )

                        if analysisResult.totalProtein != 0 {
                            NutritionSummaryBadge(value: analysisResult.totalProtein, unit: "g", label: "Protein", color: .green)
                        }

                        if analysisResult.totalFat != 0 {
                            NutritionSummaryBadge(value: analysisResult.totalFat, unit: "g", label: "Fat", color: .loopRed)
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
                        let selectedFood = AIFoodItem(
                            name: foodItem.name ?? "Product without name",
                            brand: foodItem.brand,
                            calories: foodItem.caloriesInThisPortion ?? 0,
                            carbs: foodItem.carbsInThisPortion ?? 0,
                            protein: foodItem.proteinInThisPortion ?? 0,
                            fat: foodItem.fatInThisPortion ?? 0,
                            imageURL: foodItem.imageURL,
                            source: foodItem.source
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
