import CoreML
import CryptoKit
import Foundation
import LoopKit
import Network
import os.log
import SwiftUI
import UIKit
import Vision

// MARK: - Claude Food Analysis Service

/// Claude (Anthropic) food analysis service
class ClaudeFoodAnalysisService: FoodAnalysisService {
    static let shared = ClaudeFoodAnalysisService()
    private init() {}

    func analyzeFoodImage(
        _ image: UIImage,
        apiKey: String,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> AIFoodAnalysisResult {
        try await analyzeFoodRequest(.image(image), apiKey: apiKey, telemetryCallback: telemetryCallback)
    }

    func analyzeFoodQuery(
        _ query: String,
        apiKey: String,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> AIFoodAnalysisResult {
        try await analyzeFoodRequest(.query(query), apiKey: apiKey, telemetryCallback: telemetryCallback)
    }

    private func getImageBase64(
        for request: AnalysisRequest,
        model _: String,
        telemetryCallback: ((String) -> Void)?
    ) throws -> String? {
        switch request {
        case .query: return nil
        case let .image(image):
            let optimizedImage = ConfigurableAIService.optimizeImageForAnalysis(image)
            // Convert image to base64 with adaptive compression
            telemetryCallback?("🔄 Encoding image data...")
            let compressionQuality = ConfigurableAIService.adaptiveCompressionQuality(for: optimizedImage)
            guard let imageData = optimizedImage.jpegData(compressionQuality: compressionQuality) else {
                throw AIFoodAnalysisError.invalidResponse
            }
            return imageData.base64EncodedString()
        }
    }

    private func analyzeFoodRequest(
        _ analyticsRequest: AnalysisRequest,
        apiKey: String,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> AIFoodAnalysisResult {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AIFoodAnalysisError.invalidResponse
        }

        // Get optimal model based on current analysis mode
        telemetryCallback?("⚙️ Configuring Claude parameters...")
        let analysisMode = ConfigurableAIService.shared.analysisMode
        let model = ConfigurableAIService.optimalModel(for: .claude, mode: analysisMode)

        // Optimize image size for faster processing and uploads
        telemetryCallback?("🖼️ Optimizing your image...")
        let base64Image = try getImageBase64(for: analyticsRequest, model: "", telemetryCallback: telemetryCallback)

        // Prepare the request
        telemetryCallback?("📡 Preparing API request...")
        var request = URLRequest(url: url)
        request.timeoutInterval = 120 // 2 minutes for GPT-5 models
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Build Claude request using Codable models
        let analysisPrompt = getAnalysisPrompt(analyticsRequest)
        var contentItems: [ClaudeContent] = [
            .text(text: analysisPrompt)
        ]
        if let base64Image {
            let source = ClaudeImageSource(type: "base64", media_type: "image/jpeg", data: base64Image)
            contentItems.append(.image(source: source))
        }

        let messages: [ClaudeMessage] = [
            ClaudeMessage(role: "user", content: contentItems)
        ]

        let body = ClaudeMessagesRequest(
            model: model,
            max_tokens: 8000,
            temperature: 0.01,
            messages: messages
        )

        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
        } catch {
            throw AIFoodAnalysisError.requestCreationFailed
        }

        telemetryCallback?("🌐 Sending request to Claude...")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 150 // 2.5 minutes request timeout
        config.timeoutIntervalForResource = 180 // 3 minutes resource timeout
        let session = URLSession(configuration: config)

        // Make the request
        telemetryCallback?("⏳ AI is cooking up results...")
        let (data, response) = try await session.data(for: request)

        telemetryCallback?("📥 Received response from Claude...")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Claude: Invalid HTTP response")
            throw AIFoodAnalysisError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let apiError = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data) {
                let message = apiError.error.message
                let type = apiError.error.type ?? ""
                print("❌ Claude API Error: type=\(type), message=\(message)")

                // Handle common Claude errors with specific error types
                if message.localizedCaseInsensitiveContains("credit") || message
                    .localizedCaseInsensitiveContains("billing") || message.localizedCaseInsensitiveContains("usage")
                {
                    throw AIFoodAnalysisError.creditsExhausted(provider: "Claude")
                } else if message.localizedCaseInsensitiveContains("rate_limit") || message
                    .localizedCaseInsensitiveContains("rate limit")
                {
                    throw AIFoodAnalysisError.rateLimitExceeded(provider: "Claude")
                } else if message.localizedCaseInsensitiveContains("quota") || message.localizedCaseInsensitiveContains("limit") {
                    throw AIFoodAnalysisError.quotaExceeded(provider: "Claude")
                } else if message
                    .localizedCaseInsensitiveContains("authentication") ||
                    (message.localizedCaseInsensitiveContains("invalid") && message.localizedCaseInsensitiveContains("key"))
                {
                    throw AIFoodAnalysisError.customError("Invalid Claude API key. Please check your configuration.")
                }
            } else {
                print("❌ Claude: Error data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            }

            // Handle HTTP status codes for common credit/quota issues
            if httpResponse.statusCode == 429 {
                throw AIFoodAnalysisError.rateLimitExceeded(provider: "Claude")
            } else if httpResponse.statusCode == 402 {
                throw AIFoodAnalysisError.creditsExhausted(provider: "Claude")
            } else if httpResponse.statusCode == 403 {
                throw AIFoodAnalysisError.quotaExceeded(provider: "Claude")
            }

            throw AIFoodAnalysisError.apiError(httpResponse.statusCode)
        }

        // Enhanced data validation like Gemini
        guard !data.isEmpty else {
            print("❌ Claude: Empty response data")
            throw AIFoodAnalysisError.invalidResponse
        }

        // Parse response
        telemetryCallback?("🔍 Parsing Claude response...")
        let decoder = JSONDecoder()
        let claudeResponse = try decoder.decode(ClaudeMessagesResponse.self, from: data)

        guard let contentItems = claudeResponse.content, !contentItems.isEmpty else {
            print("❌ Claude: Invalid response structure - no content items")
            if let raw = String(data: data, encoding: .utf8) {
                print("❌ Claude: Raw response: \(raw)")
            }
            throw AIFoodAnalysisError.responseParsingFailed
        }

        // Extract first text segment from content
        guard let text = contentItems.first(where: { ($0.type == nil || $0.type == "text") && ($0.text?.isEmpty == false) })?
            .text
        else {
            print("❌ Claude: No text content in response")
            if let raw = String(data: data, encoding: .utf8) {
                print("❌ Claude: Raw response: \(raw)")
            }
            throw AIFoodAnalysisError.responseParsingFailed
        }

        // Add detailed logging like Gemini
        print("🔧 Claude: Received text length: \(text.count)")

        // Parse the JSON response from Claude
        telemetryCallback?("⚡ Processing AI analysis results...")
        return try parseClaudeAnalysis(text)
    }

    private func parseClaudeAnalysis(_ text: String) throws -> AIFoodAnalysisResult {
        // Clean the text and extract JSON from Claude's response
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Safely extract JSON content with proper bounds checking
        var jsonString: String
        if let jsonStartRange = cleanedText.range(of: "{"),
           let jsonEndRange = cleanedText.range(of: "}", options: .backwards),
           jsonStartRange.lowerBound < jsonEndRange.upperBound
        { // Ensure valid range
            // Safely extract from start brace to end brace (inclusive)
            jsonString = String(cleanedText[jsonStartRange.lowerBound ..< jsonEndRange.upperBound])
        } else {
            // If no clear JSON boundaries, assume the whole cleaned text is JSON
            jsonString = cleanedText
        }

        // Additional safety check for empty JSON
        if jsonString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            jsonString = cleanedText
        }

        print("🔧 Claude: Attempting to parse JSON: \(jsonString.prefix(300))...")

        // Enhanced JSON parsing with error recovery
        var json: [String: Any]
        do {
            guard let jsonData = jsonString.data(using: .utf8),
                  let parsedJson = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            else {
                print("❌ Claude: Failed to parse extracted JSON")
                print("❌ Claude: JSON string was: \(jsonString.prefix(500))...")
                throw AIFoodAnalysisError.responseParsingFailed
            }
            json = parsedJson
        } catch {
            print("❌ Claude: JSON parsing error: \(error)")
            print("❌ Claude: Problematic JSON: \(jsonString.prefix(500))...")

            // Try fallback parsing with the original cleaned text
            if let fallbackData = cleanedText.data(using: .utf8),
               let fallbackJson = try? JSONSerialization.jsonObject(with: fallbackData) as? [String: Any]
            {
                json = fallbackJson
            } else {
                throw AIFoodAnalysisError.responseParsingFailed
            }
        }

        // Parse food items with enhanced safety like Gemini
        var foodItems: [FoodItemAnalysis] = []

        do {
            if let foodItemsArray = json["food_items"] as? [[String: Any]] {
                // Enhanced per-item error handling like Gemini
                for (_, item) in foodItemsArray.enumerated() {
                    do {
                        let foodItem = FoodItemAnalysis(
                            name: extractClaudeString(from: item, keys: ["name"]) ?? "Unknown Food",
                            portionEstimate: extractClaudeString(from: item, keys: ["portion_estimate"]) ?? "1 serving",
                            standardServingSize: extractClaudeString(from: item, keys: ["standard_serving_size"]),
                            servingsStandard: extractClaudeString(from: item, keys: ["serving_standard"]),
                            servingMultiplier: max(0.1, extractClaudeNumber(from: item, keys: ["serving_multiplier"]) ?? 1.0),
                            // Prevent zero/negative
                            preparationMethod: extractClaudeString(from: item, keys: ["preparation_method"]),
                            visualCues: extractClaudeString(from: item, keys: ["visual_cues"]),
                            carbohydrates: max(0, extractClaudeNumber(from: item, keys: ["carbohydrates"]) ?? 0),
                            // Ensure non-negative
                            calories: extractClaudeNumber(from: item, keys: ["calories"]).map { max(0, $0) }, // Bounds checking
                            fat: extractClaudeNumber(from: item, keys: ["fat"]).map { max(0, $0) }, // Bounds checking
                            fiber: extractClaudeNumber(from: item, keys: ["fiber"]).map { max(0, $0) }, // Bounds checking
                            protein: extractClaudeNumber(from: item, keys: ["protein"]).map { max(0, $0) }, // Bounds checking
                            assessmentNotes: extractClaudeString(from: item, keys: ["assessment_notes"])
                        )
                        foodItems.append(foodItem)
                    }
                }
            }
        }

        // TODO: why?
        // Enhanced fallback creation like Gemini - safe fallback with comprehensive data
        if foodItems.isEmpty {
            let totalCarbs = extractClaudeNumber(from: json, keys: ["total_carbohydrates"]) ?? 25.0
            let totalProtein = extractClaudeNumber(from: json, keys: ["total_protein"])
            let totalFat = extractClaudeNumber(from: json, keys: ["total_fat"])
            let totalFiber = extractClaudeNumber(from: json, keys: ["total_fiber"])
            let totalCalories = extractClaudeNumber(from: json, keys: ["total_calories"])

            foodItems = [
                FoodItemAnalysis(
                    name: "Claude Analyzed Food",
                    portionEstimate: "1 standard serving",
                    standardServingSize: nil,
                    servingsStandard: nil,
                    servingMultiplier: 1.0,
                    preparationMethod: "Not specified in analysis",
                    visualCues: "Visual analysis completed",
                    carbohydrates: max(0, totalCarbs), // Ensure non-negative
                    calories: totalCalories.map { max(0, $0) }, // Bounds checking
                    fat: totalFat.map { max(0, $0) }, // Bounds checking
                    fiber: totalFiber.map { max(0, $0) },
                    protein: totalProtein.map { max(0, $0) }, // Bounds checking
                    assessmentNotes: "Safe fallback nutrition estimate - please verify actual food for accuracy"
                )
            ]
        }

        let confidence = extractConfidence(from: json)

        // Extract image type to determine if this is menu analysis or food photo
        let imageTypeString = json["image_type"] as? String
        let imageType = ImageAnalysisType(rawValue: imageTypeString ?? "food_photo") ?? .foodPhoto

        // Calculate original servings for proper scaling
        let originalServings = foodItems.reduce(0) { $0 + $1.servingMultiplier }

        return AIFoodAnalysisResult(
            imageType: imageType,
            foodItemsDetailed: foodItems,
            overallDescription: ConfigurableAIService.cleanFoodText(json["overall_description"] as? String),
            confidence: confidence,
            totalFoodPortions: (json["total_food_portions"] as? Double).map { Int($0) },
            totalStandardServings: json["total_standard_servings"] as? Double,
            servingsStandard: json["serving_standard"] as? String,
            totalCarbohydrates: json["total_carbohydrates"] as? Double ?? foodItems.reduce(0) { $0 + $1.carbohydrates },
            totalProtein: json["total_protein"] as? Double ?? foodItems.compactMap(\.protein).reduce(0, +),
            totalFat: json["total_fat"] as? Double ?? foodItems.compactMap(\.fat).reduce(0, +),
            totalFiber: json["total_fiber"] as? Double ?? foodItems.compactMap(\.fiber).reduce(0, +),
            totalCalories: json["total_calories"] as? Double ?? foodItems.compactMap(\.calories).reduce(0, +),
            portionAssessmentMethod: json["portion_assessment_method"] as? String,
            diabetesConsiderations: json["diabetes_considerations"] as? String,
            visualAssessmentDetails: json["visual_assessment_details"] as? String,
            notes: "Analysis provided by Claude (Anthropic)",
            originalServings: originalServings,
            fatProteinUnits: json["fat_protein_units"] as? String,
            netCarbsAdjustment: json["net_carbs_adjustment"] as? String,
            insulinTimingRecommendations: json["insulin_timing_recommendations"] as? String,
            fpuDosingGuidance: json["fpu_dosing_guidance"] as? String,
            exerciseConsiderations: json["exercise_considerations"] as? String,
            absorptionTimeHours: json["absorption_time_hours"] as? Double,
            absorptionTimeReasoning: json["absorption_time_reasoning"] as? String,
            mealSizeImpact: json["meal_size_impact"] as? String,
            individualizationFactors: json["individualization_factors"] as? String,
            safetyAlerts: json["safety_alerts"] as? String
        )
    }

    // MARK: - Claude Helper Methods

    private func extractClaudeNumber(from json: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = json[key] as? Double {
                return max(0, value) // Ensure non-negative nutrition values like Gemini
            } else if let value = json[key] as? Int {
                return max(0, Double(value)) // Ensure non-negative
            } else if let value = json[key] as? String, let doubleValue = Double(value) {
                return max(0, doubleValue) // Ensure non-negative
            }
        }
        return nil
    }

    private func extractClaudeString(from json: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = json[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value.trimmingCharacters(in: .whitespacesAndNewlines) // Enhanced validation like Gemini
            }
        }
        return nil
    }

    private func extractConfidence(from json: [String: Any]) -> AIConfidenceLevel {
        let confidenceKeys = ["confidence", "confidence_score"]

        for key in confidenceKeys {
            if let value = json[key] as? Double {
                if value >= 0.8 {
                    return .high
                } else if value >= 0.5 {
                    return .medium
                } else {
                    return .low
                }
            } else if let value = json[key] as? String {
                // Enhanced string-based confidence detection like Gemini
                switch value.lowercased() {
                case "high":
                    return .high
                case "medium":
                    return .medium
                case "low":
                    return .low
                default:
                    continue
                }
            }
        }

        return .medium // Default to medium instead of assuming high
    }
}

// MARK: - Claude / Anthropic Codable Models (Request/Response/Error)

// Request
struct ClaudeMessagesRequest: Encodable {
    let model: String
    let max_tokens: Int
    let temperature: Double
    let messages: [ClaudeMessage]
}

struct ClaudeMessage: Encodable {
    let role: String
    let content: [ClaudeContent]
}

enum ClaudeContent: Encodable {
    case text(text: String)
    case image(source: ClaudeImageSource)

    enum CodingKeys: String, CodingKey { case type, text, source }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .text(text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case let .image(source):
            try container.encode("image", forKey: .type)
            try container.encode(source, forKey: .source)
        }
    }
}

struct ClaudeImageSource: Encodable {
    let type: String // "base64"
    let media_type: String // e.g., "image/jpeg"
    let data: String // base64-encoded image
}

// Response
struct ClaudeMessagesResponse: Decodable {
    let content: [ClaudeMessageContent]?
}

struct ClaudeMessageContent: Decodable {
    let type: String?
    let text: String?
}

// Error Response
struct ClaudeErrorResponse: Decodable {
    struct APIError: Decodable {
        let type: String?
        let message: String
        let code: String?
    }

    let error: APIError
}
