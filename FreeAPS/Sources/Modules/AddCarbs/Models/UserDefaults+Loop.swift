import Foundation
import LoopKit

extension UserDefaults {
    enum AIKey: String {
        case legacyPumpManagerState = "com.loopkit.Loop.PumpManagerState"
        case legacyCGMManagerState = "com.loopkit.Loop.CGMManagerState"
        case legacyServicesState = "com.loopkit.Loop.ServicesState"
        case loopNotRunningNotifications = "com.loopkit.Loop.loopNotRunningNotifications"
        case inFlightAutomaticDose = "com.loopkit.Loop.inFlightAutomaticDose"
        case favoriteFoods = "com.loopkit.Loop.favoriteFoods"
        case aiProvider = "com.loopkit.Loop.aiProvider"
        case standardQueryOverride = "com.loopkit.Loop.standardQueryOverride"
        case advancedQueryOverride = "com.loopkit.Loop.advancedQueryOverride"
        case claudeAPIKey = "com.loopkit.Loop.claudeAPIKey"
//        case claudeQuery = "com.loopkit.Loop.claudeQuery"
        case openAIAPIKey = "com.loopkit.Loop.openAIAPIKey"
//        case openAIQuery = "com.loopkit.Loop.openAIQuery"
        case googleGeminiAPIKey = "com.loopkit.Loop.googleGeminiAPIKey"
//        case googleGeminiQuery = "com.loopkit.Loop.googleGeminiQuery"
        case textSearchProvider = "com.loopkit.Loop.textSearchProvider"
        case barcodeSearchProvider = "com.loopkit.Loop.barcodeSearchProvider"
        case aiImageProvider = "com.loopkit.Loop.aiImageProvider"
//        case analysisMode = "com.loopkit.Loop.analysisMode"
//        case advancedDosingRecommendationsEnabled = "com.loopkit.Loop.advancedDosingRecommendationsEnabled"
//        case openAIVersion = "com.loopkit.Loop.OpenAIVersion"
        case preferredLanguage = "com.loopkit.Loop.AIPreferredLanguage"
        case preferredRegion = "com.loopkit.Loop.AIPreferredRegion"
    }

    enum OpenAIVersion: String, CaseIterable, Identifiable {
        case gpt4o = "GPT-4o"
        case gpt5_0 = "GPT-5"
        case gpt5_1 = "GPT-5.1"

        var id: String { rawValue }
    }

    func clearLegacyPumpManagerRawValue() {
        set(nil, forKey: AIKey.legacyPumpManagerState.rawValue)
    }

    func clearLegacyCGMManagerRawValue() {
        set(nil, forKey: AIKey.legacyCGMManagerState.rawValue)
    }

    var legacyServicesState: [Service.RawStateValue] {
        array(forKey: AIKey.legacyServicesState.rawValue) as? [[String: Any]] ?? []
    }

    func clearLegacyServicesState() {
        set(nil, forKey: AIKey.legacyServicesState.rawValue)
    }

    var inFlightAutomaticDose: AutomaticDoseRecommendation? {
        get {
            let decoder = JSONDecoder()
            guard let data = object(forKey: AIKey.inFlightAutomaticDose.rawValue) as? Data else {
                return nil
            }
            return try? decoder.decode(AutomaticDoseRecommendation.self, from: data)
        }
        set {
            do {
                if let newValue = newValue {
                    let encoder = JSONEncoder()
                    let data = try encoder.encode(newValue)
                    set(data, forKey: AIKey.inFlightAutomaticDose.rawValue)
                } else {
                    set(nil, forKey: AIKey.inFlightAutomaticDose.rawValue)
                }
            } catch {
                assertionFailure("Unable to encode AutomaticDoseRecommendation")
            }
        }
    }

    var aiProvider: String {
        get {
            string(forKey: AIKey.aiProvider.rawValue) ?? "Basic Analysis (Free)"
        }
        set {
            set(newValue, forKey: AIKey.aiProvider.rawValue)
        }
    }

    var standardQueryOverride: String? {
        get {
            string(forKey: AIKey.standardQueryOverride.rawValue)
        }
        set {
            set(newValue, forKey: AIKey.standardQueryOverride.rawValue)
        }
    }

    var advancedQueryOverride: String? {
        get {
            string(forKey: AIKey.advancedQueryOverride.rawValue)
        }
        set {
            set(newValue, forKey: AIKey.advancedQueryOverride.rawValue)
        }
    }

    var claudeAPIKey: String {
        get {
            string(forKey: AIKey.claudeAPIKey.rawValue) ?? ""
        }
        set {
            set(newValue, forKey: AIKey.claudeAPIKey.rawValue)
        }
    }

//    var claudeQuery: String {
//        get {
//            string(forKey: AIKey.claudeQuery.rawValue) ?? """
//            You are a nutrition expert analyzing this food image for diabetes management. Describe EXACTLY what you see in vivid detail.
//
//            EXAMPLE of the detailed description I expect:
//            "I can see a white ceramic dinner plate, approximately 10 inches in diameter, containing three distinct food items. The main protein appears to be a grilled chicken breast, about 5 inches long and 1 inch thick, with visible grill marks in a crosshatch pattern indicating high-heat cooking..."
//
//            RESPOND ONLY IN JSON FORMAT with these exact fields:
//            {
//              "food_items": [
//                {
//                  "name": "specific food name with exact preparation detail I can see",
//                  "portion_estimate": "exact portion with visual references",
//                  "preparation_method": "specific cooking details I observe",
//                  "visual_cues": "exact visual elements I'm analyzing",
//                  "carbohydrates": number_in_grams_for_this_exact_portion,
//                  "protein": number_in_grams_for_this_exact_portion,
//                  "fat": number_in_grams_for_this_exact_portion,
//                  "calories": number_in_kcal_for_this_exact_portion,
//                  "serving_multiplier": decimal_representing_how_many_standard_servings,
//                  "assessment_notes": "step-by-step explanation of how I calculated this portion"
//                }
//              ],
//              "overall_description": "COMPREHENSIVE visual inventory of everything I can see",
//              "total_carbohydrates": sum_of_all_carbs,
//              "total_protein": sum_of_all_protein,
//              "total_fat": sum_of_all_fat,
//              "total_calories": sum_of_all_calories,
//              "portion_assessment_method": "Step-by-step description of my measurement process",
//              "confidence": decimal_between_0_and_1,
//              "diabetes_considerations": "Based on what I can see: specific carb sources and timing considerations",
//              "visual_assessment_details": "Detailed texture, color, cooking, and quality analysis"
//            }
//
//            MANDATORY REQUIREMENTS:
//            ❌ NEVER say "mixed vegetables" - specify "steamed broccoli florets, diced carrots"
//            ❌ NEVER say "chicken" - specify "grilled chicken breast with char marks"
//            ❌ NEVER say "average portion" - specify "5 oz portion covering 1/4 of plate"
//            ✅ ALWAYS describe exact colors, textures, sizes, shapes, cooking evidence
//            ✅ ALWAYS compare portions to visible objects (fork, plate, hand if visible)
//            ✅ ALWAYS calculate nutrition from YOUR visual portion assessment
//            """
//        }
//        set {
//            set(newValue, forKey: AIKey.claudeQuery.rawValue)
//        }
//    }

    var openAIAPIKey: String {
        get {
            string(forKey: AIKey.openAIAPIKey.rawValue) ?? ""
        }
        set {
            set(newValue, forKey: AIKey.openAIAPIKey.rawValue)
        }
    }

//    var openAIQuery: String {
//        get {
//            // Check if using GPT-5 - use optimized prompt for better performance
//            if UserDefaults.standard.useGPT5ForOpenAI {
//                return string(forKey: AIKey.openAIQuery.rawValue) ?? """
//                Analyze this food image for diabetes management. Be specific and accurate.
//
//                JSON format required:
//                {
//                  "food_items": [{
//                    "name": "specific food name with preparation details",
//                    "portion_estimate": "portion size with visual reference",
//                    "carbohydrates": grams_number,
//                    "protein": grams_number,
//                    "fat": grams_number,
//                    "calories": kcal_number,
//                    "serving_multiplier": decimal_servings
//                  }],
//                  "overall_description": "detailed visual description",
//                  "total_carbohydrates": sum_carbs,
//                  "total_protein": sum_protein,
//                  "total_fat": sum_fat,
//                  "total_calories": sum_calories,
//                  "confidence": decimal_0_to_1,
//                  "diabetes_considerations": "carb sources and timing advice"
//                }
//
//                Requirements: Use exact visual details, compare to visible objects, calculate from visual assessment.
//                """
//            } else {
//                // Full detailed prompt for GPT-4 models
//                return string(forKey: AIKey.openAIQuery.rawValue) ?? """
//                You are a nutrition expert analyzing this food image for diabetes management. Describe EXACTLY what you see in vivid detail.
//
//                EXAMPLE of the detailed description I expect:
//                "I can see a white ceramic dinner plate, approximately 10 inches in diameter, containing three distinct food items. The main protein appears to be a grilled chicken breast, about 5 inches long and 1 inch thick, with visible grill marks in a crosshatch pattern indicating high-heat cooking..."
//
//                RESPOND ONLY IN JSON FORMAT with these exact fields:
//                {
//                  "food_items": [
//                    {
//                      "name": "specific food name with exact preparation detail I can see",
//                      "portion_estimate": "exact portion with visual references",
//                      "preparation_method": "specific cooking details I observe",
//                      "visual_cues": "exact visual elements I'm analyzing",
//                      "carbohydrates": number_in_grams_for_this_exact_portion,
//                      "protein": number_in_grams_for_this_exact_portion,
//                      "fat": number_in_grams_for_this_exact_portion,
//                      "calories": number_in_kcal_for_this_exact_portion,
//                      "serving_multiplier": decimal_representing_how_many_standard_servings,
//                      "assessment_notes": "step-by-step explanation of how I calculated this portion"
//                    }
//                  ],
//                  "overall_description": "COMPREHENSIVE visual inventory of everything I can see",
//                  "total_carbohydrates": sum_of_all_carbs,
//                  "total_protein": sum_of_all_protein,
//                  "total_fat": sum_of_all_fat,
//                  "total_calories": sum_of_all_calories,
//                  "portion_assessment_method": "Step-by-step description of my measurement process",
//                  "confidence": decimal_between_0_and_1,
//                  "diabetes_considerations": "Based on what I can see: specific carb sources and timing considerations",
//                  "visual_assessment_details": "Detailed texture, color, cooking, and quality analysis"
//                }
//
//                MANDATORY REQUIREMENTS:
//                ❌ NEVER say "mixed vegetables" - specify "steamed broccoli florets, diced carrots"
//                ❌ NEVER say "chicken" - specify "grilled chicken breast with char marks"
//                ❌ NEVER say "average portion" - specify "5 oz portion covering 1/4 of plate"
//                ✅ ALWAYS describe exact colors, textures, sizes, shapes, cooking evidence
//                ✅ ALWAYS compare portions to visible objects (fork, plate, hand if visible)
//                ✅ ALWAYS calculate nutrition from YOUR visual portion assessment
//                """
//            }
//        }
//        set {
//            set(newValue, forKey: AIKey.openAIQuery.rawValue)
//        }
//    }

    var googleGeminiAPIKey: String {
        get {
            string(forKey: AIKey.googleGeminiAPIKey.rawValue) ?? ""
        }
        set {
            set(newValue, forKey: AIKey.googleGeminiAPIKey.rawValue)
        }
    }

//    var googleGeminiQuery: String {
//        get {
//            string(forKey: AIKey.googleGeminiQuery.rawValue) ?? """
//            You are a nutrition expert analyzing this food image for diabetes management. Describe EXACTLY what you see in vivid detail.
//
//            EXAMPLE of the detailed description I expect:
//            "I can see a white ceramic dinner plate, approximately 10 inches in diameter, containing three distinct food items. The main protein appears to be a grilled chicken breast, about 5 inches long and 1 inch thick, with visible grill marks in a crosshatch pattern indicating high-heat cooking..."
//
//            RESPOND ONLY IN JSON FORMAT with these exact fields:
//            {
//              "food_items": [
//                {
//                  "name": "specific food name with exact preparation detail I can see",
//                  "portion_estimate": "exact portion with visual references",
//                  "preparation_method": "specific cooking details I observe",
//                  "visual_cues": "exact visual elements I'm analyzing",
//                  "carbohydrates": number_in_grams_for_this_exact_portion,
//                  "protein": number_in_grams_for_this_exact_portion,
//                  "fat": number_in_grams_for_this_exact_portion,
//                  "calories": number_in_kcal_for_this_exact_portion,
//                  "serving_multiplier": decimal_representing_how_many_standard_servings,
//                  "assessment_notes": "step-by-step explanation of how I calculated this portion"
//                }
//              ],
//              "overall_description": "COMPREHENSIVE visual inventory of everything I can see",
//              "total_carbohydrates": sum_of_all_carbs,
//              "total_protein": sum_of_all_protein,
//              "total_fat": sum_of_all_fat,
//              "total_calories": sum_of_all_calories,
//              "portion_assessment_method": "Step-by-step description of my measurement process",
//              "confidence": decimal_between_0_and_1,
//              "diabetes_considerations": "Based on what I can see: specific carb sources and timing considerations",
//              "visual_assessment_details": "Detailed texture, color, cooking, and quality analysis"
//            }
//
//            MANDATORY REQUIREMENTS:
//            ❌ NEVER say "mixed vegetables" - specify "steamed broccoli florets, diced carrots"
//            ❌ NEVER say "chicken" - specify "grilled chicken breast with char marks"
//            ❌ NEVER say "average portion" - specify "5 oz portion covering 1/4 of plate"
//            ✅ ALWAYS describe exact colors, textures, sizes, shapes, cooking evidence
//            ✅ ALWAYS compare portions to visible objects (fork, plate, hand if visible)
//            ✅ ALWAYS calculate nutrition from YOUR visual portion assessment
//            """
//        }
//        set {
//            set(newValue, forKey: AIKey.googleGeminiQuery.rawValue)
//        }
//    }

    var textSearchProvider: TextSearchProvider {
        get {
            if let str = string(forKey: AIKey.textSearchProvider.rawValue) {
                return TextSearchProvider(rawValue: str) ?? .defaultProvider
            } else {
                return .defaultProvider
            }
        }
        set {
            set(newValue.rawValue, forKey: AIKey.textSearchProvider.rawValue)
        }
    }

    var barcodeSearchProvider: BarcodeSearchProvider {
        get {
            if let str = string(forKey: AIKey.barcodeSearchProvider.rawValue) {
                return BarcodeSearchProvider(rawValue: str) ?? .defaultProvider
            } else {
                return .defaultProvider
            }
        }
        set {
            set(newValue.rawValue, forKey: AIKey.barcodeSearchProvider.rawValue)
        }
    }

    var aiImageProvider: ImageSearchProvider {
        get {
            if let str = string(forKey: AIKey.aiImageProvider.rawValue) {
                return ImageSearchProvider(rawValue: str) ?? .defaultProvider
            } else {
                return .defaultProvider
            }
        }
        set {
            set(newValue.rawValue, forKey: AIKey.aiImageProvider.rawValue)
        }
    }

//    var analysisMode: String {
//        get {
//            string(forKey: AIKey.analysisMode.rawValue) ?? "standard"
//        }
//        set {
//            set(newValue, forKey: AIKey.analysisMode.rawValue)
//        }
//    }

//    var advancedDosingRecommendationsEnabled: Bool {
//        get {
//            bool(forKey: AIKey.advancedDosingRecommendationsEnabled.rawValue)
//        }
//        set {
//            set(newValue, forKey: AIKey.advancedDosingRecommendationsEnabled.rawValue)
//        }
//    }

//    var openAIVersion: OpenAIVersion {
//        get {
//            if let version = string(forKey: AIKey.openAIVersion.rawValue) {
//                return OpenAIVersion(rawValue: version) ?? .gpt4o
//            } else {
//                return .gpt4o
//            }
//        }
//        set {
//            set(newValue.rawValue, forKey: AIKey.openAIVersion.rawValue)
//        }
//    }

    var userPreferredLanguageForAI: String? {
        get {
            string(forKey: AIKey.preferredLanguage.rawValue)
        }
        set {
            set(newValue, forKey: AIKey.preferredLanguage.rawValue)
        }
    }

    var userPreferredRegionForAI: String? {
        get {
            string(forKey: AIKey.preferredRegion.rawValue)
        }
        set {
            set(newValue, forKey: AIKey.preferredRegion.rawValue)
        }
    }
}
