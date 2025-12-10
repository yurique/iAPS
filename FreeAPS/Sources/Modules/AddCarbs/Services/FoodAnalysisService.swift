import Foundation

protocol AnalysisServiceBase {}

protocol ImageAnalysisService: Sendable, AnalysisServiceBase {
    var needAggressiveImageCompression: Bool { get }

    func analyzeImage(
        prompt: String,
        images: [String],
        telemetryCallback: ((String) -> Void)?
    ) async throws -> FoodAnalysisResult
}

protocol TextAnalysisService: Sendable, AnalysisServiceBase {
    func analyzeText(
        prompt: String,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> [OpenFoodFactsProduct]
}

protocol BarcodeAnalysisService: Sendable, AnalysisServiceBase {
    func analyzeBarcode(
        barcode: String,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> OpenFoodFactsProduct
}

extension AnalysisServiceBase {
    func decode<T: Decodable>(
        _ content: String,
        as type: T.Type
    ) throws -> T {
        // 1. Remove markdown fences and stray backticks
        var cleanedContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 2. Remove UTF-8 BOM or invisible junk before first "{"
        if let braceIndex = cleanedContent.firstIndex(of: "{") {
            let prefix = cleanedContent[..<braceIndex]
            if prefix.contains(where: { !$0.isASCII }) {
                cleanedContent = String(cleanedContent[braceIndex...])
            }
        }

        // 3. Extract JSON substring between first "{" and last "}"
        let jsonString: String
        if let jsonStartRange = cleanedContent.range(of: "{"),
           let jsonEndRange = cleanedContent.range(of: "}", options: .backwards),
           jsonStartRange.lowerBound < jsonEndRange.upperBound
        {
            jsonString = String(cleanedContent[jsonStartRange.lowerBound ..< jsonEndRange.upperBound])
        } else {
            jsonString = cleanedContent
        }

        // 4. Fix common issue: remove trailing commas before }
        let fixedJson = jsonString.replacingOccurrences(
            of: ",\\s*}".replacingOccurrences(of: "\\", with: "\\\\"),
            with: "}"
        )

        // 5. Decode
        guard let jsonData = fixedJson.data(using: .utf8) else {
            print("❌ Failed to convert to Data. JSON was:\n\(fixedJson)")
            throw AIFoodAnalysisError.responseParsingFailed
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(type, from: jsonData)

        } catch {
            print("❌ JSON decode error: \(error)")
            print("❌ JSON content:\n\(fixedJson)")
            throw AIFoodAnalysisError.responseParsingFailed
        }
    }
}

extension TextAnalysisService {
    func toOpenFoodFactsProducts(
        model: AIModelBase,
        result: FoodAnalysisResult
    ) -> [OpenFoodFactsProduct] {
        let syntheticID = "\(model.rawValue)_\(Date.now.hashValue)"
        return result.foodItemsDetailed.map { item in
            var carbs: Double = 0
            var proteins: Double = 0
            var fat: Double = 0
            var calories: Double = 0
            var sugars: Double = 0
            var fiber: Double = 0

            if let portion = item.portionEstimateSize {
                if let carbsPer100 = item.carbsPer100 {
                    carbs = carbsPer100 / 100 * portion
                }
                if let proteinPer100 = item.proteinPer100 {
                    proteins = proteinPer100 / 100 * portion
                }
                if let fatPer100 = item.fatPer100 {
                    fat = fatPer100 / 100 * portion
                }
                if let caloriesPer100 = item.caloriesPer100 {
                    calories = caloriesPer100 / 100 * portion
                }
                if let sugarsPer100 = item.sugarsPer100 {
                    sugars = sugarsPer100 / 100 * portion
                }
                if let fiberPer100 = item.fiberPer100 {
                    fiber = fiberPer100 / 100 * portion
                }
            }

            let nutriments = Nutriments(
                carbohydrates: carbs,
                proteins: proteins,
                fat: fat,
                calories: calories,
                sugars: sugars,
                fiber: fiber
            )

            return OpenFoodFactsProduct(
                id: syntheticID,
                productName: item.name,
                brands: "AI Analysis",
                categories: nil,
                nutriments: nutriments,
                servingSize: item.standardServing ?? "1 serving",
                servingQuantity: 1.0, // TODO: what is this?
                imageURL: nil,
                imageFrontURL: nil,
                code: nil,
                dataSource: .aiAnalysis
            )
        }
    }
}
