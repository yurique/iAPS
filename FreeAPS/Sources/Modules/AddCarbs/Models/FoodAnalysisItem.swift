import Foundation

/// Individual food item analysis with detailed portion assessment
struct FoodItemAnalysis: JSON {
    let name: String
    let portionEstimate: String
    let standardServingSize: String?
    let servingsStandard: String?
    let servingMultiplier: Double
    let preparationMethod: String?
    let visualCues: String?
    let carbohydrates: Double
    let calories: Double?
    let fat: Double?
    let fiber: Double?
    let protein: Double?
    let assessmentNotes: String?
}

extension FoodItemAnalysis: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let name = try container.decode(String.self, forKey: .name)
        let portionEstimate = try container.decodeTrimmedNonEmpty(forKey: .portionEstimate)
        let standardServingSize = try container.decodeTrimmedIfPresent(forKey: .standardServingSize)
        let servingsStandard = try container.decodeTrimmedIfPresent(forKey: .servingsStandard)
        let servingMultiplier = try container.decodeNumberIfPresent(forKey: .servingMultiplier) ?? 1.0
        let preparationMethod = try container.decodeTrimmedIfPresent(forKey: .preparationMethod)
        let visualCues = try container.decodeTrimmedIfPresent(forKey: .visualCues)
        let carbohydrates = try container.decodeNumberIfPresent(forKey: .carbohydrates) ?? 0
        let calories = try container.decodeNumberIfPresent(forKey: .calories)
        let fat = try container.decodeNumberIfPresent(forKey: .fat)
        let fiber = try container.decodeNumberIfPresent(forKey: .fiber)
        let protein = try container.decodeNumberIfPresent(forKey: .protein)
        let assessmentNotes = try container.decodeTrimmedIfPresent(forKey: .assessmentNotes)

        self = FoodItemAnalysis(
            name: name,
            portionEstimate: portionEstimate,
            standardServingSize: standardServingSize,
            servingsStandard: servingsStandard,
            servingMultiplier: servingMultiplier,
            preparationMethod: preparationMethod,
            visualCues: visualCues,
            carbohydrates: carbohydrates,
            calories: calories,
            fat: fat,
            fiber: fiber,
            protein: protein,
            assessmentNotes: assessmentNotes
        )
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case portionEstimate = "portion_estimate"
        case standardServingSize = "standard_serving_size"
        case servingsStandard = "serving_standard"
        case servingMultiplier = "serving_multiplier"
        case preparationMethod = "preparation_method"
        case visualCues = "visual_cues"
        case carbohydrates
        case calories
        case fat
        case fiber
        case protein
        case assessmentNotes = "assessment_notes"
    }
}
