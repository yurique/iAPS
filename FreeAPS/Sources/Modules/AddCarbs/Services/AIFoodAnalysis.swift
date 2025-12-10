import CoreML
import CryptoKit
import Foundation
import LoopKit
import Network
import os.log
import SwiftUI
import UIKit
import Vision

class ConfigurableAIService: ObservableObject, @unchecked Sendable {
    static let shared = ConfigurableAIService()

    // private let log = OSLog(category: "ConfigurableAIService")

    // MARK: - Published Properties

    @Published var textSearchProvider: TextSearchProvider = .defaultProvider
    @Published var barcodeSearchProvider: BarcodeSearchProvider = .defaultProvider
    @Published var aiImageSearchProvider: ImageSearchProvider = .defaultProvider

    private init() {
        // Load current settings
        textSearchProvider = UserDefaults.standard.textSearchProvider
        barcodeSearchProvider = UserDefaults.standard.barcodeSearchProvider
        aiImageSearchProvider = UserDefaults.standard.aiImageProvider

        // Google Gemini API key should be configured by user
//        if UserDefaults.standard.googleGeminiAPIKey.isEmpty {
//            print("⚠️ Google Gemini API key not configured - user needs to set up their own key")
//        }
    }

//    func getProviderImplementation(
//        for provider: SearchProvider
//    ) throws -> FoodAnalysisService {
//        switch provider {
//        case .googleGemini: return GoogleGeminiFoodAnalysisService.shared
//        case .openAI: return OpenAIFoodAnalysisService.shared
//        case .claude: return ClaudeFoodAnalysisService.shared
//        case .openFoodFacts,
//             .usdaFoodData:
//            throw AIFoodAnalysisError.invalidResponse
//        }
//    }

    // MARK: - User Settings

    var isImageAnalysisConfigured: Bool {
        switch UserDefaults.standard.aiImageProvider {
        case .aiModel(.claude):
            return !UserDefaults.standard.claudeAPIKey.isEmpty
        case .aiModel(.gemini):
            return !UserDefaults.standard.googleGeminiAPIKey.isEmpty
        case .aiModel(.openAI):
            return !UserDefaults.standard.openAIAPIKey.isEmpty
        }
    }

    var isTextSearchConfigured: Bool {
        switch UserDefaults.standard.textSearchProvider {
        case .aiModel(.claude):
            return !UserDefaults.standard.claudeAPIKey.isEmpty
        case .aiModel(.gemini):
            return !UserDefaults.standard.googleGeminiAPIKey.isEmpty
        case .aiModel(.openAI):
            return !UserDefaults.standard.openAIAPIKey.isEmpty
        case .usdaFoodData:
            return true
        case .openFoodFacts:
            return true
        }
    }

    var isBarcodeSearchConfigured: Bool {
        switch UserDefaults.standard.barcodeSearchProvider {
//        case .aiModel(.claude):
//            return !UserDefaults.standard.claudeAPIKey.isEmpty
//        case .aiModel(.gemini):
//            return !UserDefaults.standard.googleGeminiAPIKey.isEmpty
//        case .aiModel(.openAI):
//            return !UserDefaults.standard.openAIAPIKey.isEmpty
        case .openFoodFacts:
            return true
        }
    }

    // MARK: - Public Methods

    func setAPIKey(_ key: String, for provider: AIProvider) {
        switch provider {
        case .claude:
            UserDefaults.standard.claudeAPIKey = key
        case .gemini:
            UserDefaults.standard.googleGeminiAPIKey = key
        case .openAI:
            UserDefaults.standard.openAIAPIKey = key
        }
    }

//    func setAnalysisMode(_ mode: AnalysisMode) {
//        analysisMode = mode
//        UserDefaults.standard.analysisMode = mode.rawValue
//    }

    func getAPIKey(for provider: AIProvider) -> String? {
        switch provider {
        case .claude:
            let key = UserDefaults.standard.claudeAPIKey
            return key.isEmpty ? nil : key
        case .gemini:
            let key = UserDefaults.standard.googleGeminiAPIKey
            return key.isEmpty ? nil : key
        case .openAI:
            let key = UserDefaults.standard.openAIAPIKey
            return key.isEmpty ? nil : key
        }
    }

    /// Reset to default Basic Analysis provider (useful for troubleshooting)
    func resetToDefault() {
        UserDefaults.standard.aiImageProvider = .defaultProvider
        UserDefaults.standard.textSearchProvider = .defaultProvider
        UserDefaults.standard.barcodeSearchProvider = .defaultProvider
    }

    // MARK: - Search Type Configuration

//    func getProviderForSearchType(_ searchType: SearchType) -> SearchProvider {
//        switch searchType {
//        case .textSearch:
//            return textSearchProvider
//        case .barcodeSearch:
//            return barcodeSearchProvider
//        case .aiImageSearch:
//            return aiImageSearchProvider
//        }
//    }
//
//    func setProviderForSearchType(_ provider: SearchProvider, searchType: SearchType) {
//        switch searchType {
//        case .textSearch:
//            textSearchProvider = provider
//            UserDefaults.standard.textSearchProvider = provider
//        case .barcodeSearch:
//            barcodeSearchProvider = provider
//            UserDefaults.standard.barcodeSearchProvider = provider
//        case .aiImageSearch:
//            aiImageSearchProvider = provider
//            UserDefaults.standard.aiImageProvider = provider
//        }
//    }

//    func getAvailableProvidersForSearchType(_ searchType: SearchType) -> [SearchProvider] {
//        SearchProvider.allCases
//            .filter { $0.supportsSearchType.contains(searchType) }
//            .sorted { $0.rawValue < $1.rawValue }
//    }

    /// Get a summary of current provider configuration
//    func getProviderConfigurationSummary() -> String {
//        let textProvider = getProviderForSearchType(.textSearch).rawValue
//        let barcodeProvider = getProviderForSearchType(.barcodeSearch).rawValue
//        let aiProvider = getProviderForSearchType(.aiImageSearch).rawValue
//
//        return """
//        Search Configuration:
//        • Text/Voice: \(textProvider)
//        • Barcode: \(barcodeProvider)
//        • AI Image: \(aiProvider)
//        """
//    }

    /// Convert AI image search provider to AIProvider for image analysis
//    private func getAIProviderForImageAnalysis() throws -> AIProvider {
//        switch aiImageSearchProvider {
//        case .claude:
//            return .claude
//        case .googleGemini:
//            return .googleGemini
//        case .openAI:
//            return .openAI
//        case .openFoodFacts,
//             .usdaFoodData:
//            // These don't support image analysis, fallback to basic
//            throw AIFoodAnalysisError.customError("Invalid provider for image analysis: \(aiImageSearchProvider)")
//        }
//    }

    /// Analyze food image with telemetry callbacks for progress tracking
    func analyzeFoodImage(
        _ image: UIImage,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> FoodAnalysisResult {
        // Check cache first for instant results
        if let cachedResult = imageAnalysisCache.getCachedResult(for: image) {
            telemetryCallback?("📋 Found cached analysis result")
            return cachedResult
        }

//        telemetryCallback?("🎯 Selecting optimal AI provider...")
        // Use parallel processing if enabled
//        if enableParallelProcessing {
//            telemetryCallback?("⚡ Starting parallel provider analysis...")
//            let result = try await analyzeImageWithParallelProviders(image, telemetryCallback: telemetryCallback)
//            imageAnalysisCache.cacheResult(result, for: image)
//            return result
//        }

        let providerImpl = try getImageSeachProviderImplementation(
            for: aiImageSearchProvider,
            telemetryCallback: telemetryCallback
        )

        telemetryCallback?("🖼️ Optimizing your image...")
        let base64Image = try ImageCompression.getImageBase64(
            for: image,
            aggressiveImageCompression: providerImpl.needAggressiveImageCompression,
            telemetryCallback: telemetryCallback
        )
        let analysisPrompt = AIPrompts.getAnalysisPrompt(.image, responseSchema: FoodAnalysisResult.schema)

        let result: FoodAnalysisResult = try await providerImpl.analyzeImage(
            prompt: analysisPrompt,
            images: [base64Image],
            telemetryCallback: telemetryCallback
        )

        print("analysis result:\n\n\(result)\n\n")

        telemetryCallback?("💾 Caching analysis result...")

        // Cache the result for future use
        imageAnalysisCache.cacheResult(result, for: image)

        return result
    }

    func analyzeFoodQuery(
        query: String,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> [OpenFoodFactsProduct] {
        switch textSearchProvider {
        case let .aiModel(model):
            let providerImpl = try getAoTextSeachProviderImplementation(for: model, telemetryCallback: telemetryCallback)
            let analysisPrompt = AIPrompts.getAnalysisPrompt(.query(query), responseSchema: FoodAnalysisResult.schema)

            return try await providerImpl.analyzeText(
                prompt: analysisPrompt,
                telemetryCallback: telemetryCallback
            )

        case .usdaFoodData:
            return try await USDAFoodDataService.shared.analyzeText(prompt: query, telemetryCallback: telemetryCallback)
        case .openFoodFacts:
            return try await OpenFoodFactsService.shared.analyzeText(prompt: query, telemetryCallback: telemetryCallback)
        }

//        let key = UserDefaults.standard.claudeAPIKey
//        guard !key.isEmpty else {
//            // log.info("🔑 Claude API key not configured, falling back to USDA")
//            return try await USDAFoodDataService.shared.searchProducts(query: query, pageSize: 15)
//        }

        //        do {
//            let result = try await ClaudeFoodAnalysisService.shared.analyzeFoodQuery(
//                query,
//                apiKey: key,
//                telemetryCallback: nil
//            )
//
//            // Convert Claude analysis result to OpenFoodFactsProduct
//            let syntheticID = "claude_\(abs(query.hashValue))"
//            let nutriments = Nutriments(
//                carbohydrates: result.totalCarbohydrates,
//                proteins: result.totalProtein,
//                fat: result.totalFat,
//                calories: result.totalCalories,
//                sugars: nil,
//                fiber: result.totalFiber
//            )
//
//            let placeholderProduct = OpenFoodFactsProduct(
//                id: syntheticID,
//                productName: result.foodItems.first ?? query.capitalized,
//                brands: "Claude AI Analysis",
//                categories: nil,
//                nutriments: nutriments,
//                servingSize: result.foodItemsDetailed.first?.portionEstimate ?? "1 serving",
//                servingQuantity: 100.0,
//                imageURL: nil,
//                imageFrontURL: nil,
//                code: nil,
//                dataSource: .aiAnalysis
//            )
//
//            return [placeholderProduct]
//        } catch {
//            // log.error("❌ Claude search failed: %{public}@", error.localizedDescription)
//            // Fall back to USDA if Claude fails
//            return try await USDAFoodDataService.shared.searchProducts(query: query, pageSize: 15)
//        }
    }

    func analyzeBarcode(
        barcode: String,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> OpenFoodFactsProduct {
        switch barcodeSearchProvider {
        case .openFoodFacts:
            return try await OpenFoodFactsService.shared.analyzeBarcode(barcode: barcode, telemetryCallback: telemetryCallback)
        }

//        let key = UserDefaults.standard.claudeAPIKey
//        guard !key.isEmpty else {
//            // log.info("🔑 Claude API key not configured, falling back to USDA")
//            return try await USDAFoodDataService.shared.searchProducts(query: query, pageSize: 15)
//        }

        //        do {
//            let result = try await ClaudeFoodAnalysisService.shared.analyzeFoodQuery(
//                query,
//                apiKey: key,
//                telemetryCallback: nil
//            )
//
//            // Convert Claude analysis result to OpenFoodFactsProduct
//            let syntheticID = "claude_\(abs(query.hashValue))"
//            let nutriments = Nutriments(
//                carbohydrates: result.totalCarbohydrates,
//                proteins: result.totalProtein,
//                fat: result.totalFat,
//                calories: result.totalCalories,
//                sugars: nil,
//                fiber: result.totalFiber
//            )
//
//            let placeholderProduct = OpenFoodFactsProduct(
//                id: syntheticID,
//                productName: result.foodItems.first ?? query.capitalized,
//                brands: "Claude AI Analysis",
//                categories: nil,
//                nutriments: nutriments,
//                servingSize: result.foodItemsDetailed.first?.portionEstimate ?? "1 serving",
//                servingQuantity: 100.0,
//                imageURL: nil,
//                imageFrontURL: nil,
//                code: nil,
//                dataSource: .aiAnalysis
//            )
//
//            return [placeholderProduct]
//        } catch {
//            // log.error("❌ Claude search failed: %{public}@", error.localizedDescription)
//            // Fall back to USDA if Claude fails
//            return try await USDAFoodDataService.shared.searchProducts(query: query, pageSize: 15)
//        }
    }

    private func getImageSeachProviderImplementation(
        for provider: ImageSearchProvider,
        telemetryCallback: ((String) -> Void)?
    ) throws -> ImageAnalysisService {
        switch provider {
        case let .aiModel(.gemini(model)):
            let key = UserDefaults.standard.googleGeminiAPIKey
            guard !key.isEmpty else {
                print("❌ Google Gemini API key not configured")
                throw AIFoodAnalysisError.noApiKey
            }
            telemetryCallback?("🤖 Connecting to Google Gemini...")
            return GoogleGeminiFoodAnalysisService.image(model, apiKey: key)

        case let .aiModel(.openAI(model)):
            let key = UserDefaults.standard.openAIAPIKey
            guard !key.isEmpty else {
                print("❌ OpenAI API key not configured")
                throw AIFoodAnalysisError.noApiKey
            }
            telemetryCallback?("🤖 Connecting to OpenAI...")
            return OpenAIFoodAnalysisService.image(model, apiKey: key)

        case let .aiModel(.claude(model)):
            let key = UserDefaults.standard.claudeAPIKey
            guard !key.isEmpty else {
                print("❌ Claude API key not configured")
                throw AIFoodAnalysisError.noApiKey
            }
            telemetryCallback?("🤖 Connecting to Claude AI...")
            return ClaudeFoodAnalysisService.image(model, apiKey: key)
        }
    }

    private func getAoTextSeachProviderImplementation(
        for provider: AIModel,
        telemetryCallback: ((String) -> Void)?
    ) throws -> TextAnalysisService {
        switch provider {
        case let .gemini(model):
            let key = UserDefaults.standard.googleGeminiAPIKey
            guard !key.isEmpty else {
                print("❌ Google Gemini API key not configured")
                throw AIFoodAnalysisError.noApiKey
            }
            telemetryCallback?("🤖 Connecting to Google Gemini...")
            return GoogleGeminiFoodAnalysisService.text(model, apiKey: key)

        case let .openAI(model):
            let key = UserDefaults.standard.openAIAPIKey
            guard !key.isEmpty else {
                print("❌ OpenAI API key not configured")
                throw AIFoodAnalysisError.noApiKey
            }
            telemetryCallback?("🤖 Connecting to OpenAI...")
            return OpenAIFoodAnalysisService.text(model, apiKey: key)

        case let .claude(model):
            let key = UserDefaults.standard.claudeAPIKey
            guard !key.isEmpty else {
                print("❌ Claude API key not configured")
                throw AIFoodAnalysisError.noApiKey
            }
            telemetryCallback?("🤖 Connecting to Claude AI...")
            return ClaudeFoodAnalysisService.text(model, apiKey: key)
        }
    }

    // MARK: - Text Processing Helper Methods

    /// Centralized list of unwanted prefixes that AI commonly adds to food descriptions
    /// Add new prefixes here as edge cases are discovered - this is the SINGLE source of truth
    static let unwantedFoodPrefixes = [
        "of ",
        "with ",
        "contains ",
        "includes ",
        "featuring ",
        "consisting of ",
        "made of ",
        "composed of ",
        "a plate of ",
        "a bowl of ",
        "a serving of ",
        "a portion of ",
        "some ",
        "several ",
        "multiple ",
        "various ",
        "an ",
        "a ",
        "the ",
        "- ",
        "– ",
        "— ",
        "this is ",
        "there is ",
        "there are ",
        "i see ",
        "appears to be ",
        "looks like "
    ]

    /// Analysis mode for speed vs accuracy trade-offs
//    enum AnalysisMode: String, CaseIterable {
//        case standard
//        case fast
//
//        var displayName: String {
//            switch self {
//            case .standard:
//                return "Standard Quality"
//            case .fast:
//                return "Fast Mode"
//            }
//        }
//
//        var description: String {
//            switch self {
//            case .standard:
//                return "Highest accuracy, slower processing"
//            case .fast:
//                return "Good accuracy, 50-70% faster"
//            }
//        }
//
//        var detailedDescription: String {
//            let gpt5Version = UserDefaults.standard.openAIVersion
//            let openAIModel = gpt5Version.rawValue
//
//            switch self {
//            case .standard:
//                return "Uses full AI models (\(openAIModel), Gemini-2.0-Pro, Claude-3.5-Sonnet) for maximum accuracy. Best for complex meals with multiple components."
//            case .fast:
//                return "Uses optimized models (\(openAIModel), Gemini-2.0-Flash) for faster analysis. 2-3x faster with ~5-10% accuracy trade-off. Great for simple meals."
//            }
//        }
//
//        var iconName: String {
//            switch self {
//            case .standard:
//                return "target"
//            case .fast:
//                return "bolt.fill"
//            }
//        }
//
//        var iconColor: Color {
//            switch self {
//            case .standard:
//                return .blue
//            case .fast:
//                return .orange
//            }
//        }
//
//        var backgroundColor: Color {
//            switch self {
//            case .standard:
//                return Color(.systemBlue).opacity(0.08)
//            case .fast:
//                return Color(.systemOrange).opacity(0.08)
//            }
//        }
//    }

    /// Current analysis mode setting
//    @Published var analysisMode = AnalysisMode(rawValue: UserDefaults.standard.analysisMode) ?? .standard

    /// Enable parallel processing for fastest results
//    @Published var enableParallelProcessing: Bool = false

    /// Intelligent caching system for AI analysis results
    private var imageAnalysisCache = ImageAnalysisCache()

    /// Provider-specific optimized timeouts for better performance and user experience
//    static func optimalTimeout(for provider: SearchProvider) -> TimeInterval {
//        switch provider {
//        case .googleGemini:
//            return 15 // Free tier optimization - faster but may timeout on complex analysis
//        case .openAI:
//            // Check if using GPT-5 models which need more time
//            switch UserDefaults.standard.openAIVersion {
//            case .gpt4o:
//                return 20 // GPT-4o models - good balance of speed and reliability
//            case .gpt5_0,
//                 .gpt5_1:
//                return 60 // GPT-5 models need significantly more time for processing
//            }
//        case .claude:
//            return 25 // Highest quality responses but slower processing
//        case .openFoodFacts,
//             .usdaFoodData:
//            return 10 // Simple API calls should be fast
//        }
//    }

    /// Get optimal model for provider and analysis mode
//    static func optimalModel(for provider: SearchProvider, mode: AnalysisMode) -> String {
//        switch (provider, mode) {
//        case (.googleGemini, .standard):
    ////            return "gemini-2.5-pro"
//            return "gemini-3-pro-preview"
//        case (.googleGemini, .fast):
//            return "gemini-2.5-flash" // ~2x faster
//        case (.openAI, .standard):
//            // Use GPT-5 if user enabled it, otherwise use GPT-4o
//            switch UserDefaults.standard.openAIVersion {
//            case .gpt4o: return "gpt-4o"
//            case .gpt5_0: return "gpt-5"
//            case .gpt5_1: return "gpt-5.1"
//            }
//        case (.openAI, .fast):
//            // Use GPT-5-nano for fastest analysis if user enabled GPT-5, otherwise use GPT-4o-mini
//            switch UserDefaults.standard.openAIVersion {
//            case .gpt4o: return "gpt-4o-mini"
//            case .gpt5_0: return "gpt-5-mini" // TODO: nano or mini? gpt itself says nano is text-only
//            case .gpt5_1: return "gpt-5.1" // no '-mini' or '-nano' at this point, but it will route to a specialized sub-model either way
//            }
    ////            return UserDefaults.standard.useGPT5ForOpenAI ? "gpt-5-nano" : "gpt-4o-mini"
//        case (.claude, .standard):
    ////            return "claude-opus-4-5"
//            return "claude-sonnet-4-5"
//        case (.claude, .fast):
//            return "claude-haiku-4-5" // ~2x faster
//        default:
//            return "" // Not applicable for non-AI providers
//        }
//    }

    /// Analyze image with network-aware provider strategy
//    func analyzeImageWithParallelProviders(
//        _ image: UIImage,
//        telemetryCallback: ((String) -> Void)?
//    ) async throws -> FoodAnalysisResult {
//        let networkMonitor = NetworkQualityMonitor.shared
//        telemetryCallback?("🌐 Analyzing network conditions...")
//
//        // Get available providers that support AI analysis
//        let availableProviders: [SearchProvider] = [.googleGemini, .openAI, .claude].filter { provider in
//            // Only include providers that have API keys configured
//            switch provider {
//            case .googleGemini:
//                return !UserDefaults.standard.googleGeminiAPIKey.isEmpty
//            case .openAI:
//                return !UserDefaults.standard.openAIAPIKey.isEmpty
//            case .claude:
//                return !UserDefaults.standard.claudeAPIKey.isEmpty
//            default:
//                return false
//            }
//        }
//
//        guard !availableProviders.isEmpty else {
//            throw AIFoodAnalysisError.noApiKey
//        }
//
//        // Check network conditions and decide strategy
//        if networkMonitor.shouldUseParallelProcessing, availableProviders.count > 1 {
//            print("🌐 Good network detected, using parallel processing with \(availableProviders.count) providers")
//            telemetryCallback?("⚡ Starting parallel AI provider analysis...")
//            return try await analyzeImageWithParallelStrategy(
//                image,
//                providers: availableProviders,
//                telemetryCallback: telemetryCallback
//            )
//        } else {
//            print("🌐 Poor network detected, using sequential processing")
//            telemetryCallback?("🔄 Starting sequential AI provider analysis...")
//            return try await analyzeImageWithSequentialStrategy(
//                image,
//                providers: availableProviders,
//                telemetryCallback: telemetryCallback
//            )
//        }
//    }

    /// Parallel strategy for good networks
//    private func analyzeImageWithParallelStrategy(
//        _ image: UIImage,
//        providers: [SearchProvider],
//        telemetryCallback _: ((String) -> Void)?
//    ) async throws -> FoodAnalysisResult {
//        // Use the maximum timeout from all providers, with special handling for GPT-5
//        let timeout = providers.map { provider in
//            max(ConfigurableAIService.optimalTimeout(for: provider), NetworkQualityMonitor.shared.recommendedTimeout)
//        }.max() ?? NetworkQualityMonitor.shared.recommendedTimeout
//
//        return try await withThrowingTaskGroup(of: FoodAnalysisResult.self) { group in
//            // Add timeout wrapper for each provider
//            for provider in providers {
//                group.addTask { [weak self] in
//                    guard let self = self else { throw AIFoodAnalysisError.invalidResponse }
//                    return try await withTimeoutForAnalysis(seconds: timeout) {
//                        let startTime = Date()
//                        do {
//                            let result = try await self.analyzeImageWithSingleProvider(image, provider: provider)
//                            let duration = Date().timeIntervalSince(startTime)
//                            print("✅ \(provider.rawValue) succeeded in \(String(format: "%.1f", duration))s")
//                            return result
//                        } catch {
//                            let duration = Date().timeIntervalSince(startTime)
//                            print(
//                                "❌ \(provider.rawValue) failed after \(String(format: "%.1f", duration))s: \(error.localizedDescription)"
//                            )
//                            throw error
//                        }
//                    }
//                }
//            }
//
//            // Return the first successful result
//            guard let result = try await group.next() else {
//                throw AIFoodAnalysisError.invalidResponse
//            }
//
//            // Cancel remaining tasks since we got our result
//            group.cancelAll()
//
//            return result
//        }
//    }

    /// Sequential strategy for poor networks (photo) - tries providers one by one
//    private func analyzeImageWithSequentialStrategy(
//        _ image: UIImage,
//        providers: [SearchProvider],
//        telemetryCallback: ((String) -> Void)?
//    ) async throws -> FoodAnalysisResult {
//        // Use provider-specific timeout, with special handling for GPT-5
//        let baseTimeout = NetworkQualityMonitor.shared.recommendedTimeout
//        var lastError: Error?
//
//        // Try providers one by one until one succeeds
//        for provider in providers {
//            do {
//                // Use provider-specific timeout for each provider
//                let providerTimeout = max(ConfigurableAIService.optimalTimeout(for: provider), baseTimeout)
//                print("🔄 Trying \(provider.rawValue) sequentially with \(providerTimeout)s timeout...")
//                telemetryCallback?("🤖 Trying \(provider.rawValue)...")
//                let result = try await withTimeoutForAnalysis(seconds: providerTimeout) {
//                    try await self.analyzeImageWithSingleProvider(image, provider: provider)
//                }
//                print("✅ \(provider.rawValue) succeeded in sequential mode")
//                return result
//            } catch {
//                print("❌ \(provider.rawValue) failed in sequential mode: \(error.localizedDescription)")
//                lastError = error
//                // Continue to next provider
//            }
//        }
//
//        // If all providers failed, throw the last error
//        throw lastError ?? AIFoodAnalysisError.invalidResponse
//    }

    /// Analyze photo with a single provider (helper for parallel processing)
//    private func analyzeImageWithSingleProvider(
//        _ image: UIImage,
//        provider: SearchProvider
//    ) async throws -> FoodAnalysisResult {
//        let providerImpl = try getProviderImplementation(for: provider)
//        return try await providerImpl.analyzeFoodImage(
//            image,
//            apiKey: UserDefaults.standard.googleGeminiAPIKey,
//            telemetryCallback: nil
//        )
//    }

    /// Analyze text query with a single provider (helper for parallel processing)
//    private func analyzeQueryWithSingleProvider(
//        _ query: String,
//        provider: SearchProvider
//    ) async throws -> FoodAnalysisResult {
//        let providerImpl = try getProviderImplementation(for: provider)
//        return try await providerImpl.analyzeFoodQuery(
//            query,
//            apiKey: UserDefaults.standard.googleGeminiAPIKey,
//            telemetryCallback: nil
//        )
//    }

    /// Public static method to clean food text - can be called from anywhere
    static func cleanFoodText(_ text: String?) -> String? {
        guard let text = text else { return nil }

        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Keep removing prefixes until none match (handles multiple prefixes)
        var foundPrefix = true
        var iterationCount = 0
        while foundPrefix, iterationCount < 10 { // Prevent infinite loops
            foundPrefix = false
            iterationCount += 1

            for prefix in unwantedFoodPrefixes {
                if cleaned.lowercased().hasPrefix(prefix.lowercased()) {
                    cleaned = String(cleaned.dropFirst(prefix.count))
                    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                    foundPrefix = true
                    break
                }
            }
        }

        // Capitalize first letter
        if !cleaned.isEmpty {
            cleaned = cleaned.prefix(1).uppercased() + cleaned.dropFirst()
        }

        return cleaned.isEmpty ? nil : cleaned
    }

    /// Cleans AI description text by removing unwanted prefixes and ensuring proper capitalization
    private func cleanAIDescription(_ description: String?) -> String? {
        Self.cleanFoodText(description)
    }
}

// MARK: - Timeout Helper

/// Timeout wrapper for async operations
func withTimeoutForAnalysis<T: Sendable>(
    seconds: TimeInterval,
    operation: @Sendable @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Add the actual operation
        group.addTask {
            try await operation()
        }

        // Add timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw AIFoodAnalysisError.timeout as Error
        }

        // Return first result (either success or timeout)
        defer { group.cancelAll() }
        guard let result = try await group.next() else {
            throw AIFoodAnalysisError.timeout as Error
        }
        return result
    }
}
