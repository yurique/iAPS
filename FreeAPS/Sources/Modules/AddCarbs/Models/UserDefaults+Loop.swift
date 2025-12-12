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
        case openAIAPIKey = "com.loopkit.Loop.openAIAPIKey"
        case googleGeminiAPIKey = "com.loopkit.Loop.googleGeminiAPIKey"
        case textSearchProvider = "com.loopkit.Loop.textSearchProvider"
        case barcodeSearchProvider = "com.loopkit.Loop.barcodeSearchProvider"
        case aiImageProvider = "com.loopkit.Loop.aiImageProvider"
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

    var openAIAPIKey: String {
        get {
            string(forKey: AIKey.openAIAPIKey.rawValue) ?? ""
        }
        set {
            set(newValue, forKey: AIKey.openAIAPIKey.rawValue)
        }
    }

    var googleGeminiAPIKey: String {
        get {
            string(forKey: AIKey.googleGeminiAPIKey.rawValue) ?? ""
        }
        set {
            set(newValue, forKey: AIKey.googleGeminiAPIKey.rawValue)
        }
    }

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
