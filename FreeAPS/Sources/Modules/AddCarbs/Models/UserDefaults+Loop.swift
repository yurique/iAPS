import Foundation
import LoopKit

extension UserDefaults {
    enum AIKey: String {
        case claudeAPIKey = "com.loopkit.Loop.claudeAPIKey"
        case openAIAPIKey = "com.loopkit.Loop.openAIAPIKey"
        case googleGeminiAPIKey = "com.loopkit.Loop.googleGeminiAPIKey"
        case textSearchProvider = "com.loopkit.Loop.textSearchProvider"
        case barcodeSearchProvider = "com.loopkit.Loop.barcodeSearchProvider"
        case aiImageProvider = "com.loopkit.Loop.aiImageProvider"
        case preferredLanguage = "com.loopkit.Loop.AIPreferredLanguage"
        case preferredRegion = "com.loopkit.Loop.AIPreferredRegion"
        case nutritionAuthority = "com.loopkit.Loop.AINutritionAuthority"
        case aiProviderStatistics = "com.loopkit.Loop.AIStatistics"
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

    var userPreferredNutritionAuthorityForAI: NutritionAuthority {
        get {
            if let str = string(forKey: AIKey.nutritionAuthority.rawValue) {
                return NutritionAuthority(rawValue: str) ?? .localDefault
            } else {
                return .localDefault
            }
        }
        set {
            set(newValue.rawValue, forKey: AIKey.nutritionAuthority.rawValue)
        }
    }

    // MARK: - AI Provider Statistics

    enum AIRequestType: String, Codable {
        case image
        case text

        var displayName: String {
            switch self {
            case .image: return "Image"
            case .text: return "Text"
            }
        }
    }

    /// Statistics for a specific AI model and request type
    struct AIProviderStatistics: Codable, Equatable {
        let modelKey: String // The AIModel's rawValue (e.g., "openAI/gpt-4o")
        let requestType: AIRequestType // image or text
        var requestCount: Int
        var successCount: Int
        var failureCount: Int
        var totalProcessingTime: TimeInterval
        var totalSuccessProcessingTime: TimeInterval
        var totalFailureProcessingTime: TimeInterval

        // Complexity-based tracking (food item counts for successful requests)
        var zeroFoodCount: Int
        var zeroFoodTotalProcessingTime: TimeInterval
        var oneFoodCount: Int
        var oneFoodTotalProcessingTime: TimeInterval
        var twoFoodCount: Int
        var twoFoodTotalProcessingTime: TimeInterval
        var multipleFoodCount: Int
        var multipleFoodTotalProcessingTime: TimeInterval

        /// Average processing time per request (all requests)
        var averageProcessingTime: TimeInterval {
            guard requestCount > 0 else { return 0 }
            return totalProcessingTime / Double(requestCount)
        }

        /// Average processing time per successful request
        var averageSuccessProcessingTime: TimeInterval {
            guard successCount > 0 else { return 0 }
            return totalSuccessProcessingTime / Double(successCount)
        }

        /// Average processing time per failed request
        var averageFailureProcessingTime: TimeInterval {
            guard failureCount > 0 else { return 0 }
            return totalFailureProcessingTime / Double(failureCount)
        }

        /// Success rate as a percentage (0-100)
        var successRate: Double {
            guard requestCount > 0 else { return 0 }
            return (Double(successCount) / Double(requestCount)) * 100
        }

        /// Failure rate as a percentage (0-100)
        var failureRate: Double {
            guard requestCount > 0 else { return 0 }
            return (Double(failureCount) / Double(requestCount)) * 100
        }

        // MARK: - Complexity-specific computed properties

        /// Average processing time for requests that found zero food items
        var averageZeroFoodProcessingTime: TimeInterval {
            guard zeroFoodCount > 0 else { return 0 }
            return zeroFoodTotalProcessingTime / Double(zeroFoodCount)
        }

        /// Average processing time for requests that found one food item
        var averageOneFoodProcessingTime: TimeInterval {
            guard oneFoodCount > 0 else { return 0 }
            return oneFoodTotalProcessingTime / Double(oneFoodCount)
        }

        /// Average processing time for requests that found two food items
        var averageTwoFoodProcessingTime: TimeInterval {
            guard twoFoodCount > 0 else { return 0 }
            return twoFoodTotalProcessingTime / Double(twoFoodCount)
        }

        /// Average processing time for requests that found multiple (3+) food items
        var averageMultipleFoodProcessingTime: TimeInterval {
            guard multipleFoodCount > 0 else { return 0 }
            return multipleFoodTotalProcessingTime / Double(multipleFoodCount)
        }

        init(
            modelKey: String,
            requestType: AIRequestType,
            requestCount: Int = 0,
            successCount: Int = 0,
            failureCount: Int = 0,
            totalProcessingTime: TimeInterval = 0,
            totalSuccessProcessingTime: TimeInterval = 0,
            totalFailureProcessingTime: TimeInterval = 0,
            zeroFoodCount: Int = 0,
            zeroFoodTotalProcessingTime: TimeInterval = 0,
            oneFoodCount: Int = 0,
            oneFoodTotalProcessingTime: TimeInterval = 0,
            twoFoodCount: Int = 0,
            twoFoodTotalProcessingTime: TimeInterval = 0,
            multipleFoodCount: Int = 0,
            multipleFoodTotalProcessingTime: TimeInterval = 0
        ) {
            self.modelKey = modelKey
            self.requestType = requestType
            self.requestCount = requestCount
            self.successCount = successCount
            self.failureCount = failureCount
            self.totalProcessingTime = totalProcessingTime
            self.totalSuccessProcessingTime = totalSuccessProcessingTime
            self.totalFailureProcessingTime = totalFailureProcessingTime
            self.zeroFoodCount = zeroFoodCount
            self.zeroFoodTotalProcessingTime = zeroFoodTotalProcessingTime
            self.oneFoodCount = oneFoodCount
            self.oneFoodTotalProcessingTime = oneFoodTotalProcessingTime
            self.twoFoodCount = twoFoodCount
            self.twoFoodTotalProcessingTime = twoFoodTotalProcessingTime
            self.multipleFoodCount = multipleFoodCount
            self.multipleFoodTotalProcessingTime = multipleFoodTotalProcessingTime
        }
    }

    /// Record a new AI request data point
    /// - Parameters:
    ///   - model: The AI model used
    ///   - requestType: Whether this is an image or text request
    ///   - processingTime: The time it took to process the request in seconds
    ///   - success: Whether the request was successful
    ///   - foodItemCount: The number of food items found (optional, only for successful requests)
    func recordAIRequest(
        model: AIModel,
        requestType: AIRequestType,
        processingTime: TimeInterval,
        success: Bool,
        foodItemCount: Int? = nil
    ) {
        var statistics = loadAIStatistics()
        let key = "\(model.rawValue):\(requestType.rawValue)"

        if var existing = statistics[key] {
            existing.requestCount += 1
            existing.totalProcessingTime += processingTime
            if success {
                existing.successCount += 1
                existing.totalSuccessProcessingTime += processingTime

                // Update complexity-specific tracking for successful requests
                if let count = foodItemCount {
                    switch count {
                    case 0:
                        existing.zeroFoodCount += 1
                        existing.zeroFoodTotalProcessingTime += processingTime
                    case 1:
                        existing.oneFoodCount += 1
                        existing.oneFoodTotalProcessingTime += processingTime
                    case 2:
                        existing.twoFoodCount += 1
                        existing.twoFoodTotalProcessingTime += processingTime
                    default: // 3 or more
                        existing.multipleFoodCount += 1
                        existing.multipleFoodTotalProcessingTime += processingTime
                    }
                }
            } else {
                existing.failureCount += 1
                existing.totalFailureProcessingTime += processingTime
            }
            statistics[key] = existing
        } else {
            var newStats = AIProviderStatistics(
                modelKey: model.rawValue,
                requestType: requestType,
                requestCount: 1,
                successCount: success ? 1 : 0,
                failureCount: success ? 0 : 1,
                totalProcessingTime: processingTime,
                totalSuccessProcessingTime: success ? processingTime : 0,
                totalFailureProcessingTime: success ? 0 : processingTime
            )

            // Update complexity-specific tracking for successful requests
            if success, let count = foodItemCount {
                switch count {
                case 0:
                    newStats.zeroFoodCount = 1
                    newStats.zeroFoodTotalProcessingTime = processingTime
                case 1:
                    newStats.oneFoodCount = 1
                    newStats.oneFoodTotalProcessingTime = processingTime
                case 2:
                    newStats.twoFoodCount = 1
                    newStats.twoFoodTotalProcessingTime = processingTime
                default: // 3 or more
                    newStats.multipleFoodCount = 1
                    newStats.multipleFoodTotalProcessingTime = processingTime
                }
            }

            statistics[key] = newStats
        }

        saveAIStatistics(statistics)
    }

    /// Get statistics for a specific model and request type
    /// - Parameters:
    ///   - model: The AI model
    ///   - requestType: Whether this is image or text
    /// - Returns: Statistics for the model+type, or nil if no data exists
    func getAIStatistics(model: AIModel, requestType: AIRequestType) -> AIProviderStatistics? {
        let statistics = loadAIStatistics()
        let key = "\(model.rawValue):\(requestType.rawValue)"
        return statistics[key]
    }

    /// Get all AI provider statistics
    /// - Returns: Array of all tracked statistics, sorted by model key then request type
    func getAllAIStatistics() -> [AIProviderStatistics] {
        let statistics = loadAIStatistics()
        return statistics.values.sorted { lhs, rhs in
            if lhs.modelKey == rhs.modelKey {
                return lhs.requestType.rawValue < rhs.requestType.rawValue
            }
            return lhs.modelKey < rhs.modelKey
        }
    }

    /// Clear all AI statistics
    func clearAIStatistics() {
        set(nil, forKey: AIKey.aiProviderStatistics.rawValue)
    }

    /// Clear statistics for a specific model and request type
    /// - Parameters:
    ///   - model: The AI model
    ///   - requestType: Whether this is image or text
    func clearAIStatistics(model: AIModel, requestType: AIRequestType) {
        var statistics = loadAIStatistics()
        let key = "\(model.rawValue):\(requestType.rawValue)"
        statistics.removeValue(forKey: key)
        saveAIStatistics(statistics)
    }

    // MARK: - Private Helpers

    private func loadAIStatistics() -> [String: AIProviderStatistics] {
        guard let data = data(forKey: AIKey.aiProviderStatistics.rawValue) else {
            return [:]
        }

        let decoder = JSONDecoder()
        do {
            let allStats = try decoder.decode([String: AIProviderStatistics].self, from: data)

            // Filter out statistics for models that no longer exist
            let validStats = allStats.filter { _, stat in
                // Validate the model still exists
                guard AIModel(rawValue: stat.modelKey) != nil else {
                    return false
                }
                return true
            }

            // If we filtered anything out, save the cleaned version
            if validStats.count != allStats.count {
                saveAIStatistics(validStats)
            }

            return validStats
        } catch {
            assertionFailure("Unable to decode AI provider statistics: \(error)")
            return [:]
        }
    }

    private func saveAIStatistics(_ statistics: [String: AIProviderStatistics]) {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(statistics)
            set(data, forKey: AIKey.aiProviderStatistics.rawValue)
        } catch {
            assertionFailure("Unable to encode AI provider statistics: \(error)")
        }
    }
}
