import Foundation
import SwiftUI

/// Simple secure field that uses proper SwiftUI components
struct StableSecureField: View {
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool

    var body: some View {
        if isSecure {
            SecureField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } else {
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }
}

/// Settings view for configuring AI food analysis
struct AISettingsView: View {
    @ObservedObject private var aiService = ConfigurableAIService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var claudeKey: String = ""
    @State private var openAIKey: String = ""
    @State private var googleGeminiKey: String = ""

    @State private var showingAPIKeyAlert = false

    // API Key visibility toggles - start with keys hidden (secure)
    @State private var showClaudeKey: Bool = false
    @State private var showOpenAIKey: Bool = false
    @State private var showGoogleGeminiKey: Bool = false

    @AppStorage(UserDefaults.AIKey.aiImageProvider.rawValue) private var imageSearchProvider: ImageSearchProvider =
        .defaultProvider

    @AppStorage(UserDefaults.AIKey.textSearchProvider.rawValue) private var textSearchProvider: TextSearchProvider =
        .defaultProvider

    @AppStorage(UserDefaults.AIKey.barcodeSearchProvider.rawValue) private var barcodeSearchProvider: BarcodeSearchProvider =
        .defaultProvider

    @State private var preferredLanguage: String = ""
    @State private var preferredRegion: String = ""

    @State private var languageOptionsState: [(code: String, name: String)] = []
    @State private var regionOptionsState: [(code: String, name: String)] = []

    private func systemLanguageCode() -> String {
        if let first = Locale.preferredLanguages.first {
            let loc = Locale(identifier: first)
            if let lang = loc.language.languageCode?.identifier {
                return lang
            }
        }
        if let lang = Locale.current.language.languageCode?.identifier {
            return lang
        }
        return "en"
    }

    private func systemRegionCode() -> String {
        if let region = Locale.current.region?.identifier {
            return region
        } else if let regionCode = (Locale.current as NSLocale).object(forKey: .countryCode) as? String {
            return regionCode
        }
        return "US"
    }

    private func buildLanguageOptions() {
        let codes = Set(Locale.LanguageCode.isoLanguageCodes.map(\.identifier))
        let locale = Locale.current
        let items: [(String, String)] = codes.compactMap { code -> (String, String)? in
            let id = Locale.identifier(fromComponents: [NSLocale.Key.languageCode.rawValue: code])
            let display = locale.localizedString(forLanguageCode: code) ?? Locale(identifier: id)
                .localizedString(forLanguageCode: code) ?? code
            return (code, display)
        }
        .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
        languageOptionsState = items
    }

    private func buildRegionOptions() {
        let codes = Set(Locale.Region.isoRegions.map(\.identifier))
        let locale = Locale.current
        let items: [(String, String)] = codes.compactMap { code -> (String, String)? in
            let display = locale.localizedString(forRegionCode: code) ?? code
            return (code, display)
        }
        .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
        regionOptionsState = items
    }

    private func displayName(for code: String, in options: [(code: String, name: String)]) -> String {
        options.first(where: { $0.code == code })?.name ?? code
    }

    init() {}

    func readPersistedValues() {
        claudeKey = ConfigurableAIService.shared.getAPIKey(for: .claude) ?? ""
        openAIKey = ConfigurableAIService.shared.getAPIKey(for: .openAI) ?? ""
        googleGeminiKey = ConfigurableAIService.shared.getAPIKey(for: .gemini) ?? ""

        preferredLanguage = UserDefaults.standard.userPreferredLanguageForAI ?? ""
        preferredRegion = UserDefaults.standard.userPreferredRegionForAI ?? ""
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text("Food Search Provider Configuration"),

                    footer: Text(
                        "Configure the API service used for each type of food search. AI Image Analysis controls what happens when you take photos of food. Different providers excel at different search methods."
                    )
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Provider for AI Image Analysis")
                            .font(.title3)

                        Picker("", selection: $imageSearchProvider) {
                            ForEach(ImageSearchProvider.allCases, id: \.self) { provider in
                                HStack(spacing: 12) {
//                                    Image(systemName: icon(for: provider))
//                                        .foregroundColor(.accentColor)

                                    Text(provider.providerName)
                                        .font(.caption)
                                    if let modelName = provider.modelName {
                                        Text(modelName)
                                            .font(.subheadline)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.15))
                                            .cornerRadius(4)
                                    }

                                    Spacer()

                                    if let fast = provider.fast, fast {
                                        Text("Fast")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                }
                                .tag(provider)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Provider for Text/Voice Search")
                            .font(.title3)

                        Picker("", selection: $textSearchProvider) {
                            ForEach(TextSearchProvider.allCases, id: \.self) { provider in
                                HStack(spacing: 12) {
//                                    Image(systemName: icon(for: provider))
//                                        .foregroundColor(.accentColor)

                                    Text(provider.providerName)
                                        .font(.caption)
                                    if let modelName = provider.modelName {
                                        Text(modelName)
                                            .font(.subheadline)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.15))
                                            .cornerRadius(4)
                                    }

                                    Spacer()

                                    if let fast = provider.fast, fast {
                                        Text("Fast")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                }
                                .tag(provider)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Provider for Barcode Scanning")
                            .font(.title3)

                        Picker("", selection: $barcodeSearchProvider) {
                            ForEach(BarcodeSearchProvider.allCases, id: \.self) { provider in
                                HStack(spacing: 12) {
//                                    Image(systemName: icon(for: provider))
//                                        .foregroundColor(.accentColor)

                                    Text(provider.providerName)
                                        .font(.caption)
                                    if let modelName = provider.modelName {
                                        Text(modelName)
                                            .font(.subheadline)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.15))
                                            .cornerRadius(4)
                                    }

                                    Spacer()

                                    if let fast = provider.fast, fast {
                                        Text("Fast")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                }
                                .tag(provider)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                    .padding(.vertical, 4)
                }

                // Claude API Configuration
                Section(
                    header: Text("Anthropic (Claude API) Configuration"),

                    footer: Text(
                        "Get a Claude API key from console.anthropic.com. Claude excels at detailed reasoning and food analysis. Pricing starts at $0.25 per million tokens for Haiku model."
                    )
                ) {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Claude API Key")
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    showClaudeKey.toggle()
                                }) {
                                    Image(systemName: showClaudeKey ? "eye.slash" : "eye")
                                        .foregroundColor(.blue)
                                }
                            }

                            HStack {
                                StableSecureField(
                                    placeholder: "Enter your Claude API key",
                                    text: $claudeKey,
                                    isSecure: !showClaudeKey
                                )
                            }
                        }
                    }
                }

                // Google Gemini API Configuration
                Section(
                    header: Text("Google (Gemini API) Configuration"),

                    footer: Text(
                        "Get a free API key from ai.google.dev. Google Gemini provides excellent food recognition with generous free tier (1500 requests per day)."
                    )
                ) {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Google Gemini API Key")
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    showGoogleGeminiKey.toggle()
                                }) {
                                    Image(systemName: showGoogleGeminiKey ? "eye.slash" : "eye")
                                        .foregroundColor(.blue)
                                }
                            }

                            HStack {
                                StableSecureField(
                                    placeholder: "Enter your Google Gemini API key",
                                    text: $googleGeminiKey,
                                    isSecure: !showGoogleGeminiKey
                                )
                            }
                        }
                    }
                }

                // OpenAI (ChatGPT) API Configuration
                Section(
                    header: Text("OpenAI (ChatGPT API) Configuration"),

                    footer: Text(
                        "Get an API key from platform.openai.com. Customize the analysis prompt to get specific meal component breakdowns and nutrition totals. (~$0.01 per image)"
                    )
                ) {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("ChatGPT (OpenAI) API Key")
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    showOpenAIKey.toggle()
                                }) {
                                    Image(systemName: showOpenAIKey ? "eye.slash" : "eye")
                                        .foregroundColor(.blue)
                                }
                            }

                            HStack {
                                StableSecureField(
                                    placeholder: "Enter your OpenAI API key",
                                    text: $openAIKey,
                                    isSecure: !showOpenAIKey
                                )
                            }
                        }
                    }
                }

                Section(
                    header: Text("Localization"),
                    footer: Text(
                        "Choose a specific language and region for AI output."
                    )
                ) {
                    NavigationLink {
                        OptionSelectionView(
                            title: "Preferred Language",
                            options: languageOptionsState,
                            selection: $preferredLanguage
                        )
                    } label: {
                        HStack {
                            Text("Preferred Language")
                            Spacer()
                            Text(
                                preferredLanguage.isEmpty
                                    ? displayName(for: systemLanguageCode(), in: languageOptionsState)
                                    : displayName(for: preferredLanguage, in: languageOptionsState)
                            )
                            .foregroundColor(.secondary)
                        }
                    }

                    NavigationLink {
                        OptionSelectionView(
                            title: "Preferred Region",
                            options: regionOptionsState,
                            selection: $preferredRegion
                        )
                    } label: {
                        HStack {
                            Text("Preferred Region")
                            Spacer()
                            Text(
                                preferredRegion.isEmpty
                                    ? displayName(for: systemRegionCode(), in: regionOptionsState)
                                    : displayName(for: preferredRegion, in: regionOptionsState)
                            )
                            .foregroundColor(.secondary)
                        }
                    }
                }

                Section(
                    header: Text("Important: How to Use Your API Keys"),

                    footer: Text(
                        "To use your paid API keys, make sure to select the corresponding provider in 'AI Image Analysis' above. The provider you select for AI Image Analysis is what will be used when you take photos of food."
                    )
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.blue)
                            Text("Camera Food Analysis")
                                .font(.headline)
                        }

                        Text(
                            "When you take a photo of food, the app uses the provider selected in 'AI Image Analysis' above."
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)

                        Text(
                            "✅ Select 'Anthropic (Claude API)', 'Google (Gemini API)', or 'OpenAI (ChatGPT API)' for AI Image Analysis to use your paid keys"
                        )
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }

                Section(header: Text("Provider Information")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available Search Providers:")
                            .font(.headline)

                        Text(
                            "• **Anthropic (Claude API)**: Advanced AI with detailed reasoning. Excellent at food analysis and portion estimation. Requires API key (~$0.25 per million tokens)."
                        )

                        Text(
                            "• **Google (Gemini API)**: Free AI with generous limits (1500/day). Excellent food recognition using Google's Vision AI. Perfect balance of quality and cost."
                        )

                        Text(
                            "• **OpenAI (ChatGPT API)**: Most accurate AI analysis using GPT-4 Vision. Requires API key (~$0.01 per image). Excellent at image analysis and natural language queries."
                        )

                        Text(
                            "• **OpenFoodFacts**: Free, open database with extensive barcode coverage and text search for packaged foods. Default for text and barcode searches."
                        )

                        Text(
                            "• **USDA FoodData Central**: Free, official nutrition database. Superior nutrition data for non-packaged foods like fruits, vegetables, and meat."
                        )
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Section(header: Text("Search Type Recommendations")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Group {
                            Text("**Text/Voice Search:**")
                                .font(.caption)
                                .fontWeight(.bold)
                            Text("USDA FoodData Central → OpenFoodFacts")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("**Barcode Scanning:**")
                                .font(.caption)
                                .fontWeight(.bold)
                            Text("OpenFoodFacts")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("**AI Image Analysis:**")
                                .font(.caption)
                                .fontWeight(.bold)
                            Text("Google (Gemini API) → OpenAI (ChatGPT API) → Anthropic (Claude API)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("Medical Disclaimer")) {
                    Text(
                        "AI nutritional estimates are approximations only. Always consult with your healthcare provider for medical decisions. Verify nutritional information whenever possible. Use at your own risk."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveSettings()
                    } label: {
                        HStack {
                            Text("Save")
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        HStack {
                            Text("Cancel")
                        }
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("Food Search Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            readPersistedValues()
            buildLanguageOptions()
            buildRegionOptions()
        }
        .alert("API Key Required", isPresented: $showingAPIKeyAlert) {
            Button("OK") {}
        } message: {
            Text("This AI provider requires an API key. Please enter your API key in the settings below.")
        }
    }

    @ViewBuilder private func modelRow(provider: String, model: String) -> some View {
        HStack {
            Text(provider)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(model)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }

    private func saveSettings() {
        // API key and query settings
        aiService.setAPIKey(claudeKey, for: .claude)
        aiService.setAPIKey(openAIKey, for: .openAI)
        aiService.setAPIKey(googleGeminiKey, for: .gemini)

        // Persist localization overrides
        UserDefaults.standard.userPreferredLanguageForAI = preferredLanguage.isEmpty ? nil : preferredLanguage
        UserDefaults.standard.userPreferredRegionForAI = preferredRegion.isEmpty ? nil : preferredRegion

        // Feature flags werden automatisch durch @AppStorage gespeichert!

        // Dismiss the settings view
        dismiss()
    }
}

private struct OptionSelectionView: View {
    let title: String
    let options: [(code: String, name: String)]
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    private var filteredOptions: [(code: String, name: String)] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return options }
        return options.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.code.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        List {
            ForEach(filteredOptions, id: \.code) { item in
                Button {
                    selection = item.code
                    dismiss()
                } label: {
                    HStack {
                        Text(item.name)
                            .foregroundColor(.primary)
                        Spacer()
                        if selection == item.code {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
    }
}

// MARK: - Preview

#if DEBUG
    struct AISettingsView_Previews: PreviewProvider {
        static var previews: some View {
            AISettingsView()
        }
    }
#endif
