import Combine
import SwiftUI

struct AnalysisRoute: Identifiable, Hashable {
    let id = UUID()
    let request: AnalysisRequest

    static func == (lhs: AnalysisRoute, rhs: AnalysisRoute) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

final class FoodSearchStateModel: ObservableObject {
    @Published var foodSearchText = ""
    @Published var isBarcode = false

    @Published var navigateToAIAnalysis: AnalysisRoute? = nil
    @Published var searchResults: [FoodAnalysisResult] = []
    @Published var aiAnalysisRequest: AnalysisRequest?

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
            return
        }
        let isBarcode = isBarcode(trimmedQuery)

        searchTask?.cancel()
        errorMessage = nil

        searchTask = Task { @MainActor in
            do {
                if isBarcode {
                    isLoading = true
                    let result = try await ConfigurableAIService.shared.analyzeBarcode(
                        trimmedQuery,
                        telemetryCallback: nil
                    )
                    Task { @MainActor in
                        self.searchResults = [result] + self.searchResults
                        self.isLoading = false
                    }

                } else {
                    switch UserDefaults.standard.textSearchProvider {
                    case .aiModel:
                        isLoading = false
                        navigateToAIAnalysis = AnalysisRoute(request: .query(trimmedQuery))
                        return
                    default:
                        isLoading = true
                        let result = try await ConfigurableAIService.shared.analyzeFoodQuery(
                            trimmedQuery,
                            telemetryCallback: nil
                        )

                        if !Task.isCancelled {
                            self.searchResults = [result] + self.searchResults
                            self.isLoading = false
                        }
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

    private func isBarcode(_ str: String) -> Bool {
        let numericCharacterSet = CharacterSet.decimalDigits
        return str.unicodeScalars.allSatisfy { numericCharacterSet.contains($0) }
    }
}
