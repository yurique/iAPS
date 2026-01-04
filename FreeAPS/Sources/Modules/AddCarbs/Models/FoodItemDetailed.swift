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

enum FoodItemSource {
    case aiPhoto
    case aiMenu
    case aiReceipe
    case aiText
    case search
    case barcode
    case manual
    case database

    var isAI: Bool {
        switch self {
        case .aiMenu,
             .aiPhoto,
             .aiReceipe,
             .aiText: true
        default: false
        }
    }
}

enum ConfidenceLevel: String, Codable, Identifiable, CaseIterable {
    case high
    case medium
    case low

    var id: ConfidenceLevel { self }
}

struct NutritionValues: Equatable {
    let calories: Decimal?
    let carbs: Decimal?
    let fat: Decimal?
    let fiber: Decimal?
    let protein: Decimal?
    let sugars: Decimal?
}

enum FoodNutrition: Equatable {
    case per100(NutritionValues)
    case perServing(NutritionValues)
}

struct FoodItemDetailed: Identifiable, Equatable {
    let id: UUID
    let name: String
    let standardName: String?
    let confidence: ConfidenceLevel?
    let brand: String?
    let portionSize: Decimal?
    let servingsMultiplier: Decimal?
    let standardServing: String?
    let standardServingSize: Decimal?
    let units: MealUnits?
    let preparationMethod: String?
    let visualCues: String?
    let glycemicIndex: Decimal?

    let nutrition: FoodNutrition

    let assessmentNotes: String?

    let imageURL: String?

    let tags: [String]?

    let source: FoodItemSource

    static func == (lhs: FoodItemDetailed, rhs: FoodItemDetailed) -> Bool {
        lhs.id == rhs.id &&
            lhs.name == rhs.name &&
            lhs.confidence == rhs.confidence &&
            lhs.brand == rhs.brand &&
            lhs.portionSize == rhs.portionSize &&
            lhs.servingsMultiplier == rhs.servingsMultiplier &&
            lhs.standardServing == rhs.standardServing &&
            lhs.standardServingSize == rhs.standardServingSize &&
            lhs.units == rhs.units &&
            lhs.preparationMethod == rhs.preparationMethod &&
            lhs.visualCues == rhs.visualCues &&
            lhs.glycemicIndex == rhs.glycemicIndex &&
            lhs.nutrition == rhs.nutrition &&
            lhs.assessmentNotes == rhs.assessmentNotes &&
            lhs.imageURL == rhs.imageURL &&
            lhs.tags == rhs.tags &&
            lhs.source == rhs.source
    }

    init(
        id: UUID? = nil,
        name: String,
        nutritionPer100: NutritionValues,
        portionSize: Decimal,
        confidence: ConfidenceLevel? = nil,
        brand: String? = nil,
        standardServing: String? = nil,
        standardServingSize: Decimal? = nil,
        units: MealUnits? = nil,
        preparationMethod: String? = nil,
        visualCues: String? = nil,
        glycemicIndex: Decimal? = nil,
        assessmentNotes: String? = nil,
        imageURL: String? = nil,
        standardName: String? = nil,
        tags: [String]? = nil,
        source: FoodItemSource
    ) {
        self.id = id ?? UUID()
        self.name = name
        self.standardName = standardName
        self.confidence = confidence
        self.brand = brand
        self.portionSize = portionSize
        servingsMultiplier = nil
        self.standardServing = standardServing
        self.standardServingSize = standardServingSize
        self.units = units
        self.preparationMethod = preparationMethod
        self.visualCues = visualCues
        self.glycemicIndex = glycemicIndex
        nutrition = .per100(nutritionPer100)
        self.assessmentNotes = assessmentNotes
        self.imageURL = imageURL
        self.tags = tags
        self.source = source
    }

    init(
        id: UUID? = nil,
        name: String,
        nutritionPerServing: NutritionValues,
        servingsMultiplier: Decimal,
        confidence: ConfidenceLevel? = nil,
        brand: String? = nil,
        standardServing: String? = nil,
        standardServingSize: Decimal? = nil,
        units: MealUnits? = nil,
        preparationMethod: String? = nil,
        visualCues: String? = nil,
        glycemicIndex: Decimal? = nil,
        assessmentNotes: String? = nil,
        imageURL: String? = nil,
        standardName: String? = nil,
        tags: [String]? = nil,
        source: FoodItemSource
    ) {
        self.id = id ?? UUID()
        self.name = name
        self.standardName = standardName
        self.confidence = confidence
        self.brand = brand
        portionSize = nil
        self.servingsMultiplier = servingsMultiplier
        self.standardServing = standardServing
        self.standardServingSize = standardServingSize
        self.units = units
        self.preparationMethod = preparationMethod
        self.visualCues = visualCues
        self.glycemicIndex = glycemicIndex
        nutrition = .perServing(nutritionPerServing)
        self.assessmentNotes = assessmentNotes
        self.imageURL = imageURL
        self.tags = tags
        self.source = source
    }
}

extension FoodItemDetailed {
    var caloriesInThisPortion: Decimal? {
        switch nutrition {
        case .per100:
            guard let portion = portionSize else { return nil }
            return caloriesInPortion(portion: portion)
        case .perServing:
            guard let multiplier = servingsMultiplier else { return nil }
            return caloriesInServings(multiplier: multiplier)
        }
    }

    var carbsInThisPortion: Decimal? {
        switch nutrition {
        case .per100:
            guard let portion = portionSize else { return nil }
            return carbsInPortion(portion: portion)
        case .perServing:
            guard let multiplier = servingsMultiplier else { return nil }
            return carbsInServings(multiplier: multiplier)
        }
    }

    var fatInThisPortion: Decimal? {
        switch nutrition {
        case .per100:
            guard let portion = portionSize else { return nil }
            return fatInPortion(portion: portion)
        case .perServing:
            guard let multiplier = servingsMultiplier else { return nil }
            return fatInServings(multiplier: multiplier)
        }
    }

    var proteinInThisPortion: Decimal? {
        switch nutrition {
        case .per100:
            guard let portion = portionSize else { return nil }
            return proteinInPortion(portion: portion)
        case .perServing:
            guard let multiplier = servingsMultiplier else { return nil }
            return proteinInServings(multiplier: multiplier)
        }
    }

    // MARK: - Per 100g/ml calculations

    /// Calculates calories from macronutrients using standard conversion factors:
    /// - Carbs: 4 kcal/g
    /// - Protein: 4 kcal/g
    /// - Fat: 9 kcal/g
    private func calculateCaloriesFromMacros(carbs: Decimal?, protein: Decimal?, fat: Decimal?) -> Decimal {
        let carbCals = (carbs ?? 0) * 4
        let proteinCals = (protein ?? 0) * 4
        let fatCals = (fat ?? 0) * 9
        return carbCals + proteinCals + fatCals
    }

    func caloriesInPortion(portion: Decimal) -> Decimal? {
        guard case let .per100(per100) = nutrition else { return nil }

        let caloriesPer100: Decimal
        if let explicitCalories = per100.calories {
            caloriesPer100 = explicitCalories
        } else {
            // Calculate from macronutrients if calories not specified
            caloriesPer100 = calculateCaloriesFromMacros(
                carbs: per100.carbs,
                protein: per100.protein,
                fat: per100.fat
            )
        }

        return caloriesPer100 / 100 * portion
    }

    func carbsInPortion(portion: Decimal) -> Decimal? {
        guard case let .per100(per100) = nutrition else { return nil }
        guard let carbsPer100 = per100.carbs else { return nil }
        return carbsPer100 / 100 * portion
    }

    func fatInPortion(portion: Decimal) -> Decimal? {
        guard case let .per100(per100) = nutrition else { return nil }
        guard let fatPer100 = per100.fat else { return nil }
        return fatPer100 / 100 * portion
    }

    func proteinInPortion(portion: Decimal) -> Decimal? {
        guard case let .per100(per100) = nutrition else { return nil }
        guard let proteinPer100 = per100.protein else { return nil }
        return proteinPer100 / 100 * portion
    }

    func fiberInPortion(portion: Decimal) -> Decimal? {
        guard case let .per100(per100) = nutrition else { return nil }
        guard let fiberPer100 = per100.fiber else { return nil }
        return fiberPer100 / 100 * portion
    }

    func sugarsInPortion(portion: Decimal) -> Decimal? {
        guard case let .per100(per100) = nutrition else { return nil }
        guard let sugarsPer100 = per100.sugars else { return nil }
        return sugarsPer100 / 100 * portion
    }

    // MARK: - Per serving calculations

    func caloriesInServings(multiplier: Decimal) -> Decimal? {
        guard case let .perServing(perServing) = nutrition else { return nil }

        let caloriesPerServing: Decimal
        if let explicitCalories = perServing.calories {
            caloriesPerServing = explicitCalories
        } else {
            // Calculate from macronutrients if calories not specified
            caloriesPerServing = calculateCaloriesFromMacros(
                carbs: perServing.carbs,
                protein: perServing.protein,
                fat: perServing.fat
            )
        }

        return caloriesPerServing * multiplier
    }

    func carbsInServings(multiplier: Decimal) -> Decimal? {
        guard case let .perServing(perServing) = nutrition else { return nil }
        guard let carbsPerServing = perServing.carbs else { return nil }
        return carbsPerServing * multiplier
    }

    func fatInServings(multiplier: Decimal) -> Decimal? {
        guard case let .perServing(perServing) = nutrition else { return nil }
        guard let fatPerServing = perServing.fat else { return nil }
        return fatPerServing * multiplier
    }

    func proteinInServings(multiplier: Decimal) -> Decimal? {
        guard case let .perServing(perServing) = nutrition else { return nil }
        guard let proteinPerServing = perServing.protein else { return nil }
        return proteinPerServing * multiplier
    }

    func fiberInServings(multiplier: Decimal) -> Decimal? {
        guard case let .perServing(perServing) = nutrition else { return nil }
        guard let fiberPerServing = perServing.fiber else { return nil }
        return fiberPerServing * multiplier
    }

    func sugarsInServings(multiplier: Decimal) -> Decimal? {
        guard case let .perServing(perServing) = nutrition else { return nil }
        guard let sugarsPerServing = perServing.sugars else { return nil }
        return sugarsPerServing * multiplier
    }

    /// Returns a copy of this food item with an updated portion size or servings multiplier
    func withPortion(_ newPortion: Decimal) -> FoodItemDetailed {
        switch nutrition {
        case let .per100(nutrition):
            return FoodItemDetailed(
                name: name,
                nutritionPer100: nutrition,
                portionSize: newPortion,
                confidence: confidence,
                brand: brand,
                standardServing: standardServing,
                standardServingSize: standardServingSize,
                units: units,
                preparationMethod: preparationMethod,
                visualCues: visualCues,
                glycemicIndex: glycemicIndex,
                assessmentNotes: assessmentNotes,
                imageURL: imageURL,
                tags: tags,
                source: source
            )
        case let .perServing(nutrition):
            return FoodItemDetailed(
                name: name,
                nutritionPerServing: nutrition,
                servingsMultiplier: newPortion,
                confidence: confidence,
                brand: brand,
                standardServing: standardServing,
                standardServingSize: standardServingSize,
                units: units,
                preparationMethod: preparationMethod,
                visualCues: visualCues,
                glycemicIndex: glycemicIndex,
                assessmentNotes: assessmentNotes,
                imageURL: imageURL,
                tags: tags,
                source: source
            )
        }
    }

    func withImageURL(_ newImageURL: String?) -> FoodItemDetailed {
        switch nutrition {
        case let .per100(nutritionValues):
            return FoodItemDetailed(
                id: id,
                name: name,
                nutritionPer100: nutritionValues,
                portionSize: portionSize ?? 100,
                confidence: confidence,
                brand: brand,
                standardServing: standardServing,
                standardServingSize: standardServingSize,
                units: units,
                preparationMethod: preparationMethod,
                visualCues: visualCues,
                glycemicIndex: glycemicIndex,
                assessmentNotes: assessmentNotes,
                imageURL: newImageURL,
                standardName: standardName,
                tags: tags,
                source: source
            )
        case let .perServing(nutritionValues):
            return FoodItemDetailed(
                id: id,
                name: name,
                nutritionPerServing: nutritionValues,
                servingsMultiplier: servingsMultiplier ?? 1,
                confidence: confidence,
                brand: brand,
                standardServing: standardServing,
                standardServingSize: standardServingSize,
                units: units,
                preparationMethod: preparationMethod,
                visualCues: visualCues,
                glycemicIndex: glycemicIndex,
                assessmentNotes: assessmentNotes,
                imageURL: newImageURL,
                standardName: standardName,
                tags: tags,
                source: source
            )
        }
    }

    func withTags(_ newTags: [String]?) -> FoodItemDetailed {
        switch nutrition {
        case let .per100(nutritionValues):
            return FoodItemDetailed(
                id: id,
                name: name,
                nutritionPer100: nutritionValues,
                portionSize: portionSize ?? 100,
                confidence: confidence,
                brand: brand,
                standardServing: standardServing,
                standardServingSize: standardServingSize,
                units: units,
                preparationMethod: preparationMethod,
                visualCues: visualCues,
                glycemicIndex: glycemicIndex,
                assessmentNotes: assessmentNotes,
                imageURL: imageURL,
                standardName: standardName,
                tags: newTags,
                source: source
            )
        case let .perServing(nutritionValues):
            return FoodItemDetailed(
                id: id,
                name: name,
                nutritionPerServing: nutritionValues,
                servingsMultiplier: servingsMultiplier ?? 1,
                confidence: confidence,
                brand: brand,
                standardServing: standardServing,
                standardServingSize: standardServingSize,
                units: units,
                preparationMethod: preparationMethod,
                visualCues: visualCues,
                glycemicIndex: glycemicIndex,
                assessmentNotes: assessmentNotes,
                imageURL: imageURL,
                standardName: standardName,
                tags: newTags,
                source: source
            )
        }
    }
}
