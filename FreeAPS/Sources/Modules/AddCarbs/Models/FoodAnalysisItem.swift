import Foundation

enum MealUnits: String, Codable {
    case grams
    case milliliters

    var localizedAbbreviation: String {
        switch self {
        case .grams: NSLocalizedString("g", comment: "abbreviation for grams")
        case .milliliters: NSLocalizedString("ml", comment: "abbreviation for milliliters")
        }
    }
}

/// Individual food item analysis with detailed portion assessment
struct AnalysedFoodItem {
    let name: String?
    let portionEstimate: String?
    let portionEstimateSize: Double?
    let standardServing: String?
    let standardServingSize: Double?
    let units: MealUnits?
//    let servingsStandard: String?
//    let servingMultiplier: Double
    let preparationMethod: String?
    let visualCues: String?
//    let carbohydrates: Double
//    let calories: Double?
//    let fat: Double?
//    let fiber: Double?
//    let protein: Double?
//    let sugars: Double?
    let caloriesPer100: Double?
    let carbsPer100: Double?
    let fatPer100: Double?
    let fiberPer100: Double?
    let proteinPer100: Double?
    let sugarsPer100: Double?

    let assessmentNotes: String?

    let imageURL: String?
    let imageFrontURL: String?

    init(
        name: String? = nil,
        portionEstimate: String? = nil,
        portionEstimateSize: Double? = nil,
        standardServing: String? = nil,
        standardServingSize: Double? = nil,
        units: MealUnits? = nil,
        preparationMethod: String? = nil,
        visualCues: String? = nil,
        caloriesPer100: Double? = nil,
        carbsPer100: Double? = nil,
        fatPer100: Double? = nil,
        fiberPer100: Double? = nil,
        proteinPer100: Double? = nil,
        sugarsPer100: Double? = nil,
        assessmentNotes: String? = nil,
        imageURL: String? = nil,
        imageFrontURL: String? = nil

    ) {
        self.name = name
        self.portionEstimate = portionEstimate
        self.portionEstimateSize = portionEstimateSize
        self.standardServing = standardServing
        self.standardServingSize = standardServingSize
        self.units = units
        self.preparationMethod = preparationMethod
        self.visualCues = visualCues
        self.caloriesPer100 = caloriesPer100
        self.carbsPer100 = carbsPer100
        self.fatPer100 = fatPer100
        self.fiberPer100 = fiberPer100
        self.proteinPer100 = proteinPer100
        self.sugarsPer100 = sugarsPer100
        self.assessmentNotes = assessmentNotes
        self.imageURL = imageURL
        self.imageFrontURL = imageFrontURL
    }
}

extension AnalysedFoodItem: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let name = try container.decode(String.self, forKey: .name)
        let portionEstimate = try container.decodeTrimmedIfPresent(forKey: .portionEstimate)
        let portionEstimateSize = try container.decodeNumberIfPresent(forKey: .portionEstimateSize)
        let standardServing = try container.decodeTrimmedIfPresent(forKey: .standardServing)
        let standardServingSize = try container.decodeNumberIfPresent(forKey: .standardServingSize)
        let units = try container.decodeIfPresent(MealUnits.self, forKey: .units) ?? .grams
//        let servingsStandard = try container.decodeTrimmedIfPresent(forKey: .servingsStandard)
//        let servingMultiplier = try container.decodeNumberIfPresent(forKey: .servingMultiplier) ?? 1.0
        let preparationMethod = try container.decodeTrimmedIfPresent(forKey: .preparationMethod)
        let visualCues = try container.decodeTrimmedIfPresent(forKey: .visualCues)
        let carbsPer100 = try container.decodeNumberIfPresent(forKey: .carbsPer100)
        let caloriesPer100 = try container.decodeNumberIfPresent(forKey: .caloriesPer100)
        let fatPer100 = try container.decodeNumberIfPresent(forKey: .fatPer100)
        let fiberPer100 = try container.decodeNumberIfPresent(forKey: .fiberPer100)
        let proteinPer100 = try container.decodeNumberIfPresent(forKey: .proteinPer100)
        let sugarsPer100 = try container.decodeNumberIfPresent(forKey: .sugarsPer100)
        let assessmentNotes = try container.decodeTrimmedIfPresent(forKey: .assessmentNotes)

        self = AnalysedFoodItem(
            name: name,
            portionEstimate: portionEstimate,
            portionEstimateSize: portionEstimateSize,
            standardServing: standardServing,
            standardServingSize: standardServingSize,
            units: units,
//            servingsStandard: servingsStandard,
//            servingMultiplier: servingMultiplier,
            preparationMethod: preparationMethod,
            visualCues: visualCues,
            caloriesPer100: caloriesPer100,
            carbsPer100: carbsPer100,
            fatPer100: fatPer100,
            fiberPer100: fiberPer100,
            proteinPer100: proteinPer100,
            sugarsPer100: sugarsPer100,
            assessmentNotes: assessmentNotes
        )
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case portionEstimate = "portion_estimate"
        case portionEstimateSize = "portion_estimate_size"
        case standardServing = "standard_serving"
        case standardServingSize = "standard_serving_size"
        case units
//        case servingsStandard = "serving_standard"
//        case servingMultiplier = "serving_multiplier"
        case preparationMethod = "preparation_method"
        case visualCues = "visual_cues"
//        case carbohydrates
//        case calories
//        case fat
//        case fiber
//        case protein
//        case sugars
        case caloriesPer100 = "calories_per_100"
        case carbsPer100 = "carbs_per_100"
        case fatPer100 = "fat_per_100"
        case fiberPer100 = "fiber_per_100"
        case proteinPer100 = "protein_per_100"
        case sugarsPer100 = "sugars_per_100"

        case assessmentNotes = "assessment_notes"
    }
}

extension AnalysedFoodItem {
    private static var fields: [AnalysedFoodItem.CodingKeys: Any] {
        [
            .name: "specific food name with preparation details",
            .units: "string enum; one of: 'grams' or 'milliliters'; as appropriate for this meal; do NOT translate!",
            .standardServing: "description of a standard serving, if available",
            .standardServingSize: "decimal, standard serving size based on NUTRITION_AUTHORITY standard, in grams or milliliters; do not include unit; do not include the name of the standard",
            .caloriesPer100: "decimal, kcal of carbohydrates per 100 grams or milliliters",
            .carbsPer100: "decimal, grams of carbohydrates per 100 grams or milliliters",
            .fatPer100: "decimal, grams of fat per 100 grams or milliliters",
            .fiberPer100: "decimal, grams of fiber per 100 grams or milliliters",
            .proteinPer100: "decimal, grams of protein per 100 grams or milliliters",
            .sugarsPer100: "decimal, grams of added sugars per 100 grams or milliliters"
        ]
    }

    static var schemaVisual: [String: Any] {
        var fields = self.fields
        fields[.portionEstimate] = "portion desription with visual references"
        fields[.portionEstimateSize] = "decimal, exact portion size, in grams or milliliters; do not include unit;"
        fields[.visualCues] = "visual elements analyzed"
        fields[.preparationMethod] = "cooking details observed"
        fields[.assessmentNotes] =
            "Explain how you calculated this specific portion size, what visual references you used for measurement, and how you determined the serving multiplier. Write in natural, conversational language."

        var dict: [String: Any] = [:]
        for (key, value) in fields {
            dict[key.rawValue] = value
        }
        return dict
    }

    static var schemaText: [String: Any] {
        var fields = self.fields
        fields[.portionEstimateSize] =
            "decimal, assume the portion matches the standard serving size, in grams or milliliters; do not include unit;"

        var dict: [String: Any] = [:]
        for (key, value) in fields {
            dict[key.rawValue] = value
        }
        return dict
    }
}
