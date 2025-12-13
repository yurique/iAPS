import Foundation
import UIKit

enum AnalysisRequest {
    case image(_ image: UIImage)
    case query(_ query: String)

    var image: UIImage? {
        switch self {
        case let .image(image): image
        case .query: nil
        }
    }
}

enum AIPrompts {
    static func getAnalysisPrompt(
        _ request: AnalysisRequest,
        responseSchema: [String: Any]
    ) -> String {
        do {
            let selectedPrompt = try getStandardAnalysisPrompt(
                request,
                responseSchema: responseSchema,
            )
            let promptLength = selectedPrompt.count

            print("🎯 AI Analysis Prompt Selection:")
            //    print("   Advanced Dosing Enabled: \(isAdvancedEnabled)")
            print("   Prompt Length: \(promptLength) characters")
            //    print("   Prompt Type: \(isAdvancedEnabled ? "ADVANCED (with FPU calculations)" : "STANDARD (basic diabetes analysis)")")
            print("   First 100 chars of selected prompt: \(String(selectedPrompt.prefix(100)))")

            return selectedPrompt
        } catch {
            return ""
        }
    }
}

private enum PromptLoader {
    static func loadTextResource(named fileName: String) -> String {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            assertionFailure("Missing resource \(fileName)")
            return ""
        }
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            assertionFailure("Failed to load \(fileName): \(error)")
            return ""
        }
    }
}

private let standardAnalysis_0_Header: String = PromptLoader.loadTextResource(named: "ai/standard/0_header.txt")
private let standardAnalysis_1_Preferences: String = PromptLoader.loadTextResource(named: "ai/standard/1_user_preferences.txt")

private let standardAnalysis_3_Standards: String = PromptLoader.loadTextResource(named: "ai/standard/3_standards.txt")

private let standardAnalysis_5_1_photo_instructions: String = PromptLoader
    .loadTextResource(named: "ai/standard/5_1_photo_instructions.txt")

private let standardAnalysis_5_2_text_instructions: String = PromptLoader
    .loadTextResource(named: "ai/standard/5_2_text_instructions.txt")

private let standardAnalysis_6_concepts: String = PromptLoader.loadTextResource(named: "ai/standard/6_concepts.txt")

private let standardAnalysis_8_1_photo_response_format: String = PromptLoader
    .loadTextResource(named: "ai/standard/8_1_photo_response_format.txt")

private let standardAnalysis_8_2_text_response_format: String = PromptLoader
    .loadTextResource(named: "ai/standard/8_2_text_response_format.txt")

private let standardAnalysis_8_footer_common: String = PromptLoader
    .loadTextResource(named: "ai/standard/8_footer_requirements_common.txt")

private let standardAnalysis_9_1_footer_photo: String = PromptLoader
    .loadTextResource(named: "ai/standard/9_1_footer_requirements_photo.txt")

private let standardAnalysis_9_2_footer_text: String = PromptLoader
    .loadTextResource(named: "ai/standard/9_2_footer_requirements_text.txt")

/// Standard analysis prompt for basic diabetes management (used when Advanced Dosing is OFF)
private func getStandardAnalysisPrompt(
    _ request: AnalysisRequest,
    responseSchema: [String: Any],
) throws -> String {
    let instructions = switch request {
    case .image: standardAnalysis_5_1_photo_instructions
    case let .query(textQuery): standardAnalysis_5_2_text_instructions.replacingOccurrences(of: "(query)", with: textQuery)
    }

    let schemaData: Data
    do {
        schemaData = try JSONSerialization.data(
            withJSONObject: responseSchema,
            options: [.prettyPrinted, .withoutEscapingSlashes]
        )
    } catch {
        throw AIFoodAnalysisError.requestCreationFailed
    }

    guard let schema = String(data: schemaData, encoding: .utf8) else {
        throw AIFoodAnalysisError.requestCreationFailed
    }

    // TODO: response format should be the same
    let responseFormat: String =
        "RESPOND IN JSON FORMAT:\n" +
        schema

    let languageCode = UserDefaults.standard.userPreferredLanguageForAI ?? Locale.current.region?.identifier
    let regionCode = UserDefaults.standard.userPreferredRegionForAI ?? Locale.preferredLanguages.first
    let userPreferences: String = {
        let hasLang = !(languageCode?.isEmpty ?? true)
        let hasRegion = !(regionCode?.isEmpty ?? true)
        if hasLang || hasRegion {
            return makePreferencesBlock(languageCode: languageCode, regionCode: regionCode)
        } else {
            return ""
        }
    }()

    let footerRequirements = switch request {
    case .image: standardAnalysis_9_1_footer_photo
    case .query: standardAnalysis_9_2_footer_text
    }

    return standardAnalysis_0_Header + "\n\n" +
        userPreferences + "\n\n" +
        standardAnalysis_3_Standards + "\n\n" +
        instructions + "\n\n" +
        standardAnalysis_6_concepts + "\n\n" +
        responseFormat + "\n\n" +
        standardAnalysis_8_footer_common + "\n\n" +
        footerRequirements
}

private func makePreferencesBlock(languageCode: String?, regionCode: String?) -> String {
    let locale = Locale.current

    let rawLang = languageCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let languageTag: String = {
        let trimmed = rawLang
        if trimmed.isEmpty { return "en-US" }
        return trimmed
    }()

    let primaryLanguageCode = languageTag.split(separator: "-").first.map(String.init) ?? "en"
    let languageName = locale.localizedString(forLanguageCode: primaryLanguageCode) ?? primaryLanguageCode

    let systemRegion = Locale.current.identifier
    let rawRegion = regionCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let effectiveRegion = rawRegion.isEmpty ? systemRegion : rawRegion
    let regionName = locale.localizedString(forRegionCode: effectiveRegion) ?? effectiveRegion

    let languageForAI = "\(languageName) (\(languageTag))"

    let regionForAI =
        effectiveRegion.isNotEmpty ?
        "\(regionName) (\(effectiveRegion))" : regionName

    let nutritionAuthority = UserDefaults.standard.userPreferredNutritionAuthorityForAI

    return standardAnalysis_1_Preferences
        .replacingOccurrences(of: "(nutrition_authority)", with: nutritionAuthority.descriptionForAI)
        .replacingOccurrences(of: "(language)", with: languageForAI)
        .replacingOccurrences(of: "(region)", with: regionForAI)
}
