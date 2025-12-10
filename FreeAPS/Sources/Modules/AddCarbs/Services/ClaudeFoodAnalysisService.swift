import CoreML
import CryptoKit
import Foundation
import LoopKit
import Network
import os.log
import SwiftUI
import UIKit
import Vision

enum ClaudeFoodAnalysisService {
    static func image(_ model: ClaudeModel, apiKey: String) -> ImageAnalysisService {
        ClaudeFoodAnalysisServiceWithModel(model: model, apiKey: apiKey)
    }

    static func text(_ model: ClaudeModel, apiKey: String) -> TextAnalysisService {
        ClaudeFoodAnalysisServiceWithModel(model: model, apiKey: apiKey)
    }
}

private struct ClaudeFoodAnalysisServiceWithModel {
    let model: ClaudeModel
    let apiKey: String
}

extension ClaudeFoodAnalysisServiceWithModel: ImageAnalysisService {
    var needAggressiveImageCompression: Bool { model.needAggressiveImageCompression }

    func analyzeImage(
        prompt: String,
        images: [String],
        telemetryCallback: ((String) -> Void)?
    ) async throws -> FoodAnalysisResult {
        let response = try await ClaudeFoodAnalysisServiceImpl.shared.executeQuery(
            model: model,
            prompt: prompt,
            images: images,
            apiKey: apiKey,
            telemetryCallback: telemetryCallback
        )

        return try decode(response, as: FoodAnalysisResult.self)
    }
}

extension ClaudeFoodAnalysisServiceWithModel: TextAnalysisService {
    func analyzeText(
        prompt: String,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> [OpenFoodFactsProduct] {
        let response = try await ClaudeFoodAnalysisServiceImpl.shared.executeQuery(
            model: model,
            prompt: prompt,
            images: [],
            apiKey: apiKey,
            telemetryCallback: telemetryCallback
        )

        let result = try decode(response, as: FoodAnalysisResult.self)
        return toOpenFoodFactsProducts(model: model, result: result)
    }
}

private final class ClaudeFoodAnalysisServiceImpl {
    static let shared = ClaudeFoodAnalysisServiceImpl()
    private init() {}

    func executeQuery(
        model: ClaudeModel,
        prompt: String,
        images: [String],
        apiKey: String,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> String {
        // Get optimal model based on current analysis mode
        telemetryCallback?("⚙️ Configuring Claude parameters...")
//        let analysisMode = ConfigurableAIService.shared.analysisMode

        let request = try buildRequest(
            model: model,
            prompt: prompt,
            images: images,
            apiKey: apiKey,
            telemetryCallback: telemetryCallback
        )

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

        try handleErrorResponse(httpResponse, data: data)

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

        return text
    }

    private func buildRequest(
        model: ClaudeModel,
        prompt: String,
        images: [String],
        apiKey: String,
        telemetryCallback: ((String) -> Void)?
    ) throws -> URLRequest {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AIFoodAnalysisError.requestCreationFailed
        }

        telemetryCallback?("📡 Preparing API request...")
        var request = URLRequest(url: url)
        request.timeoutInterval = 120 // 2 minutes for GPT-5 models
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let textPart = ClaudeContent.text(text: prompt)
        let imageParts = images.map {
            ClaudeContent.image(
                source: ClaudeImageSource(type: "base64", media_type: "image/jpeg", data: $0)
            )
        }

        let messages: [ClaudeMessage] = [
            ClaudeMessage(
                role: "user",
                content: [textPart] + imageParts
            )
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

        return request
    }

    private func handleErrorResponse(_ httpResponse: HTTPURLResponse, data: Data) throws {
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
    }
}

// MARK: - Claude / Anthropic Codable Models (Request/Response/Error)

// Request
struct ClaudeMessagesRequest: Encodable {
    let model: ClaudeModel
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
