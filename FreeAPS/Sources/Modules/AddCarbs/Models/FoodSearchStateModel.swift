import Combine
import SwiftUI

final class FoodSearchStateModel: ObservableObject {
    @Published var foodSearchText = ""
    @Published var isBarcode = false

    @Published var searchResults: [OpenFoodFactsProduct] = []
    @Published var aiSearchResults: [AIFoodItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?

    init() {
        $foodSearchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self else {
                    return
                }
                let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
                self.isBarcode = trimmedQuery.isNotEmpty && isBarcode(trimmedQuery)
            }
            .store(in: &cancellables)
    }

    deinit {
        searchTask?.cancel()
    }

    func enterBarcodeAndSearch(barcode: String) {
        foodSearchText = barcode
        searchByText(query: barcode)
    }

    func searchByText(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isNotEmpty else {
            searchResults = []
            aiSearchResults = []
            return
        }
        let isBarcode = isBarcode(trimmedQuery)

        searchTask?.cancel()
        isLoading = true
        errorMessage = nil

        searchTask = Task { @MainActor in
            Task { @MainActor in

                do {
                    if isBarcode {
                        if let product = try await ConfigurableAIService.shared.analyzeBarcode(
                            barcode: trimmedQuery,
                            telemetryCallback: nil
                        ) {
                            Task { @MainActor in
                                self.searchResults = [product]
                                print("✅ OpenFoodFacts found product: \(product.displayName)")
                                self.isLoading = false

                                print("🖼️ Barcode Product URLs: \(product.imageURL ?? "nil"), \(product.imageFrontURL ?? "nil")")
                            }
                        }

                    } else {
                        let openFoodProducts = try await ConfigurableAIService.shared.analyzeFoodQuery(
                            query: trimmedQuery,
                            telemetryCallback: nil
                        )

                        if !Task.isCancelled {
                            self.searchResults = openFoodProducts
                            self.isLoading = false
                            print("✅ Search completed: \(self.searchResults.count) results")
                        }
                    }
                } catch {
                    if !Task.isCancelled {
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                        self.searchResults = []
                        print("❌ Search failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    func addAISearchResults(_ results: [AIFoodItem]) {
        aiSearchResults = results
    }

    func clearAISearchResults() {
        aiSearchResults = []
    }

    private func isBarcode(_ str: String) -> Bool {
        let numericCharacterSet = CharacterSet.decimalDigits
        return str.unicodeScalars.allSatisfy { numericCharacterSet.contains($0) }
    }
}
