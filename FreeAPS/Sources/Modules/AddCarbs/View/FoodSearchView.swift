import Combine
import SwiftUI

struct FoodSearchView: View {
    @ObservedObject var state: FoodSearchStateModel
    var onSelect: (AIFoodItem, UIImage?) -> Void
    @Environment(\.dismiss) var dismiss

    // Navigation States
    @State private var navigateToBarcode = false
    @State private var navigateToAICamera = false

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
                .padding(.top, 12)

                if state.searchResults.isNotEmpty {
                    AIAnalysisResultsView(
                        analysisResults: state.searchResults,
                        onFoodItemSelected: { foodItem in
                            handleFoodItemSelection(foodItem, image: state.aiAnalysisRequest?.image)
                        },
                        onCompleteMealSelected: { totalMeal in
                            handleFoodItemSelection(totalMeal, image: state.aiAnalysisRequest?.image)
                        }
                    )
                    .padding(.top, 4)
                } else {
                    Spacer()
                }
            }

//            .navigationTitle("Food Search")
//            .navigationBarItems(trailing: Button("Done") { dismiss() })
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
                    onImageCaptured: { image in
                        navigateToAICamera = false
                        state.navigateToAIAnalysis = AnalysisRoute(request: AnalysisRequest.image(image))
                    },
                    onCancel: { navigateToAICamera = false }
                )
            }
            .navigationDestination(item: $state.navigateToAIAnalysis) { analysisRoute in
                AIProgressView(
                    analysisRequest: analysisRoute.request,
                    onFoodAnalyzed: { analysisResult, analysisRequest in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            handleAIAnalysis(analysisResult, image: analysisRequest.image)
                            state.aiAnalysisRequest = analysisRequest
                            navigateToAICamera = false
                            state.navigateToAIAnalysis = nil
                        }
                    },
                    onCancel: {
                        navigateToAICamera = false
                        state.navigateToAIAnalysis = nil
                    }
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

    private func handleAIAnalysis(_ analysisResult: FoodAnalysisResult, image _: UIImage?) { // ✅ Parameter name korrigiert
        state.searchResults = state.searchResults + [analysisResult]

        // TODO: to ai food items
//        let aiFoodItems = analysisResult.foodItemsDetailed.map { foodItem in
//            var carbs: Double = 0
//            var proteins: Double = 0
//            var fat: Double = 0
//            var calories: Double = 0
//
//            if let portion = foodItem.portionEstimateSize {
//                if let carbsPer100 = foodItem.carbsPer100 {
//                    carbs = carbsPer100 / 100 * portion
//                }
//                if let proteinPer100 = foodItem.proteinPer100 {
//                    proteins = proteinPer100 / 100 * portion
//                }
//                if let fatPer100 = foodItem.fatPer100 {
//                    fat = fatPer100 / 100 * portion
//                }
//                if let caloriesPer100 = foodItem.caloriesPer100 {
//                    calories = caloriesPer100 / 100 * portion
//                }
//            }
//
//            return AIFoodItem(
//                name: foodItem.name,
//                brand: nil,
//                calories: calories,
//                carbs: carbs,
//                protein: proteins,
//                fat: fat,
//                imageURL: nil
//            )
//        }
//        state.aiSearchResults = aiFoodItems
    }

    private func handleFoodItemSelection(_ foodItem: AIFoodItem, image: UIImage?) {
        onSelect(foodItem, image)
        dismiss()
    }
}
