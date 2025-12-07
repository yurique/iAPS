import CoreML
import CryptoKit
import Foundation
import LoopKit
import Network
import os.log
import SwiftUI
import UIKit
import Vision

// MARK: - OpenAI Service (Alternative)

class OpenAIFoodAnalysisService: FoodAnalysisService {
    static let shared = OpenAIFoodAnalysisService()
    private init() {}

    private let apiURL = URL(string: "https://api.openai.com/v1/responses")!

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

    private func analyzeFoodRequest(
        _ request: AnalysisRequest,
        apiKey: String,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> AIFoodAnalysisResult {
        // Get optimal model based on current analysis mode
        telemetryCallback?("⚙️ Configuring OpenAI parameters...")
        let analysisMode = ConfigurableAIService.shared.analysisMode
        let model = ConfigurableAIService.optimalModel(for: .openAI, mode: analysisMode)
        let openaAIVersion = UserDefaults.standard.openAIVersion

        print("🤖 OpenAI Model Selection:")
        print("   Analysis Mode: \(analysisMode.rawValue)")
        print("   OpenAI Version: \(openaAIVersion)")
        print("   Selected Model: \(model)")

        // Optimize image size for faster processing and uploads
        telemetryCallback?("🖼️ Optimizing your image...")

        let urlRequest: URLRequest
        do {
            urlRequest = try prepareRequest(request, model: model, apiKey: apiKey, telemetryCallback: telemetryCallback)
        } catch {
            throw AIFoodAnalysisError.requestCreationFailed
        }

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
                        if model.contains("gpt-5") || model.contains("gpt-5.1") {
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
                            if model.contains("gpt-5") || model.contains("gpt-5.1") {
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

            return try parseOpenAIResponse(content: content)
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

    private func getImageBase64(
        for request: AnalysisRequest,
        model: String,
        telemetryCallback: ((String) -> Void)?
    ) throws -> String? {
        switch request {
        case .query: return nil
        case let .image(image):
            let optimizedImage = ConfigurableAIService.optimizeImageForAnalysis(image)
            // Convert image to base64 with adaptive compression
            // GPT-5 benefits from more aggressive compression due to slower processing
            telemetryCallback?("🔄 Encoding image data...")
            let compressionQuality = model.contains("gpt-5") ?
                min(0.7, ConfigurableAIService.adaptiveCompressionQuality(for: optimizedImage)) :
                ConfigurableAIService.adaptiveCompressionQuality(for: optimizedImage)
            guard let imageData = optimizedImage.jpegData(compressionQuality: compressionQuality) else {
                throw AIFoodAnalysisError.imageProcessingFailed
            }
            return imageData.base64EncodedString()
        }
    }

    private func prepareRequest(
        _ analyticsRequest: AnalysisRequest,
        model: String,
        apiKey: String,
        telemetryCallback: ((String) -> Void)?
    ) throws -> URLRequest {
        let base64Image = try getImageBase64(for: analyticsRequest, model: model, telemetryCallback: telemetryCallback)

        // Get analysis prompt early to check complexity
        telemetryCallback?("📡 Preparing API request...")
        let analysisPrompt = getAnalysisPrompt(analyticsRequest)
        let isAdvancedPrompt = false // analysisPrompt.count > 10000 // TODO: should we look at the length of the query?

        // Create OpenAI API request
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Set appropriate timeout based on model type and prompt complexity
        if model.contains("gpt-5") {
            request.timeoutInterval = 120 // 2 minutes for GPT-5 models
            print("🔧 \(model) Debug - Set URLRequest timeout to 120 seconds")
        } else {
            // For GPT-4 models, extend timeout significantly for advanced analysis (very long prompt)
            request.timeoutInterval = 120 // 2 minutes for GPT-4 models
            print(
                "🔧 \(model) Timeout - Model: \(model), Advanced: \(isAdvancedPrompt), Timeout: \(request.timeoutInterval)s, Prompt: \(analysisPrompt.count) chars"
            )
//            if isAdvancedPrompt {
//                print("🔧 \(model) Advanced - Using extended 150s timeout for comprehensive analysis (\(analysisPrompt.count) chars)")
//            }
        }

        // Use appropriate parameters based on model type
        print("🔍 OpenAI Final Prompt Debug:")
        print("   Analysis prompt length: \(analysisPrompt.count) characters")
        print("   First 100 chars of analysis prompt: \(String(analysisPrompt.prefix(100)))")

        var contentParts: [OpenAIResponsesContent] = [
            .input_text(text: analysisPrompt)
        ]

        if let base64Image, !base64Image.isEmpty {
            contentParts.append(.input_image(imageURL: "data:image/jpeg;base64,\(base64Image)"))
        }

        let inputMessages: [OpenAIResponsesMessage] = [
            OpenAIResponsesMessage(role: "user", content: contentParts)
        ]

        var textOptions: OpenAIResponsesTextOptions?
        var stream: Bool?
        if model.contains("gpt-5") {
            textOptions = OpenAIResponsesTextOptions(format: .init(type: "json_object"))
            stream = false // Ensure complete response (no streaming)
            telemetryCallback?("⚡ Using GPT-5 optimized settings...")
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

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        return request
    }

    private func performRequest(
        request: URLRequest,
        model: String,
        attempt: Int,
        maxRetries: Int,
        telemetryCallback: ((String) -> Void)?
    ) async throws -> (Data, URLResponse) {
        do {
            print("🔧 \(model) Debug - Attempt \(attempt)/\(maxRetries)")
            telemetryCallback?("🔄 \(model) attempt \(attempt)/\(maxRetries)...")

            let config = URLSessionConfiguration.default
            if model.contains("gpt-5") {
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
        model: String,
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

    /// Parse OpenAI response content into AIFoodAnalysisResult
    private func parseOpenAIResponse(content: String) throws -> AIFoodAnalysisResult {
        // 1. Remove markdown fences and stray backticks
        var cleanedContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 2. Remove UTF-8 BOM or invisible junk before first "{"
        if let braceIndex = cleanedContent.firstIndex(of: "{") {
            let prefix = cleanedContent[..<braceIndex]
            if prefix.contains(where: { !$0.isASCII }) {
                cleanedContent = String(cleanedContent[braceIndex...])
            }
        }

        // 3. Extract JSON substring between first "{" and last "}"
        let jsonString: String
        if let jsonStartRange = cleanedContent.range(of: "{"),
           let jsonEndRange = cleanedContent.range(of: "}", options: .backwards),
           jsonStartRange.lowerBound < jsonEndRange.upperBound
        {
            jsonString = String(cleanedContent[jsonStartRange.lowerBound ..< jsonEndRange.upperBound])
        } else {
            jsonString = cleanedContent
        }

        // 4. Fix common issue: remove trailing commas before }
        let fixedJson = jsonString.replacingOccurrences(
            of: ",\\s*}".replacingOccurrences(of: "\\", with: "\\\\"),
            with: "}"
        )

        // 5. Decode
        guard let jsonData = fixedJson.data(using: .utf8) else {
            print("❌ Failed to convert to Data. JSON was:\n\(fixedJson)")
            throw AIFoodAnalysisError.responseParsingFailed
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(AIFoodAnalysisResult.self, from: jsonData)

        } catch {
            print("❌ JSON decode error: \(error)")
            print("❌ JSON content:\n\(fixedJson)")
            throw AIFoodAnalysisError.responseParsingFailed
        }
    }
}

// MARK: - OpenAI /responses Codable Payloads (Request/Response/Error)

// Request
struct OpenAIResponsesRequest: Encodable {
    let model: String
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
