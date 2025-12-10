import Foundation

enum AIProvider: Hashable {
    case openAI
    case gemini
    case claude

    var requiresAPIKey: Bool {
        switch self {
        case .claude,
             .gemini,
             .openAI:
            return true
        }
    }

    var description: String {
        switch self {
        case .claude:
            return "Anthropic's Claude AI with excellent reasoning. Requires paid API key from console.anthropic.com."
        case .gemini:
            return "Free API key available at ai.google.dev. Best for detailed food analysis."
        case .openAI:
            return "Requires paid OpenAI API key. Most accurate for complex meals."
        }
    }
}

protocol AIModelBase {
    var needAggressiveImageCompression: Bool { get }

    var fast: Bool { get }

    var rawValue: String { get }
}

enum OpenAIModel: String, AIModelBase, Encodable {
    case gpt_4o = "gpt-4o"
    case gpt_4o_mini = "gpt-4o-mini"
    case gpt_5 = "gpt-5"
    case gpt_5_mini = "gpt-5-mini"
    case gpt_5_1 = "gpt-5.1"

    var fast: Bool {
        switch self {
        case .gpt_4o: false
        case .gpt_4o_mini: true
        case .gpt_5: false
        case .gpt_5_mini: true
        case .gpt_5_1: false
        }
    }

    var needAggressiveImageCompression: Bool {
        switch self {
        case .gpt_4o: false
        case .gpt_4o_mini: false
        case .gpt_5: true
        case .gpt_5_mini: true
        case .gpt_5_1: true
        }}

    var isGPT5: Bool {
        switch self {
        case .gpt_4o: false
        case .gpt_4o_mini: false
        case .gpt_5: true
        case .gpt_5_mini: true
        case .gpt_5_1: true
        }
    }
}

enum GeminiModel: String, AIModelBase, Encodable {
    case gemini_2_5_pro = "gemini-2.5-pro"
    case gemini_2_5_flash = "gemini-2.5-flash"
    case gemini_3_pro_preview = "gemini-3-pro-preview"

    var fast: Bool {
        switch self {
        case .gemini_2_5_pro: false
        case .gemini_2_5_flash: true
        case .gemini_3_pro_preview: false
        }
    }

    var needAggressiveImageCompression: Bool {
        switch self {
        case .gemini_2_5_pro: return false
        case .gemini_2_5_flash: return false
        case .gemini_3_pro_preview: return false
        }
    }
}

enum ClaudeModel: String, AIModelBase, Encodable {
    case sonnet_4_5 = "claude-sonnet-4-5"
    case haiku_4_5 = "claude-haiku-4-5"

    var fast: Bool {
        switch self {
        case .sonnet_4_5: false
        case .haiku_4_5: true
        }
    }

    var needAggressiveImageCompression: Bool {
        switch self {
        case .sonnet_4_5: return false
        case .haiku_4_5: return false
        }
    }
}

enum AIModel {
    case openAI(OpenAIModel)
    case gemini(GeminiModel)
    case claude(ClaudeModel)

    var provider: AIProvider {
        switch self {
        case .openAI: return .openAI
        case .gemini: return .gemini
        case .claude: return .claude
        }
    }
}

enum ImageSearchProvider {
    case aiModel(AIModel)

    static let allCases: [ImageSearchProvider] = [
        .aiModel(.openAI(.gpt_4o)),
        .aiModel(.openAI(.gpt_4o_mini)),
        .aiModel(.openAI(.gpt_5)),
        .aiModel(.openAI(.gpt_5_mini)),
        .aiModel(.openAI(.gpt_5_1)),
        .aiModel(.gemini(.gemini_3_pro_preview)),
        .aiModel(.gemini(.gemini_2_5_pro)),
        .aiModel(.gemini(.gemini_2_5_flash)),
        .aiModel(.claude(.sonnet_4_5)),
        .aiModel(.claude(.haiku_4_5))
    ]

    static let defaultProvider: ImageSearchProvider = .aiModel(.gemini(.gemini_2_5_pro))
}

enum TextSearchProvider {
    case aiModel(AIModel)
    case usdaFoodData
    case openFoodFacts

    static let allCases: [TextSearchProvider] = [
        .aiModel(.openAI(.gpt_4o)),
        .aiModel(.openAI(.gpt_4o_mini)),
        .aiModel(.openAI(.gpt_5)),
        .aiModel(.openAI(.gpt_5_mini)),
        .aiModel(.openAI(.gpt_5_1)),
        .aiModel(.gemini(.gemini_3_pro_preview)),
        .aiModel(.gemini(.gemini_2_5_pro)),
        .aiModel(.gemini(.gemini_2_5_flash)),
        .aiModel(.claude(.sonnet_4_5)),
        .aiModel(.claude(.haiku_4_5)),
        .usdaFoodData,
        .openFoodFacts
    ]

    static let defaultProvider: TextSearchProvider = .usdaFoodData
}

enum BarcodeSearchProvider {
//    case aiModel(AIModel)
    case openFoodFacts
//    case usdaFoodData

    static let allCases: [BarcodeSearchProvider] = [
        //        .aiModel(.openAI(.gpt_4o)),
//        .aiModel(.openAI(.gpt_4o_mini)),
//        .aiModel(.openAI(.gpt_5)),
//        .aiModel(.openAI(.gpt_5_mini)),
//        .aiModel(.openAI(.gpt_5_1)),
//        .aiModel(.gemini(.gemini_3_pro_preview)),
//        .aiModel(.gemini(.gemini_2_5_pro)),
//        .aiModel(.gemini(.gemini_2_5_flash)),
//        .aiModel(.claude(.sonnet_4_5)),
//        .aiModel(.claude(.haiku_4_5)),
        .openFoodFacts
    ]

    static let defaultProvider: BarcodeSearchProvider = .openFoodFacts
}

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

// MARK: - String serialization for AIModel and providers

extension AIModel: RawRepresentable, Codable {
    public typealias RawValue = String

    public init?(rawValue: String) {
        // Expect at least a provider segment, with an optional tail that the model enum parses.
        let parts = rawValue.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
        guard let provider = parts.first else { return nil }
        let tail = parts.count > 1 ? parts[1] : ""
        switch provider {
        case "openAI":
            guard let m = OpenAIModel(rawValue: tail) else { return nil }
            self = .openAI(m)
        case "gemini":
            guard let m = GeminiModel(rawValue: tail) else { return nil }
            self = .gemini(m)
        case "claude":
            guard let m = ClaudeModel(rawValue: tail) else { return nil }
            self = .claude(m)
        default:
            return nil
        }
    }

    public var rawValue: String {
        switch self {
        case let .openAI(m):
            return "openAI/\(m.rawValue)"
        case let .gemini(m):
            return "gemini/\(m.rawValue)"
        case let .claude(m):
            return "claude/\(m.rawValue)"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = AIModel(rawValue: string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid AIModel string: \(string)")
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension ImageSearchProvider: RawRepresentable, Codable {
    public typealias RawValue = String

    public init?(rawValue: String) {
        let parts = rawValue.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
        guard let head = parts.first else { return nil }
        let tail = parts.count > 1 ? parts[1] : ""
        switch head {
        case "aiModel":
            guard let model = AIModel(rawValue: tail) else { return nil }
            self = .aiModel(model)
        default:
            return nil
        }
    }

    public var rawValue: String {
        switch self {
        case let .aiModel(model):
            return "aiModel/\(model.rawValue)"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = ImageSearchProvider(rawValue: string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ImageSearchProvider string: \(string)"
            )
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension TextSearchProvider: RawRepresentable, Codable {
    public typealias RawValue = String

    public init?(rawValue: String) {
        if rawValue == "usdaFoodData" {
            self = .usdaFoodData
            return
        }
        if rawValue == "openFoodFacts" {
            self = .openFoodFacts
            return
        }
        let parts = rawValue.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
        guard let head = parts.first else { return nil }
        let tail = parts.count > 1 ? parts[1] : ""
        switch head {
        case "aiModel":
            guard let model = AIModel(rawValue: tail) else { return nil }
            self = .aiModel(model)
        default:
            return nil
        }
    }

    public var rawValue: String {
        switch self {
        case .usdaFoodData:
            return "usdaFoodData"
        case .openFoodFacts:
            return "openFoodFacts"
        case let .aiModel(model):
            return "aiModel/\(model.rawValue)"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = TextSearchProvider(rawValue: string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid TextSearchProvider string: \(string)"
            )
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension BarcodeSearchProvider: RawRepresentable, Codable {
    public typealias RawValue = String

    public init?(rawValue: String) {
        // Either "openFoodFacts", "usdaFoodData" or "aiModel/<...>"
        if rawValue == "openFoodFacts" {
            self = .openFoodFacts
            return
        }
//        if rawValue == "usdaFoodData" {
//            self = .usdaFoodData
//            return
//        }
//        let parts = rawValue.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
//        guard let head = parts.first else { return nil }
//        let tail = parts.count > 1 ? parts[1] : ""
//        switch head {
//        case "aiModel":
//            guard let model = AIModel(rawValue: tail) else { return nil }
//            self = .aiModel(model)
//        default:
//            return nil
//        }
        return nil
    }

    public var rawValue: String {
        switch self {
        case .openFoodFacts:
            return "openFoodFacts"
//        case .usdaFoodData:
//            return "usdaFoodData"
//        case let .aiModel(model):
//            return "aiModel/\(model.rawValue)"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = BarcodeSearchProvider(rawValue: string) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid BarcodeSearchProvider string: \(string)"
            )
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - Hashable & Identifiable for provider enums

extension ImageSearchProvider: Hashable, Identifiable {
    public var id: String { rawValue }

    public static func == (lhs: ImageSearchProvider, rhs: ImageSearchProvider) -> Bool {
        lhs.rawValue == rhs.rawValue
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}

extension TextSearchProvider: Hashable, Identifiable {
    public var id: String { rawValue }

    public static func == (lhs: TextSearchProvider, rhs: TextSearchProvider) -> Bool {
        lhs.rawValue == rhs.rawValue
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}

extension BarcodeSearchProvider: Hashable, Identifiable {
    public var id: String { rawValue }

    public static func == (lhs: BarcodeSearchProvider, rhs: BarcodeSearchProvider) -> Bool {
        lhs.rawValue == rhs.rawValue
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}
