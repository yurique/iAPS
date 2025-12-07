import CoreML
import CryptoKit
import Foundation
import LoopKit
import Network
import os.log
import SwiftUI
import UIKit
import Vision

protocol FoodAnalysisService {
    func analyzeFoodImage(_ image: UIImage, apiKey: String, telemetryCallback: ((String) -> Void)?) async throws
        -> AIFoodAnalysisResult

    func analyzeFoodQuery(_ query: String, apiKey: String, telemetryCallback: ((String) -> Void)?) async throws
        -> AIFoodAnalysisResult
}

// MARK: - Network Quality Monitoring

/// Network quality monitor for determining analysis strategy
class NetworkQualityMonitor: ObservableObject {
    static let shared = NetworkQualityMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published var isConnected = false
    @Published var connectionType: NWInterface.InterfaceType?
    @Published var isExpensive = false
    @Published var isConstrained = false

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.global().async { [weak self] in
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive
                self?.isConstrained = path.isConstrained

                // Determine connection type
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .wiredEthernet
                } else {
                    self?.connectionType = nil
                }
            }
        }
        monitor.start(queue: queue)
    }

    /// Determines if we should use aggressive optimizations
    var shouldUseConservativeMode: Bool {
        !isConnected || isExpensive || isConstrained || connectionType == .cellular
    }

    /// Determines if parallel processing is safe
    var shouldUseParallelProcessing: Bool {
        isConnected && !isExpensive && !isConstrained && connectionType == .wifi
    }

    /// Gets appropriate timeout for current network conditions
    var recommendedTimeout: TimeInterval {
        if shouldUseConservativeMode {
            return 45.0 // Conservative timeout for poor networks
        } else {
            return 25.0 // Standard timeout for good networks
        }
    }
}

// MARK: - AI Food Analysis Models

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
private let standardAnalysis_3_Standards: String = PromptLoader.loadTextResource(named: "ai/standard/3_standards.txt")
private let standardAnalysis_5_1_photo_instructions: String = PromptLoader
    .loadTextResource(named: "ai/standard/5_1_photo_instructions.txt")
private let standardAnalysis_5_2_text_instructions: String = PromptLoader
    .loadTextResource(named: "ai/standard/5_2_text_instructions.txt")
private let standardAnalysis_7_concepts: String = PromptLoader.loadTextResource(named: "ai/standard/7_concepts.txt")
private let standardAnalysis_8_1_photo_response_format: String = PromptLoader
    .loadTextResource(named: "ai/standard/8_1_photo_response_format.txt")
private let standardAnalysis_8_2_text_response_format: String = PromptLoader
    .loadTextResource(named: "ai/standard/8_2_text_response_format.txt")
private let standardAnalysisFooter: String = PromptLoader
    .loadTextResource(named: "ai/standard/9_footer_requirements.txt")

/// Standard analysis prompt for basic diabetes management (used when Advanced Dosing is OFF)
private func getStandardAnalysisPrompt(
    _ request: AnalysisRequest,
    language _: String,
    region _: String
) -> String {
    let instructions: String = switch request {
    case .image: standardAnalysis_5_1_photo_instructions
    case let .query(textQuery): standardAnalysis_5_2_text_instructions.replacingOccurrences(of: "(query)", with: textQuery)
    }

    // TODO: response format should be the same
    let responseFormat: String = switch request {
    case .image: standardAnalysis_8_1_photo_response_format
    case .query: standardAnalysis_8_2_text_response_format
    }

    let languageCode = UserDefaults.standard.userPreferredLanguageForAI
    let regionCode = UserDefaults.standard.userPreferredRegionForAI
    let userPreferences: String = {
        let hasLang = !(languageCode?.isEmpty ?? true)
        let hasRegion = !(regionCode?.isEmpty ?? true)
        if hasLang || hasRegion {
            return makePreferencesBlock(languageCode: languageCode, regionCode: regionCode)
        } else {
            return ""
        }
    }()

    return standardAnalysis_0_Header + "\n\n" +
        userPreferences + "\n\n" +
        standardAnalysis_3_Standards + "\n\n" +
        instructions + "\n\n" +
        standardAnalysis_7_concepts + "\n\n" +
        responseFormat + "\n\n" +
        standardAnalysisFooter
}

/// Advanced analysis prompt with FPU calculations and exercise considerations (used when Advanced Dosing is ON)
private let advancedAnalysisPrompt: String = PromptLoader.loadTextResource(named: "ai/advanced/AdvancedAnalysisPrompt")

private func makePreferencesBlock(languageCode: String?, regionCode: String?) -> String {
    let locale = Locale.current

    // Determine effective language: fallback to US English ("en-US") when missing
    let rawLang = languageCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let languageTag: String = {
        let trimmed = rawLang
        if trimmed.isEmpty { return "en-US" } // fallback to US English
        return trimmed
    }()

    // Primary language code for a human-readable name (e.g., "en" from "en-US")
    let primaryLanguageCode = languageTag.split(separator: "-").first.map(String.init) ?? "en"
    let languageName = locale.localizedString(forLanguageCode: primaryLanguageCode) ?? primaryLanguageCode

    // Determine effective region: fallback to user's system preferred region
    let systemRegion = Locale.current.identifier
    let rawRegion = regionCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let effectiveRegion = rawRegion.isEmpty ? systemRegion : rawRegion
    let regionName = locale.localizedString(forRegionCode: effectiveRegion) ?? effectiveRegion

    var lines: [String] = ["", "# USER PREFERENCES"]

    // Always include language preference (using BCP-47 tag)
    lines.append("- User language: \(languageName) (\(languageTag))")
    lines
        .append(
            "- Output language for all *values* in JSON fields that represent human-readable text (e.g. names, descriptions, notes)."
        )
    lines.append("- Do NOT translate JSON field names / keys. They MUST stay exactly as in the schema.")

    // Always include region preference (falling back to system region)
    if !effectiveRegion.isEmpty {
        lines.append("- User region: \(regionName) (\(effectiveRegion))")
    } else {
        lines.append("- User region: \(regionName)")
    }

    lines.append("- Always keep the response a single valid JSON object, with no explanation before or after it.")

    return lines.joined(separator: "\n")
}

/// Function to generate analysis prompt based on advanced dosing recommendations setting
/// Forces fresh read of UserDefaults to avoid caching issues
internal func getAnalysisPrompt(
    _ request: AnalysisRequest,
) -> String {
    let language = UserDefaults.standard.userPreferredLanguageForAI ?? "English"
    let region = UserDefaults.standard.userPreferredRegionForAI ?? "Europe"

    let selectedPrompt = getStandardAnalysisPrompt(
        request,
        language: language,
        region: region
    )
    let promptLength = selectedPrompt.count

    print("🎯 AI Analysis Prompt Selection:")
//    print("   Advanced Dosing Enabled: \(isAdvancedEnabled)")
    print("   Prompt Length: \(promptLength) characters")
//    print("   Prompt Type: \(isAdvancedEnabled ? "ADVANCED (with FPU calculations)" : "STANDARD (basic diabetes analysis)")")
    print("   First 100 chars of selected prompt: \(String(selectedPrompt.prefix(100)))")

    return selectedPrompt
}

// MARK: - Search Types

/// Different types of food searches that can use different providers
enum SearchType: String, CaseIterable {
    case textSearch = "Text/Voice Search"
    case barcodeSearch = "Barcode Scanning"
    case aiImageSearch = "AI Image Analysis"

    var description: String {
        switch self {
        case .textSearch:
            return "Searching by typing food names or using voice input"
        case .barcodeSearch:
            return "Scanning product barcodes with camera"
        case .aiImageSearch:
            return "Taking photos of food for AI analysis"
        }
    }
}

/// Available providers for different search types
enum SearchProvider: String, CaseIterable {
    case claude = "Anthropic (Claude API)"
    case googleGemini = "Google (Gemini API)"
    case openAI = "OpenAI (ChatGPT API)"
    case openFoodFacts = "OpenFoodFacts"
    case usdaFoodData = "USDA FoodData Central"

    var supportsSearchType: [SearchType] {
        switch self {
        case .claude:
            return [.textSearch, .aiImageSearch]
        case .googleGemini:
            return [.textSearch, .aiImageSearch]
        case .openAI:
            return [.textSearch, .aiImageSearch]
        case .openFoodFacts:
            return [.textSearch, .barcodeSearch]
        case .usdaFoodData:
            return [.textSearch]
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .openFoodFacts,
             .usdaFoodData:
            return false
        case .claude,
             .googleGemini,
             .openAI:
            return true
        }
    }
}

enum AIProvider: String, CaseIterable {
    case claude = "Anthropic (Claude API)"
    case googleGemini = "Google (Gemini API)"
    case openAI = "OpenAI (ChatGPT API)"

    var requiresAPIKey: Bool {
        switch self {
        case .claude,
             .googleGemini,
             .openAI:
            return true
        }
    }

    var requiresCustomURL: Bool {
        switch self {
        case .claude,
             .googleGemini,
             .openAI:
            return false
        }
    }

    var description: String {
        switch self {
        case .claude:
            return "Anthropic's Claude AI with excellent reasoning. Requires paid API key from console.anthropic.com."
        case .googleGemini:
            return "Free API key available at ai.google.dev. Best for detailed food analysis."
        case .openAI:
            return "Requires paid OpenAI API key. Most accurate for complex meals."
        }
    }
}

// MARK: - Intelligent Caching System

/// Cache for AI analysis results based on image hashing
class ImageAnalysisCache {
    private let cache = NSCache<NSString, CachedAnalysisResult>()
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes

    init() {
        // Configure cache limits
        cache.countLimit = 50 // Maximum 50 cached results
        cache.totalCostLimit = 10 * 1024 * 1024 // 10MB limit
    }

    /// Cache an analysis result for the given image
    func cacheResult(_ result: AIFoodAnalysisResult, for image: UIImage) {
        let imageHash = calculateImageHash(image)
        let cachedResult = CachedAnalysisResult(
            result: result,
            timestamp: Date(),
            imageHash: imageHash
        )

        cache.setObject(cachedResult, forKey: imageHash as NSString)
    }

    /// Get cached result for the given image if available and not expired
    func getCachedResult(for image: UIImage) -> AIFoodAnalysisResult? {
        let imageHash = calculateImageHash(image)

        guard let cachedResult = cache.object(forKey: imageHash as NSString) else {
            return nil
        }

        // Check if cache entry has expired
        if Date().timeIntervalSince(cachedResult.timestamp) > cacheExpirationTime {
            cache.removeObject(forKey: imageHash as NSString)
            return nil
        }

        return cachedResult.result
    }

    /// Calculate a hash for the image to use as cache key
    private func calculateImageHash(_ image: UIImage) -> String {
        // Convert image to data and calculate SHA256 hash
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return UUID().uuidString
        }

        let hash = imageData.sha256Hash
        return hash
    }

    /// Clear all cached results
    func clearCache() {
        cache.removeAllObjects()
    }
}

/// Wrapper for cached analysis results with metadata
private class CachedAnalysisResult {
    let result: AIFoodAnalysisResult
    let timestamp: Date
    let imageHash: String

    init(result: AIFoodAnalysisResult, timestamp: Date, imageHash: String) {
        self.result = result
        self.timestamp = timestamp
        self.imageHash = imageHash
    }
}

/// Extension to calculate SHA256 hash for Data
extension Data {
    var sha256Hash: String {
        let digest = SHA256.hash(data: self)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Configurable AI Service

/// AI service that allows users to configure their own API keys
class ConfigurableAIService: ObservableObject, @unchecked Sendable {
    // MARK: - Singleton

    static let shared = ConfigurableAIService()

    // private let log = OSLog(category: "ConfigurableAIService")

    // MARK: - Published Properties

    @Published var textSearchProvider: SearchProvider = .openFoodFacts
    @Published var barcodeSearchProvider: SearchProvider = .openFoodFacts
    @Published var aiImageSearchProvider: SearchProvider = .googleGemini

    private init() {
        // Load current settings
        textSearchProvider = UserDefaults.standard.textSearchProvider
        barcodeSearchProvider = UserDefaults.standard.barcodeSearchProvider
        aiImageSearchProvider = UserDefaults.standard.aiImageProvider

        // Google Gemini API key should be configured by user
        if UserDefaults.standard.googleGeminiAPIKey.isEmpty {
            print("⚠️ Google Gemini API key not configured - user needs to set up their own key")
        }
    }

    // MARK: - Configuration

    func getProviderImplementation(
        for provider: SearchProvider
    ) throws -> FoodAnalysisService {
        switch provider {
        case .googleGemini: return GoogleGeminiFoodAnalysisService.shared
        case .openAI: return OpenAIFoodAnalysisService.shared
        case .claude: return ClaudeFoodAnalysisService.shared
        case .openFoodFacts,
             .usdaFoodData:
            throw AIFoodAnalysisError.invalidResponse
        }
    }

    // MARK: - User Settings

    var isImageAnalysisConfigured: Bool {
        print("ai image provider: \(UserDefaults.standard.aiImageProvider)")
        switch UserDefaults.standard.aiImageProvider {
        case .claude:
            return !UserDefaults.standard.claudeAPIKey.isEmpty
        case .googleGemini:
            return !UserDefaults.standard.googleGeminiAPIKey.isEmpty
        case .openAI:
            return !UserDefaults.standard.openAIAPIKey.isEmpty
        case .openFoodFacts,
             .usdaFoodData:
            // something is not right
            return false
        }
    }

    // MARK: - Public Methods

    func setAPIKey(_ key: String, for provider: AIProvider) {
        switch provider {
        case .claude:
            UserDefaults.standard.claudeAPIKey = key
        case .googleGemini:
            UserDefaults.standard.googleGeminiAPIKey = key
        case .openAI:
            UserDefaults.standard.openAIAPIKey = key
        }
    }

    func setAPIURL(_: String, for provider: AIProvider) {
        switch provider {
        case .claude,
             .googleGemini,
             .openAI:
            break // No custom URL needed
        }
    }

    func setAPIName(_: String, for provider: AIProvider) {
        switch provider {
        case .claude,
             .googleGemini,
             .openAI:
            break // No custom name needed
        }
    }

    func setStandardQueryOverride(_ query: String?) {
        UserDefaults.standard.standardQueryOverride = query
    }

    func setAdvancedQueryOverride(_ query: String?) {
        UserDefaults.standard.advancedQueryOverride = query
    }

    func setAnalysisMode(_ mode: AnalysisMode) {
        analysisMode = mode
        UserDefaults.standard.analysisMode = mode.rawValue
    }

    func getAPIKey(for provider: AIProvider) -> String? {
        switch provider {
        case .claude:
            let key = UserDefaults.standard.claudeAPIKey
            return key.isEmpty ? nil : key
        case .googleGemini:
            let key = UserDefaults.standard.googleGeminiAPIKey
            return key.isEmpty ? nil : key
        case .openAI:
            let key = UserDefaults.standard.openAIAPIKey
            return key.isEmpty ? nil : key
        }
    }

    func getAPIURL(for provider: AIProvider) -> String? {
        switch provider {
        case .claude,
             .googleGemini,
             .openAI:
            return nil
        }
    }

    func getAPIName(for provider: AIProvider) -> String? {
        switch provider {
        case .claude,
             .googleGemini,
             .openAI:
            return nil
        }
    }

    func getStandardQueryOverride() -> String? {
        UserDefaults.standard.standardQueryOverride
    }

    func getAdvancedQueryOverride() -> String? {
        UserDefaults.standard.advancedQueryOverride
    }

    /// Reset to default Basic Analysis provider (useful for troubleshooting)
    func resetToDefault() {
        UserDefaults.standard.aiImageProvider = .googleGemini
        UserDefaults.standard.textSearchProvider = .usdaFoodData
        UserDefaults.standard.barcodeSearchProvider = .openFoodFacts
    }

    // MARK: - Search Type Configuration

    func getProviderForSearchType(_ searchType: SearchType) -> SearchProvider {
        switch searchType {
        case .textSearch:
            return textSearchProvider
        case .barcodeSearch:
            return barcodeSearchProvider
        case .aiImageSearch:
            return aiImageSearchProvider
        }
    }

    func setProviderForSearchType(_ provider: SearchProvider, searchType: SearchType) {
        switch searchType {
        case .textSearch:
            textSearchProvider = provider
            UserDefaults.standard.textSearchProvider = provider
        case .barcodeSearch:
            barcodeSearchProvider = provider
            UserDefaults.standard.barcodeSearchProvider = provider
        case .aiImageSearch:
            aiImageSearchProvider = provider
            UserDefaults.standard.aiImageProvider = provider
        }
    }

    func getAvailableProvidersForSearchType(_ searchType: SearchType) -> [SearchProvider] {
        SearchProvider.allCases
            .filter { $0.supportsSearchType.contains(searchType) }
            .sorted { $0.rawValue < $1.rawValue }
    }

    /// Get a summary of current provider configuration
    func getProviderConfigurationSummary() -> String {
        let textProvider = getProviderForSearchType(.textSearch).rawValue
        let barcodeProvider = getProviderForSearchType(.barcodeSearch).rawValue
        let aiProvider = getProviderForSearchType(.aiImageSearch).rawValue

        return """
        Search Configuration:
        • Text/Voice: \(textProvider)
        • Barcode: \(barcodeProvider) 
        • AI Image: \(aiProvider)
        """
    }

    /// Convert AI image search provider to AIProvider for image analysis
    private func getAIProviderForImageAnalysis() throws -> AIProvider {
        switch aiImageSearchProvider {
        case .claude:
            return .claude
        case .googleGemini:
            return .googleGemini
        case .openAI:
            return .openAI
        case .openFoodFacts,
             .usdaFoodData:
            // These don't support image analysis, fallback to basic
            throw AIFoodAnalysisError.customError("Invalid provider for image analysis: \(aiImageSearchProvider)")
        }
    }

    /// Analyze food image using the configured provider with intelligent caching
    func analyzeFoodImage(_ image: UIImage) async throws -> AIFoodAnalysisResult {
        try await analyzeFoodImage(image, telemetryCallback: nil)
    }

    /// Analyze food image with telemetry callbacks for progress tracking
    func analyzeFoodImage(_ image: UIImage, telemetryCallback: ((String) -> Void)?) async throws -> AIFoodAnalysisResult {
        // Check cache first for instant results
        if let cachedResult = imageAnalysisCache.getCachedResult(for: image) {
            telemetryCallback?("📋 Found cached analysis result")
            return cachedResult
        }

        telemetryCallback?("🎯 Selecting optimal AI provider...")

        // Use parallel processing if enabled
        if enableParallelProcessing {
            telemetryCallback?("⚡ Starting parallel provider analysis...")
            let result = try await analyzeImageWithParallelProviders(image, telemetryCallback: telemetryCallback)
            imageAnalysisCache.cacheResult(result, for: image)
            return result
        }

        // Use the AI image search provider instead of the separate currentProvider
        let provider = try getAIProviderForImageAnalysis()

        let key: String
        let prividerImpl: FoodAnalysisService

        switch provider {
        case .claude:
            key = UserDefaults.standard.claudeAPIKey
            guard !key.isEmpty else {
                print("❌ Claude API key not configured")
                throw AIFoodAnalysisError.noApiKey
            }
            telemetryCallback?("🤖 Connecting to Claude AI...")
            prividerImpl = ClaudeFoodAnalysisService.shared
        case .googleGemini:
            key = UserDefaults.standard.googleGeminiAPIKey
            guard !key.isEmpty else {
                print("❌ Google Gemini API key not configured")
                throw AIFoodAnalysisError.noApiKey
            }
            telemetryCallback?("🤖 Connecting to Google Gemini...")
            prividerImpl = GoogleGeminiFoodAnalysisService.shared
        case .openAI:
            key = UserDefaults.standard.openAIAPIKey
            guard !key.isEmpty else {
                print("❌ OpenAI API key not configured")
                throw AIFoodAnalysisError.noApiKey
            }
            telemetryCallback?("🤖 Connecting to OpenAI...")
            prividerImpl = OpenAIFoodAnalysisService.shared
        }

        let result: AIFoodAnalysisResult = try await prividerImpl.analyzeFoodImage(
            image,
            apiKey: key,
            telemetryCallback: telemetryCallback
        )

        telemetryCallback?("💾 Caching analysis result...")

        // Cache the result for future use
        imageAnalysisCache.cacheResult(result, for: image)

        return result
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

    /// Adaptive image compression based on image size for optimal performance
    static func adaptiveCompressionQuality(for image: UIImage) -> CGFloat {
        let imagePixels = image.size.width * image.size.height

        // Adaptive compression: larger images need more compression for faster uploads
        switch imagePixels {
        case 0 ..< 500_000: // Small images (< 500k pixels)
            return 0.9
        case 500_000 ..< 1_000_000: // Medium images (500k-1M pixels)
            return 0.8
        default: // Large images (> 1M pixels)
            return 0.7
        }
    }

    /// Analysis mode for speed vs accuracy trade-offs
    enum AnalysisMode: String, CaseIterable {
        case standard
        case fast

        var displayName: String {
            switch self {
            case .standard:
                return "Standard Quality"
            case .fast:
                return "Fast Mode"
            }
        }

        var description: String {
            switch self {
            case .standard:
                return "Highest accuracy, slower processing"
            case .fast:
                return "Good accuracy, 50-70% faster"
            }
        }

        var detailedDescription: String {
            let gpt5Version = UserDefaults.standard.openAIVersion
            let openAIModel = gpt5Version.rawValue

            switch self {
            case .standard:
                return "Uses full AI models (\(openAIModel), Gemini-2.0-Pro, Claude-3.5-Sonnet) for maximum accuracy. Best for complex meals with multiple components."
            case .fast:
                return "Uses optimized models (\(openAIModel), Gemini-2.0-Flash) for faster analysis. 2-3x faster with ~5-10% accuracy trade-off. Great for simple meals."
            }
        }

        var iconName: String {
            switch self {
            case .standard:
                return "target"
            case .fast:
                return "bolt.fill"
            }
        }

        var iconColor: Color {
            switch self {
            case .standard:
                return .blue
            case .fast:
                return .orange
            }
        }

        var backgroundColor: Color {
            switch self {
            case .standard:
                return Color(.systemBlue).opacity(0.08)
            case .fast:
                return Color(.systemOrange).opacity(0.08)
            }
        }
    }

    /// Current analysis mode setting
    @Published var analysisMode = AnalysisMode(rawValue: UserDefaults.standard.analysisMode) ?? .standard

    /// Enable parallel processing for fastest results
    @Published var enableParallelProcessing: Bool = false

    /// Intelligent caching system for AI analysis results
    private var imageAnalysisCache = ImageAnalysisCache()

    /// Provider-specific optimized timeouts for better performance and user experience
    static func optimalTimeout(for provider: SearchProvider) -> TimeInterval {
        switch provider {
        case .googleGemini:
            return 15 // Free tier optimization - faster but may timeout on complex analysis
        case .openAI:
            // Check if using GPT-5 models which need more time
            switch UserDefaults.standard.openAIVersion {
            case .gpt4o:
                return 20 // GPT-4o models - good balance of speed and reliability
            case .gpt5_0,
                 .gpt5_1:
                return 60 // GPT-5 models need significantly more time for processing
            }
        case .claude:
            return 25 // Highest quality responses but slower processing
        case .openFoodFacts,
             .usdaFoodData:
            return 10 // Simple API calls should be fast
        }
    }

    /// Get optimal model for provider and analysis mode
    static func optimalModel(for provider: SearchProvider, mode: AnalysisMode) -> String {
        switch (provider, mode) {
        case (.googleGemini, .standard):
//            return "gemini-2.5-pro"
            return "gemini-3-pro-preview"
        case (.googleGemini, .fast):
            return "gemini-2.5-flash" // ~2x faster
        case (.openAI, .standard):
            // Use GPT-5 if user enabled it, otherwise use GPT-4o
            switch UserDefaults.standard.openAIVersion {
            case .gpt4o: return "gpt-4o"
            case .gpt5_0: return "gpt-5"
            case .gpt5_1: return "gpt-5.1"
            }
        case (.openAI, .fast):
            // Use GPT-5-nano for fastest analysis if user enabled GPT-5, otherwise use GPT-4o-mini
            switch UserDefaults.standard.openAIVersion {
            case .gpt4o: return "gpt-4o-mini"
            case .gpt5_0: return "gpt-5-mini" // TODO: nano or mini? gpt itself says nano is text-only
            case .gpt5_1: return "gpt-5.1" // no '-mini' or '-nano' at this point, but it will route to a specialized sub-model either way
            }
//            return UserDefaults.standard.useGPT5ForOpenAI ? "gpt-5-nano" : "gpt-4o-mini"
        case (.claude, .standard):
//            return "claude-opus-4-5"
            return "claude-sonnet-4-5"
        case (.claude, .fast):
            return "claude-haiku-4-5" // ~2x faster
        default:
            return "" // Not applicable for non-AI providers
        }
    }

    /// Safe async image optimization to prevent main thread blocking
    static func optimizeImageForAnalysisSafely(_ image: UIImage) async -> UIImage {
        await withCheckedContinuation { continuation in
            // Process image on background thread to prevent UI freezing
            DispatchQueue.global(qos: .userInitiated).async {
                let optimized = optimizeImageForAnalysis(image)
                continuation.resume(returning: optimized)
            }
        }
    }

    /// Intelligent image resizing for optimal AI analysis performance
    static func optimizeImageForAnalysis(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1024

        // Check if resizing is needed
        if image.size.width <= maxDimension, image.size.height <= maxDimension {
            return image // No resizing needed
        }

        // Calculate new size maintaining aspect ratio
        let scale = maxDimension / max(image.size.width, image.size.height)
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        // Perform high-quality resize
        return resizeImage(image, to: newSize)
    }

    /// High-quality image resizing helper
    private static func resizeImage(_ image: UIImage, to newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }

    /// Analyze image with network-aware provider strategy
    func analyzeImageWithParallelProviders(
        _ image: UIImage,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> AIFoodAnalysisResult {
        let networkMonitor = NetworkQualityMonitor.shared
        telemetryCallback?("🌐 Analyzing network conditions...")

        // Get available providers that support AI analysis
        let availableProviders: [SearchProvider] = [.googleGemini, .openAI, .claude].filter { provider in
            // Only include providers that have API keys configured
            switch provider {
            case .googleGemini:
                return !UserDefaults.standard.googleGeminiAPIKey.isEmpty
            case .openAI:
                return !UserDefaults.standard.openAIAPIKey.isEmpty
            case .claude:
                return !UserDefaults.standard.claudeAPIKey.isEmpty
            default:
                return false
            }
        }

        guard !availableProviders.isEmpty else {
            throw AIFoodAnalysisError.noApiKey
        }

        // Check network conditions and decide strategy
        if networkMonitor.shouldUseParallelProcessing, availableProviders.count > 1 {
            print("🌐 Good network detected, using parallel processing with \(availableProviders.count) providers")
            telemetryCallback?("⚡ Starting parallel AI provider analysis...")
            return try await analyzeImageWithParallelStrategy(
                image,
                providers: availableProviders,
                telemetryCallback: telemetryCallback
            )
        } else {
            print("🌐 Poor network detected, using sequential processing")
            telemetryCallback?("🔄 Starting sequential AI provider analysis...")
            return try await analyzeImageWithSequentialStrategy(
                image,
                providers: availableProviders,
                telemetryCallback: telemetryCallback
            )
        }
    }

    /// Parallel strategy for good networks
    private func analyzeImageWithParallelStrategy(
        _ image: UIImage,
        providers: [SearchProvider],
        telemetryCallback _: ((String) -> Void)?
    ) async throws -> AIFoodAnalysisResult {
        // Use the maximum timeout from all providers, with special handling for GPT-5
        let timeout = providers.map { provider in
            max(ConfigurableAIService.optimalTimeout(for: provider), NetworkQualityMonitor.shared.recommendedTimeout)
        }.max() ?? NetworkQualityMonitor.shared.recommendedTimeout

        return try await withThrowingTaskGroup(of: AIFoodAnalysisResult.self) { group in
            // Add timeout wrapper for each provider
            for provider in providers {
                group.addTask { [weak self] in
                    guard let self = self else { throw AIFoodAnalysisError.invalidResponse }
                    return try await withTimeoutForAnalysis(seconds: timeout) {
                        let startTime = Date()
                        do {
                            let result = try await self.analyzeImageWithSingleProvider(image, provider: provider)
                            let duration = Date().timeIntervalSince(startTime)
                            print("✅ \(provider.rawValue) succeeded in \(String(format: "%.1f", duration))s")
                            return result
                        } catch {
                            let duration = Date().timeIntervalSince(startTime)
                            print(
                                "❌ \(provider.rawValue) failed after \(String(format: "%.1f", duration))s: \(error.localizedDescription)"
                            )
                            throw error
                        }
                    }
                }
            }

            // Return the first successful result
            guard let result = try await group.next() else {
                throw AIFoodAnalysisError.invalidResponse
            }

            // Cancel remaining tasks since we got our result
            group.cancelAll()

            return result
        }
    }

    /// Sequential strategy for poor networks (photo) - tries providers one by one
    private func analyzeImageWithSequentialStrategy(
        _ image: UIImage,
        providers: [SearchProvider],
        telemetryCallback: ((String) -> Void)?
    ) async throws -> AIFoodAnalysisResult {
        // Use provider-specific timeout, with special handling for GPT-5
        let baseTimeout = NetworkQualityMonitor.shared.recommendedTimeout
        var lastError: Error?

        // Try providers one by one until one succeeds
        for provider in providers {
            do {
                // Use provider-specific timeout for each provider
                let providerTimeout = max(ConfigurableAIService.optimalTimeout(for: provider), baseTimeout)
                print("🔄 Trying \(provider.rawValue) sequentially with \(providerTimeout)s timeout...")
                telemetryCallback?("🤖 Trying \(provider.rawValue)...")
                let result = try await withTimeoutForAnalysis(seconds: providerTimeout) {
                    try await self.analyzeImageWithSingleProvider(image, provider: provider)
                }
                print("✅ \(provider.rawValue) succeeded in sequential mode")
                return result
            } catch {
                print("❌ \(provider.rawValue) failed in sequential mode: \(error.localizedDescription)")
                lastError = error
                // Continue to next provider
            }
        }

        // If all providers failed, throw the last error
        throw lastError ?? AIFoodAnalysisError.invalidResponse
    }

    /// Analyze photo with a single provider (helper for parallel processing)
    private func analyzeImageWithSingleProvider(
        _ image: UIImage,
        provider: SearchProvider
    ) async throws -> AIFoodAnalysisResult {
        let providerImpl = try getProviderImplementation(for: provider)
        return try await providerImpl.analyzeFoodImage(
            image,
            apiKey: UserDefaults.standard.googleGeminiAPIKey,
            telemetryCallback: nil
        )
    }

    /// Analyze text query with a single provider (helper for parallel processing)
    private func analyzeQueryWithSingleProvider(
        _ query: String,
        provider: SearchProvider
    ) async throws -> AIFoodAnalysisResult {
        let providerImpl = try getProviderImplementation(for: provider)
        return try await providerImpl.analyzeFoodQuery(
            query,
            apiKey: UserDefaults.standard.googleGeminiAPIKey,
            telemetryCallback: nil
        )
    }

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
