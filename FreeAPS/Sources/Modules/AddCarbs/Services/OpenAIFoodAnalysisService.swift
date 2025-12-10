import CoreML
import CryptoKit
import Foundation
import LoopKit
import Network
import os.log
import SwiftUI
import UIKit
import Vision

enum OpenAIFoodAnalysisService {
    static func image(_ model: OpenAIModel, apiKey: String) -> ImageAnalysisService {
        OpenAIFoodANalysisServiceWithModel(model: model, apiKey: apiKey)
    }

    static func text(_ model: OpenAIModel, apiKey: String) -> TextAnalysisService {
        OpenAIFoodANalysisServiceWithModel(model: model, apiKey: apiKey)
    }
}

private struct OpenAIFoodANalysisServiceWithModel {
    let model: OpenAIModel
    let apiKey: String
}

extension OpenAIFoodANalysisServiceWithModel: ImageAnalysisService {
    var needAggressiveImageCompression: Bool { model.needAggressiveImageCompression }

    func analyzeImage(
        prompt: String,
        images: [String],
        telemetryCallback: ((String) -> Void)?
    ) async throws -> FoodAnalysisResult {
        let response = try await OpenAIFoodAnalysisServiceImpl.shared.executeQuery(
            model: model,
            prompt: prompt,
            images: images,
            apiKey: apiKey,
            telemetryCallback: telemetryCallback
        )

        return try decode(response, as: FoodAnalysisResult.self)
    }
}

extension OpenAIFoodANalysisServiceWithModel: TextAnalysisService {
    func analyzeText(
        prompt: String,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> [OpenFoodFactsProduct] {
        let response = try await OpenAIFoodAnalysisServiceImpl.shared.executeQuery(
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

private final class OpenAIFoodAnalysisServiceImpl {
    static let shared = OpenAIFoodAnalysisServiceImpl()
    private init() {}

    private let apiURL = URL(string: "https://api.openai.com/v1/responses")!

    func executeQuery(
        model: OpenAIModel,
        prompt: String,
        images: [String],
        apiKey: String,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> String {
        // Get optimal model based on current analysis mode
        telemetryCallback?("⚙️ Configuring OpenAI parameters...")
//        let analysisMode = ConfigurableAIService.shared.analysisMode
//        let model = ConfigurableAIService.optimalModel(for: .openAI, mode: analysisMode)
//        let openaAIVersion = UserDefaults.standard.openAIVersion

        print("🤖 OpenAI Model Selection:")
//        print("   Analysis Mode: \(analysisMode.rawValue)")
        print("   Selected Model: \(model)")

        // Optimize image size for faster processing and uploads
        telemetryCallback?("🖼️ Optimizing your image...")

        let urlRequest: URLRequest = try buildRequest(
            model: model,
            prompt: prompt,
            images: images,
            apiKey: apiKey,
            telemetryCallback: telemetryCallback
        )

//        do {
//            // Debug logging for GPT-5 requests
//            if model.contains("gpt-5") {
//                print("🔧 GPT-5 Debug - Request payload keys: \(payload.keys.sorted())")
//                if let bodyData = request.httpBody,
//                   let bodyString = String(data: bodyData, encoding: .utf8)
//                {
//                    print("🔧 GPT-5 Debug - Request body length: \(bodyString.count) characters")
//                    print("🔧 GPT-5 Debug - Request contains image: \(bodyString.contains("image_url"))")
//                    print("🔧 GPT-5 Debug - Request contains response_format: \(bodyString.contains("response_format"))")
//                }
//            }
//        } catch {
//            throw AIFoodAnalysisError.requestCreationFailed
//        }

        telemetryCallback?("🌐 Sending request to OpenAI...")

        do {
//            if isAdvancedPrompt {
//                telemetryCallback?("⏳ Doing a deep analysis (may take a bit)...")
//            } else {
            telemetryCallback?("⏳ AI is cooking up results...")
//            }

            // Use enhanced timeout logic with retry for GPT-5
            let (data, response): (Data, URLResponse) = try await performRequestWithRetry(
                request: urlRequest,
                model: model,
                telemetryCallback: telemetryCallback
            )

            if let bodyString = String(data: data, encoding: .utf8) {
                print("raw response: \(bodyString)")
            } else {
                print("raw response: <non-UTF8 data of length \(data.count)>")
            }

//            if model.contains("gpt-5") {
//                do {
//                    // GPT-5 requires special handling with retries and extended timeout
//                    (data, response) = try await performGPT5RequestWithRetry(
//                        request: request,
//                        telemetryCallback: telemetryCallback
//                    )
//                } catch let error as AIFoodAnalysisError where error.localizedDescription.contains("GPT-5 timeout") {
//                    // GPT-5 failed, immediately retry with GPT-4o
//                    print("🔄 Immediate fallback: Retrying with GPT-4o after GPT-5 failure")
//                    telemetryCallback?("🔄 Retrying with GPT-4o...")
//
//                    return try await retryWithGPT4Fallback(
//                        image: image,
//                        query: query,
//                        apiKey: apiKey,
//
//                        analysisPrompt: analysisPrompt,
//                        isAdvancedPrompt: isAdvancedPrompt,
//
//                        telemetryCallback: telemetryCallback
//                    )
//                }
//            } else {
//                // Standard GPT-4 processing
//                (data, response) = try await URLSession.shared.data(for: request)
//            }

            telemetryCallback?("📥 Received response from OpenAI...")

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ OpenAI: Invalid HTTP response")
                throw AIFoodAnalysisError.invalidResponse
            }

            // Decode error response JSON at the top of non-200 error block
            if httpResponse.statusCode != 200 {
                if let apiError = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                    let message = apiError.error.message ?? "Unknown error"
                    let code = apiError.error.code ?? apiError.error.type ?? ""
                    print("❌ OpenAI API Error: code=\(code), message=\(message)")

                    switch code {
                    case "insufficient_quota":
                        throw AIFoodAnalysisError.creditsExhausted(provider: "OpenAI")
                    case "rate_limit_exceeded":
                        throw AIFoodAnalysisError.rateLimitExceeded(provider: "OpenAI")
                    case "invalid_api_key":
                        throw AIFoodAnalysisError.customError("Invalid OpenAI API key. Please check your configuration.")
                    case "model_not_found":
                        // TODO: do we do fallbacks?
                        if model.isGPT5 {
                            print("⚠️ GPT-5 model not available, falling back to GPT-4o...")
                            throw AIFoodAnalysisError.customError(
                                "GPT-5 not available yet. Switched to GPT-4o automatically. You can try enabling GPT-5 again later."
                            )
                        }
                    default:
                        // Fallback to message inspection for unknown codes
                        if message.localizedCaseInsensitiveContains("quota") {
                            throw AIFoodAnalysisError.creditsExhausted(provider: "OpenAI")
                        } else if message.localizedCaseInsensitiveContains("rate limit") {
                            throw AIFoodAnalysisError.rateLimitExceeded(provider: "OpenAI")
                        } else if message.localizedCaseInsensitiveContains("invalid"),
                                  message.localizedCaseInsensitiveContains("key")
                        {
                            throw AIFoodAnalysisError.customError("Invalid OpenAI API key. Please check your configuration.")
                        } else if message.localizedCaseInsensitiveContains("model"),
                                  message.localizedCaseInsensitiveContains("not found")
                        {
                            if model.isGPT5 {
                                print("⚠️ GPT-5 model not available, falling back to GPT-4o...")
                                throw AIFoodAnalysisError.customError(
                                    "GPT-5 not available yet. Switched to GPT-4o automatically. You can try enabling GPT-5 again later."
                                )
                            }
                        }
                    }
                } else {
                    print("❌ OpenAI: Error data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                }

                // Handle HTTP status codes for common credit/quota issues
                if httpResponse.statusCode == 429 {
                    throw AIFoodAnalysisError.rateLimitExceeded(provider: "OpenAI")
                } else if httpResponse.statusCode == 402 {
                    throw AIFoodAnalysisError.creditsExhausted(provider: "OpenAI")
                } else if httpResponse.statusCode == 403 {
                    throw AIFoodAnalysisError.quotaExceeded(provider: "OpenAI")
                }

                // Generic API error for unhandled cases
                throw AIFoodAnalysisError.apiError(httpResponse.statusCode)
            }

            // Enhanced data validation like Gemini
            guard !data.isEmpty else {
                print("❌ OpenAI: Empty response data")
                throw AIFoodAnalysisError.invalidResponse
            }

            // Parse OpenAI response (new /responses API only)
            telemetryCallback?("🔍 Parsing OpenAI response...")

            // Decode as /responses payload
            let decoder = JSONDecoder()
            let responsesPayload = try decoder.decode(OpenAIResponsesResponse.self, from: data)

            guard let content = extractContent(from: responsesPayload), !content.isEmpty else {
                print("❌ OpenAI: Could not extract content from /responses payload (struct)")
                print("❌ OpenAI: Response payload: \(responsesPayload)")
                throw AIFoodAnalysisError.responseParsingFailed
            }

            // Add detailed logging like Gemini
            print("🔧 OpenAI: Received content length: \(content.count)")

            // Check for empty content from GPT-5 and auto-fallback to GPT-4o
            if content.isEmpty {
                print("❌ OpenAI: Empty content received")
                print("❌ OpenAI: Model used: \(model)")
                print("❌ OpenAI: HTTP Status: \(httpResponse.statusCode)")

//                if model.contains("gpt-5") || model.contains("gpt-5.1"), UserDefaults.standard.openAIVersion != .gpt4o {
//                    print("⚠️ GPT-5 returned empty response, automatically switching to GPT-4o...")
//                    DispatchQueue.main.async {
//                        UserDefaults.standard.openAIVersion = .gpt4o
//                    }
//                    throw AIFoodAnalysisError
//                        .customError("GPT-5 returned empty response. Automatically switched to GPT-4o for next analysis.")
//                }

                throw AIFoodAnalysisError.responseParsingFailed
            }

            // Enhanced JSON extraction from GPT-4's response (like Claude service)
            telemetryCallback?("⚡ Processing AI analysis results...")

            return content
        } catch let error as AIFoodAnalysisError {
            throw error
        } catch {
            throw AIFoodAnalysisError.networkError(error)
        }
    }

    // Unified content extraction for /responses
    // Priority order:
    // 1) output_text (string)
    // 2) output (array of segments with type/text)
    // 3) content (array) with items that may contain text or nested message content
    private func extractContent(from payload: OpenAIResponsesResponse) -> String? {
        // Case 1: output_text
        if let outputText = payload.output_text, !outputText.isEmpty {
            return outputText
        }

        // Case 2: output array of messages with nested content
        if let output = payload.output, !output.isEmpty {
            var parts: [String] = []
            for message in output {
                if let items = message.content {
                    for item in items {
                        if let t = item.text, item.type == nil || item.type == "output_text" {
                            parts.append(t)
                        }
                    }
                }
            }
            if !parts.isEmpty { return parts.joined(separator: "\n") }
        }

        // Case 3: content array
        if let contentArr = payload.content, !contentArr.isEmpty {
            let parts = contentArr.compactMap { $0.text ?? $0.message?.content }
            if !parts.isEmpty { return parts.joined(separator: "\n") }
        }

        return nil
    }

    private func buildRequest(
        model: OpenAIModel,
        prompt: String,
        images: [String],
        apiKey: String,
        telemetryCallback: ((String) -> Void)?
    ) throws -> URLRequest {
        telemetryCallback?("📡 Preparing API request...")

        // Create OpenAI API request
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Set appropriate timeout based on model type and prompt complexity
        if model.isGPT5 {
            request.timeoutInterval = 120 // 2 minutes for GPT-5 models
        } else {
            request.timeoutInterval = 120 // 2 minutes for GPT-4 models
        }
        print(
            "🔧 \(model) Timeout - Model: \(model), Timeout: \(request.timeoutInterval)s, Prompt: \(prompt.count) chars"
        )

        // Use appropriate parameters based on model type
        print("🔍 OpenAI Final Prompt Debug:")
        print("   Analysis prompt length: \(prompt.count) characters")
        print("   First 100 chars of analysis prompt: \(String(prompt.prefix(100)))")

        let textPart = OpenAIResponsesContent.input_text(text: prompt)
        let imageParts = images.map {
            OpenAIResponsesContent.input_image(imageURL: "data:image/jpeg;base64,\($0)")
        }

        let inputMessages: [OpenAIResponsesMessage] = [
            OpenAIResponsesMessage(role: "user", content: [textPart] + imageParts)
        ]

        var textOptions: OpenAIResponsesTextOptions?
        var stream: Bool?
        if model.isGPT5 {
            textOptions = OpenAIResponsesTextOptions(format: .init(type: "json_object"))
            stream = false // Ensure complete response (no streaming)
            telemetryCallback?("⚡ Using \(model) optimized settings...")
        } else {
//            if isAdvancedPrompt {
//                print("🔧 \(model) Advanced - Using 6000 max_output_tokens for comprehensive analysis")
//            }
        }

        let body = OpenAIResponsesRequest(
            model: model,
            input: inputMessages,
            max_output_tokens: 6000,
            temperature: 0.01,
            text: textOptions,
            stream: stream
        )

        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
        } catch {
            throw AIFoodAnalysisError.requestCreationFailed
        }

        return request
    }

    private func performRequest(
        request: URLRequest,
        model: OpenAIModel,
        attempt: Int,
        maxRetries: Int,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> (Data, URLResponse) {
        do {
            print("🔧 \(model) Debug - Attempt \(attempt)/\(maxRetries)")
            telemetryCallback?("🔄 \(model) attempt \(attempt)/\(maxRetries)...")

            let config = URLSessionConfiguration.default
            if model.isGPT5 {
                //  extended timeout for GPT-5
                config.timeoutIntervalForRequest = 150 // 2.5 minutes request timeout
                config.timeoutIntervalForResource = 180 // 3 minutes resource timeout
            } else {
                config.timeoutIntervalForRequest = 90 // 1.5 minutes request timeout
                config.timeoutIntervalForResource = 120 // 2 minutes resource timeout
            }
            let session = URLSession(configuration: config)

            do {
                let (data, response) = try await withTimeoutForAnalysis(seconds: 140) {
                    try await session.data(for: request)
                }

                print("🔧 \(model) - Request succeeded on attempt \(attempt)")
                return (data, response)
            } catch {
                if let urlError = error as? URLError, urlError.code == .timedOut {
                    print("⚠️ \(model) - Request timed out")
                    throw AIFoodAnalysisError.timeout // makes performRequestWithRetry handle it
                }
                throw error
            }
        } catch AIFoodAnalysisError.timeout {
            print("⚠️ \(model) - Timeout")
            throw AIFoodAnalysisError.timeout
        } catch {
            print("❌ \(model) - Non-timeout error: \(error)")
            // For non-timeout errors, fail immediately
            throw error
        }
    }

    // MARK: - GPT-5 Enhanced Request Handling

    /// Performs a GPT-5 request with retry logic and enhanced timeout handling
    private func performRequestWithRetry(
        request: URLRequest,
        model: OpenAIModel,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> (Data, URLResponse) {
        let maxRetries = 2
//        var lastError: Error?

        for attempt in 1 ... maxRetries {
            do {
                return try await performRequest(
                    request: request,
                    model: model,
                    attempt: attempt,
                    maxRetries: maxRetries,
                    telemetryCallback: telemetryCallback
                )

            } catch AIFoodAnalysisError.timeout {
                print("⚠️ \(model) Debug - Timeout on attempt \(attempt)")
//                lastError = AIFoodAnalysisError.timeout

                if attempt < maxRetries {
                    let backoffDelay = Double(attempt) * 2.0 // 2s, 4s backoff
                    telemetryCallback?("⏳ \(model) retry in \(Int(backoffDelay))s...")
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                }
            } catch {
                print("❌ \(model) Debug - Non-timeout error on attempt \(attempt): \(error)")
                // For non-timeout errors, fail immediately
                throw error
            }
        }

        // All retries failed
        print("❌ \(model) Debug - All retry attempts failed")
//        telemetryCallback?("❌ GPT-5 requests timed out, switching to GPT-4o...")

        // Auto-fallback to GPT-4o on persistent timeout
//        DispatchQueue.main.async {
//            UserDefaults.standard.openAIVersion = .gpt4o
//        }

        throw AIFoodAnalysisError
            .customError("\(model) requests timed out consistently.")
    }
}

// MARK: - OpenAI /responses Codable Payloads (Request/Response/Error)

// Request
struct OpenAIResponsesRequest: Encodable {
    let model: OpenAIModel
    let input: [OpenAIResponsesMessage]
    let max_output_tokens: Int
    let temperature: Double
    let text: OpenAIResponsesTextOptions?
    let stream: Bool?
}

struct OpenAIResponsesTextOptions: Encodable {
    struct Format: Encodable { let type: String }
    let format: Format
}

struct OpenAIResponsesMessage: Encodable {
    let role: String
    let content: [OpenAIResponsesContent]
}

enum OpenAIResponsesContent: Encodable {
    case input_text(text: String)
    case input_image(imageURL: String)

    enum CodingKeys: String, CodingKey { case type, text, image_url }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .input_text(text):
            try container.encode("input_text", forKey: .type)
            try container.encode(text, forKey: .text)
        case let .input_image(imageURL):
            try container.encode("input_image", forKey: .type)
            try container.encode(imageURL, forKey: .image_url)
        }
    }
}

// Response
struct OpenAIResponsesResponse: Decodable {
    let output_text: String?
    let output: [OpenAIResponsesMessageOutput]?
    let content: [OpenAIResponsesContentItem]?
}

struct OpenAIResponsesMessageOutput: Decodable {
    let id: String?
    let type: String? // e.g., "message"
    let status: String?
    let role: String?
    let content: [OpenAIResponsesOutputContent]?
}

struct OpenAIResponsesOutputContent: Decodable {
    let type: String? // e.g., "output_text"
    let text: String?
}

struct OpenAIResponsesContentItem: Decodable {
    let type: String?
    let text: String?
    let message: OpenAIResponsesMessagePayload?
}

struct OpenAIResponsesMessagePayload: Decodable {
    let content: String?
}

// Error Response
struct OpenAIErrorResponse: Decodable {
    struct APIError: Decodable {
        let message: String?
        let type: String?
        let param: String?
        let code: String?
    }

    let error: APIError
}
