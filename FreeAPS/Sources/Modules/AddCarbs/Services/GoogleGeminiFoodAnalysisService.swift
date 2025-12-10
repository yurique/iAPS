import CoreML
import CryptoKit
import Foundation
import LoopKit
import Network
import os.log
import SwiftUI
import UIKit
import Vision

enum GoogleGeminiFoodAnalysisService {
    static func image(_ model: GeminiModel, apiKey: String) -> ImageAnalysisService {
        GoogleGeminiFoodAnalysisServiceWithModel(model: model, apiKey: apiKey)
    }

    static func text(_ model: GeminiModel, apiKey: String) -> TextAnalysisService {
        GoogleGeminiFoodAnalysisServiceWithModel(model: model, apiKey: apiKey)
    }
}

private struct GoogleGeminiFoodAnalysisServiceWithModel {
    let model: GeminiModel
    let apiKey: String
}

extension GoogleGeminiFoodAnalysisServiceWithModel: ImageAnalysisService {
    var needAggressiveImageCompression: Bool { model.needAggressiveImageCompression }

    func analyzeImage(
        prompt: String,
        images: [String],
        telemetryCallback: ((String) -> Void)?
    ) async throws -> FoodAnalysisResult {
        let response = try await GoogleGeminiFoodAnalysisServiceImpl.shared.executeQuery(
            model: model,
            prompt: prompt,
            images: images,
            apiKey: apiKey,
            telemetryCallback: telemetryCallback
        )

        return try decode(response, as: FoodAnalysisResult.self)
    }
}

extension GoogleGeminiFoodAnalysisServiceWithModel: TextAnalysisService {
    func analyzeText(
        prompt: String,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> [OpenFoodFactsProduct] {
        let response = try await GoogleGeminiFoodAnalysisServiceImpl.shared.executeQuery(
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

private final class GoogleGeminiFoodAnalysisServiceImpl {
    static let shared = GoogleGeminiFoodAnalysisServiceImpl()

    private let baseURLTemplate = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

    private init() {}

    func executeQuery(
        model: GeminiModel,
        prompt: String,
        images: [String],
        apiKey: String,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> String {
        print("🍱 Starting Google Gemini food analysis")
        telemetryCallback?("⚙️ Configuring Gemini parameters...")

        // Get optimal model based on current analysis mode
//        let analysisMode = ConfigurableAIService.shared.analysisMode

        let request = try buildRequest(
            model: model,
            prompt: prompt,
            images: images,
            apiKey: apiKey,
            telemetryCallback: telemetryCallback
        )

        telemetryCallback?("🌐 Sending request to Google Gemini...")

        do {
            telemetryCallback?("⏳ AI is cooking up results...")
            let (data, response) = try await URLSession.shared.data(for: request)

            telemetryCallback?("📥 Received response from Gemini...")

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Google Gemini: Invalid HTTP response")
                throw AIFoodAnalysisError.invalidResponse
            }

            if let bodyString = String(data: data, encoding: .utf8) {
                print("raw response: \(bodyString)")
            } else {
                print("raw response: <non-UTF8 data of length \(data.count)>")
            }

            try handleErrorResponse(httpResponse, data: data)

            // Parse Gemini response with Codable models
            let decoder = JSONDecoder()
            let geminiResponse = try decoder.decode(GeminiGenerateContentResponse.self, from: data)

            guard let firstCandidate = geminiResponse.candidates?.first else {
                print("❌ Google Gemini: No candidates in response")
                if let err = try? decoder.decode(GeminiErrorResponse.self, from: data) {
                    print("❌ Google Gemini: API returned error: \(err)")
                }
                throw AIFoodAnalysisError.responseParsingFailed
            }

            // Extract text from the first candidate's content parts (Codable)
            let parts: [GeminiPartResponse] = firstCandidate.content?.parts ?? []
            var textSegments: [String] = []
            for part in parts {
                if let t = part.text, !t.isEmpty {
                    textSegments.append(t)
                }
            }
            let text = textSegments.joined(separator: "\n").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            guard !text.isEmpty else {
                print("❌ Google Gemini: Invalid response structure or empty text")
                print("❌ Candidate: \(String(describing: firstCandidate))")
                throw AIFoodAnalysisError.responseParsingFailed
            }

            print("🔧 Google Gemini: Received text length: \(text.count)")

            return text
        } catch let error as AIFoodAnalysisError {
            throw error
        } catch {
            throw AIFoodAnalysisError.networkError(error)
        }
    }

    private func buildRequest(
        model: GeminiModel,
        prompt: String,
        images: [String],
        apiKey: String,
        telemetryCallback _: ((String) -> Void)?
    ) throws -> URLRequest {
        let baseURL = baseURLTemplate.replacingOccurrences(of: "{model}", with: model.rawValue)

        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw AIFoodAnalysisError.requestCreationFailed
        }

        let userTextPart = GeminiPart(text: prompt)
        let imageParts = images.map {
            GeminiPart(inline_data: GeminiInlineData(mime_type: "image/jpeg", data: $0))
        }

        let geminiRequest = GeminiGenerateContentRequest(
            contents: [GeminiContent(parts: [userTextPart] + imageParts)],
            generationConfig: GeminiGenerationConfig(
                temperature: 0.01,
                topP: 0.95,
                topK: 8,
                maxOutputTokens: 8000
            )
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(geminiRequest)
        } catch {
            throw AIFoodAnalysisError.requestCreationFailed
        }
        return request
    }

    private func handleErrorResponse(_ httpResponse: HTTPURLResponse, data: Data) throws {
        guard httpResponse.statusCode == 200 else {
            print("❌ Google Gemini API error: \(httpResponse.statusCode)")
            if let apiError = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data) {
                let message = apiError.error.message
                let status = apiError.error.status ?? ""
                print("❌ Gemini API Error: status=\(status), message=\(message)")

                // Handle common Gemini errors with specific error types
                if message.localizedCaseInsensitiveContains("quota") ||
                    message.localizedCaseInsensitiveContains("QUOTA_EXCEEDED") ||
                    status.localizedCaseInsensitiveContains("QUOTA_EXCEEDED")
                {
                    throw AIFoodAnalysisError.quotaExceeded(provider: "Google Gemini")
                } else if message.localizedCaseInsensitiveContains("RATE_LIMIT_EXCEEDED") ||
                    message.localizedCaseInsensitiveContains("rate limit") ||
                    status.localizedCaseInsensitiveContains("RATE_LIMIT_EXCEEDED")
                {
                    throw AIFoodAnalysisError.rateLimitExceeded(provider: "Google Gemini")
                } else if message.localizedCaseInsensitiveContains("PERMISSION_DENIED") ||
                    message.localizedCaseInsensitiveContains("API_KEY_INVALID") ||
                    status.localizedCaseInsensitiveContains("PERMISSION_DENIED")
                {
                    throw AIFoodAnalysisError
                        .customError("Invalid Google Gemini API key. Please check your configuration.")
                } else if message.localizedCaseInsensitiveContains("RESOURCE_EXHAUSTED") ||
                    status.localizedCaseInsensitiveContains("RESOURCE_EXHAUSTED")
                {
                    throw AIFoodAnalysisError.creditsExhausted(provider: "Google Gemini")
                }
            } else {
                print("❌ Gemini: Error data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            }

            // Handle HTTP status codes for common credit/quota issues
            if httpResponse.statusCode == 429 {
                throw AIFoodAnalysisError.rateLimitExceeded(provider: "Google Gemini")
            } else if httpResponse.statusCode == 403 {
                throw AIFoodAnalysisError.quotaExceeded(provider: "Google Gemini")
            }

            throw AIFoodAnalysisError.apiError(httpResponse.statusCode)
        }

        guard !data.isEmpty else {
            print("❌ Google Gemini: Empty response data")
            throw AIFoodAnalysisError.invalidResponse
        }
    }
}

// MARK: - Google Gemini Codable Models

// Request payload
struct GeminiGenerateContentRequest: Encodable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig
}

struct GeminiContent: Encodable {
    let parts: [GeminiPart]
}

struct GeminiPart: Encodable {
    let text: String?
    let inline_data: GeminiInlineData?

    init(text: String) {
        self.text = text
        inline_data = nil
    }

    init(inline_data: GeminiInlineData) {
        text = nil
        self.inline_data = inline_data
    }
}

struct GeminiInlineData: Encodable {
    let mime_type: String
    let data: String
}

struct GeminiGenerationConfig: Encodable {
    let temperature: Double
    let topP: Double
    let topK: Int
    let maxOutputTokens: Int
}

// Response payload
struct GeminiGenerateContentResponse: Decodable {
    let candidates: [GeminiCandidate]?
}

struct GeminiCandidate: Decodable {
    let content: GeminiContentResponse?
    let finishReason: String?
}

struct GeminiContentResponse: Decodable {
    let parts: [GeminiPartResponse]?
}

struct GeminiPartResponse: Decodable {
    let text: String?
}

// Error payload
struct GeminiErrorResponse: Decodable {
    struct APIError: Decodable {
        let code: Int?
        let message: String
        let status: String?
    }

    let error: APIError
}
