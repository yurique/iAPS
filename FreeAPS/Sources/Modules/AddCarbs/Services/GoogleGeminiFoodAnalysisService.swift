import CoreML
import CryptoKit
import Foundation
import LoopKit
import Network
import os.log
import SwiftUI
import UIKit
import Vision

// MARK: - Google Gemini Food Analysis Service

/// Service for food analysis using Google Gemini Vision API (free tier)
class GoogleGeminiFoodAnalysisService: FoodAnalysisService {
    static let shared = GoogleGeminiFoodAnalysisService()

    private let baseURLTemplate = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

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
                throw AIFoodAnalysisError.imageProcessingFailed
            }
            return imageData.base64EncodedString()
        }
    }

    private func analyzeFoodRequest(
        _ analysisRequest: AnalysisRequest,
        apiKey: String,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> AIFoodAnalysisResult {
        print("🍱 Starting Google Gemini food analysis")
        telemetryCallback?("⚙️ Configuring Gemini parameters...")

        // Get optimal model based on current analysis mode
        let analysisMode = ConfigurableAIService.shared.analysisMode
        let model = ConfigurableAIService.optimalModel(for: .googleGemini, mode: analysisMode)
        let baseURL = baseURLTemplate.replacingOccurrences(of: "{model}", with: model)

        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw AIFoodAnalysisError.requestCreationFailed
        }

        // Optimize image size for faster processing and uploads
        telemetryCallback?("🖼️ Optimizing your image...")
        let base64Image = try getImageBase64(for: analysisRequest, model: "", telemetryCallback: telemetryCallback)

        // Build Gemini request using Codable models
        let userTextPart = GeminiPart(text: getAnalysisPrompt(analysisRequest))
        var requestParts: [GeminiPart] = [userTextPart]
        if let base64Image {
            let inline = GeminiInlineData(mime_type: "image/jpeg", data: base64Image)
            requestParts.append(GeminiPart(inline_data: inline))
        }

        let geminiRequest = GeminiGenerateContentRequest(
            contents: [GeminiContent(parts: requestParts)],
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

            // Add data validation
            guard !data.isEmpty else {
                print("❌ Google Gemini: Empty response data")
                throw AIFoodAnalysisError.invalidResponse
            }

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

            var cleanedText = text
            // Remove markdown fences and stray backticks
            cleanedText = cleanedText.replacingOccurrences(of: "```json", with: "")
            cleanedText = cleanedText.replacingOccurrences(of: "```", with: "")
            cleanedText = cleanedText.replacingOccurrences(of: "`", with: "")
            cleanedText = cleanedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            // Extract JSON substring between first "{" and last "}" if present
            if let start = cleanedText.firstIndex(of: "{"),
               let end = cleanedText.lastIndex(of: "}"),
               start <= end
            {
                cleanedText = String(cleanedText[start ... end])
            }

            guard let jsonData = cleanedText.data(using: .utf8) else {
                throw AIFoodAnalysisError.responseParsingFailed
            }

            do {
                let resultDecoder = JSONDecoder()
                return try resultDecoder.decode(AIFoodAnalysisResult.self, from: jsonData)
            } catch {
                print("❌ JSON decode error: \(error)")
                print("❌ JSON content:\n\(cleanedText)")
                throw AIFoodAnalysisError.responseParsingFailed
            }
        } catch let error as AIFoodAnalysisError {
            throw error
        } catch {
            throw AIFoodAnalysisError.networkError(error)
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
