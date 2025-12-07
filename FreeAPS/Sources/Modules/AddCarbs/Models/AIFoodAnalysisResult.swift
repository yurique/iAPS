import Foundation

/// Result from AI food analysis with detailed breakdown
struct AIFoodAnalysisResult: JSON {
    let imageType: ImageAnalysisType?
    let foodItemsDetailed: [FoodItemAnalysis]
    let overallDescription: String?
    let confidence: AIConfidenceLevel
    let totalFoodPortions: Int?
    let totalStandardServings: Double?
    let servingsStandard: String?
    let totalCarbohydrates: Double
    let totalProtein: Double?
    let totalFat: Double?
    let totalFiber: Double?
    let totalCalories: Double?
    let portionAssessmentMethod: String?
    let diabetesConsiderations: String?
    let visualAssessmentDetails: String?
    let notes: String?

    // Store original baseline servings for proper scaling calculations
    let originalServings: Double

    // Advanced dosing fields (optional for backward compatibility)
    let fatProteinUnits: String?
    let netCarbsAdjustment: String?
    let insulinTimingRecommendations: String?
    let fpuDosingGuidance: String?
    let exerciseConsiderations: String?
    var absorptionTimeHours: Double?
    var absorptionTimeReasoning: String?
    let mealSizeImpact: String?
    let individualizationFactors: String?
    let safetyAlerts: String?

    // Legacy compatibility properties
    var foodItems: [String] {
        foodItemsDetailed.map(\.name)
    }

//    var detailedDescription: String? {
//        overallDescription
//    }

    var portionSize: String {
        if foodItemsDetailed.count == 1 {
            return foodItemsDetailed.first?.portionEstimate ?? "1 serving"
        } else {
            // Create concise food summary for multiple items (clean food names)
            let foodNames = foodItemsDetailed.map { item in
                // Clean up food names by removing technical terms
                cleanFoodName(item.name)
            }
            return foodNames.joined(separator: ", ")
        }
    }

    // Helper function to clean food names for display
    private func cleanFoodName(_ name: String) -> String {
        var cleaned = name

        // Remove common technical terms while preserving essential info
        let removals = [
            " Breast", " Fillet", " Thigh", " Florets", " Spears",
            " Cubes", " Medley", " Portion"
        ]

        for removal in removals {
            cleaned = cleaned.replacingOccurrences(of: removal, with: "")
        }

        // Capitalize first letter and trim
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            cleaned = cleaned.prefix(1).uppercased() + cleaned.dropFirst()
        }

        return cleaned.isEmpty ? name : cleaned
    }

    var servingSizeDescription: String {
        if foodItemsDetailed.count == 1 {
            return foodItemsDetailed.first?.portionEstimate ?? "1 serving"
        } else {
            // Return the same clean food names for "Based on" text
            let foodNames = foodItemsDetailed.map { item in
                cleanFoodName(item.name)
            }
            return foodNames.joined(separator: ", ")
        }
    }

//    var carbohydrates: Double {
//        totalCarbohydrates
//    }
//
//    var protein: Double? {
//        totalProtein
//    }
//
//    var fat: Double? {
//        totalFat
//    }
//
//    var calories: Double? {
//        totalCalories
//    }
//
//    var fiber: Double? {
//        totalFiber
//    }

    var servings: Double {
        foodItemsDetailed.reduce(0) { $0 + $1.servingMultiplier }
    }

//    var analysisNotes: String? {
//        portionAssessmentMethod
//    }
}

extension AIFoodAnalysisResult: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let imageType: ImageAnalysisType? = try container
            .decodeIfPresent(ImageAnalysisType.self, forKey: .imageType) ?? .foodPhoto

        let foodItemsDetailed: [FoodItemAnalysis] = try container.decode([FoodItemAnalysis].self, forKey: .foodItemsDetailed)

        // TODO: extractString(from: nutritionData, keys: ["overall_description", "detailed_description"])
        let overallDescription: String? = try container.decodeTrimmedIfPresent(forKey: .overallDescription)

        let confidence: AIConfidenceLevel = try container.decode(AIConfidenceLevel.self, forKey: .confidence)
        let totalFoodPortions: Int? = try container.decodeIfPresent(Int.self, forKey: .totalFoodPortions)
        let totalStandardServings: Double? = try container.decodeNumberIfPresent(forKey: .totalStandardServings)
        let servingsStandard: String? = try container.decodeTrimmedIfPresent(forKey: .servingsStandard)

        let totalCarbohydrates: Double = try container.decodeNumberIfPresent(forKey: .totalCarbohydrates) ??
            foodItemsDetailed.map(\.carbohydrates).reduce(0, +)

        let totalProtein: Double? = try container.decodeNumberIfPresent(forKey: .totalProtein) ??
            foodItemsDetailed.compactMap(\.protein).reduce(0, +)

        let totalFat: Double? = try container.decodeNumberIfPresent(forKey: .totalFat) ??
            foodItemsDetailed.compactMap(\.fat).reduce(0, +)

        let totalFiber: Double? = try container.decodeNumberIfPresent(forKey: .totalFiber) ??
            foodItemsDetailed.compactMap(\.fiber).reduce(0, +)

        let totalCalories: Double? = try container.decodeNumberIfPresent(forKey: .totalCalories) ??
            foodItemsDetailed.compactMap(\.calories).reduce(0, +)

        // TODO: extractString(from: nutritionData, keys: ["portion_assessment_method", "analysis_notes"])
        let portionAssessmentMethod: String? = try container.decodeTrimmedIfPresent(forKey: .portionAssessmentMethod)

        let diabetesConsiderations: String? = try container.decodeTrimmedIfPresent(forKey: .diabetesConsiderations)
        let visualAssessmentDetails: String? = try container.decodeTrimmedIfPresent(forKey: .visualAssessmentDetails)
        let notes: String? = try container.decodeTrimmedIfPresent(forKey: .notes)

        let fatProteinUnits: String? = try container.decodeTrimmedIfPresent(forKey: .fatProteinUnits)
        let netCarbsAdjustment: String? = try container.decodeTrimmedIfPresent(forKey: .netCarbsAdjustment)
        let insulinTimingRecommendations: String? = try container.decodeTrimmedNonEmpty(forKey: .insulinTimingRecommendations)
        let fpuDosingGuidance: String? = try container.decodeTrimmedIfPresent(forKey: .fpuDosingGuidance)
        let exerciseConsiderations: String? = try container.decodeTrimmedIfPresent(forKey: .exerciseConsiderations)
        let absorptionTimeHours: Double? = try container.decodeNumberIfPresent(forKey: .absorptionTimeHours)
        let absorptionTimeReasoning: String? = try container.decodeTrimmedIfPresent(forKey: .absorptionTimeReasoning)
        let mealSizeImpact: String? = try container.decodeTrimmedIfPresent(forKey: .mealSizeImpact)
        let individualizationFactors: String? = try container.decodeTrimmedIfPresent(forKey: .individualizationFactors)
        let safetyAlerts: String? = try container.decodeTrimmedIfPresent(forKey: .safetyAlerts)

        // Calculate original servings for proper scaling
        let originalServings = foodItemsDetailed.map(\.servingMultiplier).reduce(0, +)

        self = AIFoodAnalysisResult(
            imageType: imageType,
            foodItemsDetailed: foodItemsDetailed,
            overallDescription: overallDescription,
            confidence: confidence,
            totalFoodPortions: totalFoodPortions,
            totalStandardServings: totalStandardServings,
            servingsStandard: servingsStandard,
            totalCarbohydrates: totalCarbohydrates,
            totalProtein: totalProtein,
            totalFat: totalFat,
            totalFiber: totalFiber,
            totalCalories: totalCalories,
            portionAssessmentMethod: portionAssessmentMethod,
            diabetesConsiderations: diabetesConsiderations,
            visualAssessmentDetails: visualAssessmentDetails,
            notes: notes,
            originalServings: originalServings,
            fatProteinUnits: fatProteinUnits,
            netCarbsAdjustment: netCarbsAdjustment,
            insulinTimingRecommendations: insulinTimingRecommendations,
            fpuDosingGuidance: fpuDosingGuidance,
            exerciseConsiderations: exerciseConsiderations,
            absorptionTimeHours: absorptionTimeHours,
            absorptionTimeReasoning: absorptionTimeReasoning,
            mealSizeImpact: mealSizeImpact,
            individualizationFactors: individualizationFactors,
            safetyAlerts: safetyAlerts
        )
    }

    // In AIFoodAnalysisResult
    private enum CodingKeys: String, CodingKey {
        case imageType = "image_type"
        case foodItemsDetailed = "food_items"
        case overallDescription = "overall_description"
        case confidence
        case totalFoodPortions = "total_food_portions"
        case totalStandardServings = "total_standard_servings"
        case servingsStandard = "serving_standard"
        case totalCarbohydrates = "total_carbohydrates"
        case totalProtein = "total_protein"
        case totalFat = "total_fat"
        case totalFiber = "total_fiber"
        case totalCalories = "total_calories"
        case portionAssessmentMethod = "portion_assessment_method"
        case diabetesConsiderations = "diabetes_considerations"
        case visualAssessmentDetails = "visual_assessment_details"
        case notes // not present in schema; keep for backward-compat if needed

        // Advanced dosing / extras in schema
        case fatProteinUnits = "fat_protein_units" // not in schema example; optional
        case netCarbsAdjustment = "net_carbs_adjustment"
        case insulinTimingRecommendations = "insulin_timing_recommendations"
        case fpuDosingGuidance = "fpu_dosing_guidance" // not in schema example; optional
        case exerciseConsiderations = "exercise_considerations" // not in schema example; optional
        case absorptionTimeHours = "absorption_time_hours"
        case absorptionTimeReasoning = "absorption_time_reasoning"
        case mealSizeImpact = "meal_size_impact" // not in schema example; optional
        case individualizationFactors = "individualization_factors" // not in schema example; optional
        case safetyAlerts = "safety_alerts"
    }
}

/// Confidence level for AI analysis
enum AIConfidenceLevel: String, JSON, Identifiable, CaseIterable {
    case high
    case medium
    case low

    var id: AIConfidenceLevel { self }
}

extension AIConfidenceLevel {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try to decode numeric confidence first
        if let numeric = try? container.decode(Double.self) {
            if numeric >= 0.8 {
                self = .high
            } else if numeric >= 0.5 {
                self = .medium
            } else {
                self = .low
            }
            return
        }

        // Fallback to string-based confidence values
        if let stringValue = try? container.decode(String.self) {
            switch stringValue.lowercased() {
            case "high":
                self = .high
            case "medium":
                self = .medium
            case "low":
                self = .low
            default:
                // Attempt to parse numeric from string
                if let numericFromString = Double(stringValue) {
                    if numericFromString >= 0.8 {
                        self = .high
                    } else if numericFromString >= 0.5 {
                        self = .medium
                    } else {
                        self = .low
                    }
                } else {
                    self = .medium // Default confidence
                }
            }
            return
        }

        // Default if neither numeric nor string could be decoded
        self = .medium
    }
}

/// Type of image being analyzed
enum ImageAnalysisType: String, JSON, Identifiable, CaseIterable {
    case foodPhoto = "food_photo"
    case menuItem = "menu_item"

    var id: ImageAnalysisType { self }
}

extension KeyedDecodingContainer {
    func decodeTrimmedNonEmpty(forKey key: Key) throws -> String {
        let raw = try decode(String.self, forKey: key)
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: self,
                debugDescription: "Expected non-empty string after trimming."
            )
        }
        return trimmed
    }

    func decodeTrimmedIfPresent(forKey key: Key) throws -> String? {
        guard let raw = try decodeIfPresent(String.self, forKey: key) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func decodeNumber(forKey key: Key, ensuringNonNegative: Bool = true) throws -> Double {
        // Try Double directly
        if let double = try? decode(Double.self, forKey: key) {
            return ensuringNonNegative ? max(0, double) : double
        }
        // Try Int and convert
        if let intVal = try? decode(Int.self, forKey: key) {
            let converted = Double(intVal)
            return ensuringNonNegative ? max(0, converted) : converted
        }
        // Try String and convert
        if let stringVal = try? decode(String.self, forKey: key) {
            let trimmed = stringVal.trimmingCharacters(in: .whitespacesAndNewlines)
            if let parsed = Double(trimmed) {
                return ensuringNonNegative ? max(0, parsed) : parsed
            }
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: self,
                debugDescription: "String value for key \(key.stringValue) is not a valid Double: \(stringVal)"
            )
        }
        // If value is explicitly null or not present, surface a missing value error
        throw DecodingError.keyNotFound(
            key,
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "No convertible numeric value found for key \(key.stringValue)"
            )
        )
    }

    /// Decode a numeric value if present. Accepts Double, Int, or String representations.
    /// Optionally clamps negatives to 0.
    func decodeNumberIfPresent(forKey key: Key, ensuringNonNegative: Bool = true) throws -> Double? {
        // If the key is not present at all, return nil early
        if (try? contains(key)) == false { return nil }

        if let double = try? decode(Double.self, forKey: key) {
            return ensuringNonNegative ? max(0, double) : double
        }
        if let intVal = try? decode(Int.self, forKey: key) {
            let converted = Double(intVal)
            return ensuringNonNegative ? max(0, converted) : converted
        }
        if let stringVal = try? decode(String.self, forKey: key) {
            let trimmed = stringVal.trimmingCharacters(in: .whitespacesAndNewlines)
            if let parsed = Double(trimmed) {
                return ensuringNonNegative ? max(0, parsed) : parsed
            }
            return nil
        }
        return nil
    }
}
