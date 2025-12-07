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

    @AppStorage(UserDefaults.AIKey.openAIVersion.rawValue) private var openAIVersion: UserDefaults.OpenAIVersion = .gpt4o

    @State private var preferredLanguage: String = ""
    @State private var preferredRegion: String = ""
    @State private var overrideLocalization: Bool = false

    @State private var languageOptionsState: [(code: String, name: String)] = []
    @State private var regionOptionsState: [(code: String, name: String)] = []

    private func initializeLanguageIfNeeded() {
        if preferredLanguage.isEmpty {
            // Use first preferred language's code if available
            if let first = Locale.preferredLanguages.first {
                let loc = Locale(identifier: first)
                if let lang = loc.language.languageCode?.identifier {
                    preferredLanguage = lang
                }
            } else if let lang = Locale.current.language.languageCode?.identifier {
                preferredLanguage = lang
            }
        }
    }

    private func initializeRegionIfNeeded() {
        if preferredRegion.isEmpty {
            if let region = Locale.current.region?.identifier {
                preferredRegion = region
            } else if let regionCode = (Locale.current as NSLocale).object(forKey: .countryCode) as? String {
                preferredRegion = regionCode
            }
        }
    }

    private func buildLanguageOptions() {
        let codes = Set(Locale.LanguageCode.isoLanguageCodes.map(\.identifier))
        let locale = Locale.current
        var items: [(String, String)] = [("", "Default")]
        let mapped = codes.compactMap { code -> (String, String)? in
            let id = Locale.identifier(fromComponents: [NSLocale.Key.languageCode.rawValue: code])
            let display = locale.localizedString(forLanguageCode: code) ?? Locale(identifier: id)
                .localizedString(forLanguageCode: code) ?? code
            return (code, display)
        }
        .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
        items.append(contentsOf: mapped)
        languageOptionsState = items
    }

    private func buildRegionOptions() {
        let codes = Set(Locale.Region.isoRegions.map(\.identifier))
        let locale = Locale.current
        var items: [(String, String)] = [("", "Default")]
        let mapped = codes.compactMap { code -> (String, String)? in
            let display = locale.localizedString(forRegionCode: code) ?? code
            return (code, display)
        }
        .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
        items.append(contentsOf: mapped)
        regionOptionsState = items
    }

    private func displayName(for code: String, in options: [(code: String, name: String)]) -> String {
        options.first(where: { $0.code == code })?.name ?? "Default"
    }

    init() {}

    func readPersistedValues() {
        claudeKey = ConfigurableAIService.shared.getAPIKey(for: .claude) ?? ""
        openAIKey = ConfigurableAIService.shared.getAPIKey(for: .openAI) ?? ""
        googleGeminiKey = ConfigurableAIService.shared.getAPIKey(for: .googleGemini) ?? ""

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
                    ForEach(SearchType.allCases, id: \.self) { searchType in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(searchType.rawValue)
                                    .font(.headline)
                                Spacer()
                            }

                            Text(searchType.description)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Picker("Provider for \(searchType.rawValue)", selection: getBindingForSearchType(searchType)) {
                                ForEach(aiService.getAvailableProvidersForSearchType(searchType), id: \.self) { provider in
                                    Text(provider.rawValue).tag(provider)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Analysis Mode Configuration
                Section(
                    header: Text("AI Analysis Mode"),

                    footer: Text(
                        "Choose between speed and accuracy. Fast mode uses lighter AI models for 2-3x faster analysis with slightly reduced accuracy (~5-10% trade-off). Standard mode uses full AI models for maximum accuracy."
                    )
                ) {
                    analysisModeSection
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

//                        VStack(alignment: .leading, spacing: 4) {
//                            NavigationLink(destination: ModelQueryEditor(
//                                title: "Claude Prompt",
//                                loadText: { ConfigurableAIService.shared.getQuery(for: .claude) ?? "" },
//                                saveText: { updated in aiService.setQuery(updated, for: .claude) },
//                                examples: [
//                                    NSLocalizedString("Default Query", comment: "One of Claude Example queries"):
//                                        "Analyze this food image for diabetes management. Describe exactly what you see in detail: colors, textures, cooking methods, plate type, utensils, and food arrangement. Identify each food item with specific preparation details, estimate precise portion sizes using visual references, and provide carbohydrates, protein, fat, and calories for each component. Focus on accurate carbohydrate estimation for insulin dosing.",
//                                    NSLocalizedString("Detailed Visual Analysis", comment: "One of Claude Example queries"):
//                                        "Provide extremely detailed visual analysis of this food image. Describe every element you can see: food colors, textures, cooking methods (grilled marks, browning, steaming), plate type and size, utensils present, garnishes, sauces, cooking oils visible, food arrangement, and background elements. Use these visual details to estimate precise portion sizes and calculate accurate nutrition values for diabetes management.",
//                                    NSLocalizedString(
//                                        "Diabetes Focus",
//                                        comment: "One of Claude Example queries"
//                                    ):
//                                        "Focus specifically on carbohydrate analysis for Type 1 diabetes management. Identify all carb sources, estimate absorption timing, and provide detailed carb counts with confidence levels.",
//                                    NSLocalizedString(
//                                        "Macro Tracking",
//                                        comment: "One of Claude Example queries"
//                                    ):
//                                        "Provide complete macronutrient analysis with detailed portion reasoning. For each food component, describe the visual cues you're using for portion estimation: compare to visible objects (fork, plate, hand), note cooking methods affecting nutrition (oils, preparation style), explain food quality indicators (ripeness, doneness), and provide comprehensive nutrition breakdown with your confidence level for each estimate."
//                                ]
//                            )) {
//                                Text("Edit Prompt")
//                                    .foregroundColor(.blue)
//                                    .padding(.vertical, 8)
//                                    .cornerRadius(8)
//                                    .frame(maxWidth: .infinity, alignment: .leading)
//                            }
//                            .buttonStyle(.plain)
//                            .padding(.top, 4)
//                        }
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

//                        VStack(alignment: .leading, spacing: 4) {
//                            NavigationLink(destination: ModelQueryEditor(
//                                title: "Google Gemini Prompt",
//                                loadText: { ConfigurableAIService.shared.getQuery(for: .googleGemini) ?? "" },
//                                saveText: { updated in aiService.setQuery(updated, for: .googleGemini) },
//                                examples: [
//                                    NSLocalizedString("Default Query", comment: "One of Google Gemini example queries"):
//                                        "Analyze this food image for diabetes management. Describe exactly what you see in detail: colors, textures, cooking methods, plate type, utensils, and food arrangement. Identify each food item with specific preparation details, estimate precise portion sizes using visual references, and provide carbohydrates, protein, fat, and calories for each component. Focus on accurate carbohydrate estimation for insulin dosing.",
//                                    NSLocalizedString(
//                                        "Detailed Visual Analysis",
//                                        comment: "One of Google Gemini example queries"
//                                    ):
//                                        "Provide extremely detailed visual analysis of this food image. Describe every element you can see: food colors, textures, cooking methods (grilled marks, browning, steaming), plate type and size, utensils present, garnishes, sauces, cooking oils visible, food arrangement, and background elements. Use these visual details to estimate precise portion sizes and calculate accurate nutrition values for diabetes management.",
//                                    NSLocalizedString("Diabetes Focus", comment: "One of Google Gemini example queries"):
//                                        "Identify all food items in this image with focus on carbohydrate content for diabetes management. Provide detailed carb counts for each component and total meal carbohydrates.",
//                                    NSLocalizedString("Macro Tracking", comment: "One of Google Gemini example queries"):
//                                        "Break down this meal into individual components with complete macronutrient profiles (carbs, protein, fat, calories) per item and combined totals."
//                                ]
//                            )) {
//                                Text("Edit Prompt")
//                                    .foregroundColor(.blue)
//                                    .padding(.vertical, 8)
//                                    .cornerRadius(8)
//                                    .frame(maxWidth: .infinity, alignment: .leading)
//                            }
//                            .buttonStyle(.plain)
//                            .padding(.top, 4)
//                        }
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

                            Section(
                                header: Text("OpenAI Model Version"),
                                footer: Text(
                                    "Choose which OpenAI model family to prefer. This affects which OpenAI models are selected in analysis and may change cost, speed, and accuracy."
                                )
                            ) {
                                Picker("OpenAI Version", selection: $openAIVersion) {
                                    ForEach(
                                        [
                                            UserDefaults.OpenAIVersion.gpt4o,
                                            UserDefaults.OpenAIVersion.gpt5_0,
                                            UserDefaults.OpenAIVersion.gpt5_1
                                        ],
                                        id: \.self
                                    ) { version in
                                        Text(version.rawValue).tag(version)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                        }

//                        VStack(alignment: .leading, spacing: 4) {
//                            NavigationLink(destination: ModelQueryEditor(
//                                title: "OpenAI Prompt",
//                                loadText: { ConfigurableAIService.shared.getQuery(for: .openAI) ?? "" },
//                                saveText: { updated in aiService.setQuery(updated, for: .openAI) },
//                                examples: [
//                                    NSLocalizedString("Default Query", comment: "One of Example Prompts for OpenAI"):
//                                        "Analyze this food image for diabetes management. Describe exactly what you see in detail: colors, textures, cooking methods, plate type, utensils, and food arrangement. Identify each food item with specific preparation details, estimate precise portion sizes using visual references, and provide carbohydrates, protein, fat, and calories for each component. Focus on accurate carbohydrate estimation for insulin dosing.",
//                                    NSLocalizedString("Detailed Visual Analysis", comment: "One of Example Prompts for OpenAI"):
//                                        "Provide extremely detailed visual analysis of this food image. Describe every element you can see: food colors, textures, cooking methods (grilled marks, browning, steaming), plate type and size, utensils present, garnishes, sauces, cooking oils visible, food arrangement, and background elements. Use these visual details to estimate precise portion sizes and calculate accurate nutrition values for diabetes management.",
//                                    NSLocalizedString("Diabetes Focus", comment: "One of Example Prompts for OpenAI"):
//                                        "Identify all food items in this image with focus on carbohydrate content for diabetes management. Provide detailed carb counts for each component and total meal carbohydrates.",
//                                    NSLocalizedString("Macro Tracking", comment: "One of Example Prompts for OpenAI"):
//                                        "Break down this meal into individual components with complete macronutrient profiles (carbs, protein, fat, calories) per item and combined totals."
//                                ]
//                            )) {
//                                Text("Edit Prompt")
//                                    .foregroundColor(.blue)
//                                    .padding(.vertical, 8)
//                                    .cornerRadius(8)
//                                    .frame(maxWidth: .infinity, alignment: .leading)
//                            }
//                            .buttonStyle(.plain)
//                            .padding(.top, 4)
//                        }
                    }
                }

                Section(
                    header: Text("Localization Overrides"),
                    footer: Text(
                        "Choose a specific language and/or region for AI output. Select 'System Default' to avoid overriding your device settings."
                    )
                ) {
                    Toggle("Override Localization", isOn: $overrideLocalization)
                        .onChange(of: overrideLocalization) { _, newValue in
                            if newValue {
                                initializeLanguageIfNeeded()
                                initializeRegionIfNeeded()
                            } else {
                                preferredLanguage = ""
                                preferredRegion = ""
                            }
                        }

                    if overrideLocalization {
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
                                Text(displayName(for: preferredLanguage, in: languageOptionsState))
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
                                Text(displayName(for: preferredRegion, in: regionOptionsState))
                                    .foregroundColor(.secondary)
                            }
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

                        Text(
                            "❌ If you select 'OpenFoodFacts' or 'USDA', camera analysis will use basic estimation instead of AI"
                        )
                        .font(.caption)
                        .foregroundColor(.orange)
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
            overrideLocalization = (!preferredLanguage.isEmpty || !preferredRegion.isEmpty)
            buildLanguageOptions()
            buildRegionOptions()
        }
        .alert("API Key Required", isPresented: $showingAPIKeyAlert) {
            Button("OK") {}
        } message: {
            Text("This AI provider requires an API key. Please enter your API key in the settings below.")
        }
    }

    @ViewBuilder private var analysisModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Mode picker
            Picker("Analysis Mode", selection: Binding(
                get: { aiService.analysisMode },
                set: { newMode in aiService.setAnalysisMode(newMode) }
            )) {
                ForEach(ConfigurableAIService.AnalysisMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            currentModeDetails
            modelInformation
        }
    }

    @ViewBuilder private var currentModeDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: aiService.analysisMode.iconName)
                    .foregroundColor(aiService.analysisMode.iconColor)
                Text("Current Mode: \(aiService.analysisMode.displayName)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Text(aiService.analysisMode.detailedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(aiService.analysisMode.backgroundColor)
        .cornerRadius(8)
    }

    @ViewBuilder private var modelInformation: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Models Used:")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                modelRow(
                    provider: "Google Gemini:",
                    model: ConfigurableAIService.optimalModel(for: .googleGemini, mode: aiService.analysisMode)
                )
                modelRow(
                    provider: "OpenAI:",
                    model: ConfigurableAIService.optimalModel(for: .openAI, mode: aiService.analysisMode)
                )
                modelRow(
                    provider: "Claude:",
                    model: ConfigurableAIService.optimalModel(for: .claude, mode: aiService.analysisMode)
                )
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6))
        .cornerRadius(6)
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
        aiService.setAPIKey(googleGeminiKey, for: .googleGemini)

        // Persist localization overrides
        UserDefaults.standard.userPreferredLanguageForAI = preferredLanguage.isEmpty ? nil : preferredLanguage
        UserDefaults.standard.userPreferredRegionForAI = preferredRegion.isEmpty ? nil : preferredRegion

        // Feature flags werden automatisch durch @AppStorage gespeichert!

        // Dismiss the settings view
        dismiss()
    }

    private func getBindingForSearchType(_ searchType: SearchType) -> Binding<SearchProvider> {
        switch searchType {
        case .textSearch:
            return Binding(
                get: { aiService.textSearchProvider },
                set: { newValue in
                    aiService.textSearchProvider = newValue
                    UserDefaults.standard.textSearchProvider = newValue
                }
            )
        case .barcodeSearch:
            return Binding(
                get: { aiService.barcodeSearchProvider },
                set: { newValue in
                    aiService.barcodeSearchProvider = newValue
                    UserDefaults.standard.barcodeSearchProvider = newValue
                }
            )
        case .aiImageSearch:
            return Binding(
                get: { aiService.aiImageSearchProvider },
                set: { newValue in
                    aiService.aiImageSearchProvider = newValue
                    UserDefaults.standard.aiImageProvider = newValue
                }
            )
        }
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
