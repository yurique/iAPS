import Combine
import SwiftUI

struct FoodSearchView: View {
    @ObservedObject var state: FoodSearchStateModel
    var onSelect: (FoodItem, UIImage?) -> Void
    @Environment(\.dismiss) var dismiss

    // Navigation States
    @State private var navigateToBarcode = false
    @State private var navigateToAICamera = false
    @State private var showingAIAnalysisResults = false
    @State private var aiAnalysisResult: FoodAnalysisResult?
    @State private var aiAnalysisImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack {
                HStack(spacing: 8) {
                    ZStack(alignment: .trailing) {
                        TextField("Food Search...", text: $state.foodSearchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .submitLabel(.search)
                            .onSubmit {
                                state.searchByText(query: state.foodSearchText)
                            }

                        if state.isBarcode {
                            Text("barcode")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .padding(.trailing, 6)
                        }
                    }

                    Button {
                        navigateToBarcode = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Button {
                        navigateToAICamera = true
                    } label: {
                        Image(systemName: "camera")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .padding(8)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(8)
                            .foregroundColor(.purple)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                ScrollView {
                    if showingAIAnalysisResults, let result = aiAnalysisResult {
                        AIAnalysisResultsView(
                            analysisResult: result,
                            onFoodItemSelected: { foodItem in
                                let selectedFood = foodItem
//                                FoodItem(
//                                    name: foodItem.name,
//                                    carbs: foodItem.carbs,
//                                    fat: foodItem.fat,
//                                    protein: foodItem.protein,
//                                    source: "AI Analysis",
//                                    imageURL: nil
//                                )
                                handleFoodItemSelection(selectedFood, image: aiAnalysisImage)
                            },
                            onCompleteMealSelected: { totalMeal in
                                onSelect(totalMeal, aiAnalysisImage)
                                dismiss()
                            }
                        )
                    } else {
                        FoodSearchResultsView(
                            searchResults: state.searchResults,
                            aiSearchResults: state.aiSearchResults,
                            isSearching: state.isLoading,
                            errorMessage: state.errorMessage,
                            onProductSelected: { selectedProduct in
                                let foodItem = selectedProduct.toFoodItem()
                                handleFoodItemSelection(foodItem, image: nil)
                            },
                            onAIProductSelected: { aiProduct in
                                let foodItem = FoodItem(
                                    name: aiProduct.name,
                                    carbs: Decimal(aiProduct.carbs),
                                    fat: Decimal(aiProduct.fat),
                                    protein: Decimal(aiProduct.protein),
                                    source: "AI Analyse",
                                    imageURL: aiProduct.imageURL
                                )
                                handleFoodItemSelection(foodItem, image: nil)
                            }
                        )
                    }
                }
                .padding(.top, 8)
            }

            .navigationTitle("Food Search")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
            .navigationDestination(isPresented: $navigateToBarcode) {
                BarcodeScannerView(
                    onBarcodeScanned: { barcode in
                        handleBarcodeScan(barcode)
                        navigateToBarcode = false
                    },
                    onCancel: { navigateToBarcode = false }
                )
            }
            .navigationDestination(isPresented: $navigateToAICamera) {
                AICameraView(
                    onFoodAnalyzed: { analysisResult, image in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            handleAIAnalysis(analysisResult, image: image)
                            navigateToAICamera = false
                        }
                    },
                    onCancel: { navigateToAICamera = false }
                )
            }
        }.background(Color(.systemBackground))
    }

    private func handleBarcodeScan(_ barcode: String) {
        print("📦 Barcode scanned: \(barcode)")
        navigateToBarcode = false
        state.enterBarcodeAndSearch(barcode: barcode)
        print("🔍 Search for Barcode: \(barcode)")
    }

    private func handleAIAnalysis(_ analysisResult: FoodAnalysisResult, image: UIImage?) { // ✅ Parameter name korrigiert
        aiAnalysisResult = analysisResult
        showingAIAnalysisResults = true
        aiAnalysisImage = image // ✅ Bild speichern

        let aiFoodItems = analysisResult.foodItemsDetailed.map { foodItem in
            var carbs: Double = 0
            var proteins: Double = 0
            var fat: Double = 0
            var calories: Double = 0

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
                if let caloriesPer100 = foodItem.caloriesPer100 {
                    calories = caloriesPer100 / 100 * portion
                }
            }

            return AIFoodItem(
                name: foodItem.name,
                brand: nil,
                calories: calories,
                carbs: carbs,
                protein: proteins,
                fat: fat,
                imageURL: nil
            )
        }
        state.aiSearchResults = aiFoodItems
    }

    private func handleFoodItemSelection(_ foodItem: FoodItem, image: UIImage?) {
        onSelect(foodItem, image)
        dismiss()
    }
}
