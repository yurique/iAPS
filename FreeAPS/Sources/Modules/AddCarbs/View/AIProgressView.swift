import PhotosUI
import SwiftUI
import UIKit

struct AIProgressView: View {
    let analysisRequest: AnalysisRequest
    let onFoodAnalyzed: (FoodAnalysisResult, AnalysisRequest) -> Void
    let onFoodSearched: ([OpenFoodFactsProduct], AnalysisRequest) -> Void
    let onCancel: () -> Void

    @State private var isAnalyzing: Bool = false

    @State private var analysisError: String?
    @State private var showingErrorAlert = false
    @State private var telemetryLogs: [String] = []
    @State private var selectedPhotoItem: PhotosPickerItem?

    @State private var searchTask: Task<Void, Never>? = nil
    @State private var analysisStart: Date? = nil

    var body: some View {
        ZStack {
            // Background layer - full screen image or text query display
            switch analysisRequest {
            case let .image(image):
                GeometryReader { proxy in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }

            case let .query(query):
                VStack {
                    Spacer()
                        .frame(height: 100)

                    // Search query display styled like user input
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        Text(query)
                            .font(.title3)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    Spacer()
                }
            }

            // Foreground layer - analyzing pill at bottom (respects safe area)
            VStack {
                Spacer()
                    .allowsHitTesting(false)

                AnalyzingPill(title: "Analyzing food with AI…", startDate: analysisStart) {
                    searchTask?.cancel()
                    searchTask = nil
                    analysisStart = self.analysisStart
                    onCancel()
                }
                .padding(.horizontal)
                .padding(.bottom, 80)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipped()
        .background(Color(.systemBackground))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if !isAnalyzing, analysisError == nil {
                    analysisStart = Date()
                    analyzeImage()
                }
            }
        }
        .onDisappear {
            searchTask?.cancel()
            searchTask = nil
        }
        .navigationTitle("AI Food Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .alert("Analysis Error", isPresented: $showingErrorAlert) {
            // Credit/quota exhaustion errors - provide direct guidance
            if analysisError?.contains("credits exhausted") == true || analysisError?.contains("quota exceeded") == true {
                Button("Cancel", role: .cancel) {
                    analysisError = nil
                }
            }
            // Rate limit errors - suggest waiting
            else if analysisError?.contains("rate limit") == true {
                Button("Wait and Retry") {
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        analyzeImage()
                    }
                }
                Button("Cancel", role: .cancel) {
                    analysisError = nil
                    onCancel()
                }
            }
            // General errors - provide standard options
            else {
                Button("Cancel", role: .cancel) {
                    analysisError = nil
                    onCancel()
                }
            }
        } message: {
            if analysisError?.contains("credits exhausted") == true {
                Text("Your AI provider has run out of credits. Please check your account billing or try a different provider.")
            } else if analysisError?.contains("quota exceeded") == true {
                Text("Your AI provider quota has been exceeded. Please check your usage limits or try a different provider.")
            } else if analysisError?.contains("rate limit") == true {
                Text("Too many requests sent to your AI provider. Please wait a moment before trying again.")
            } else {
                Text(analysisError ?? "Unknown error occurred")
            }
        }
    }

    private func analyzeImage() {
        // Check if AI service is configured
        let aiService = ConfigurableAIService.shared

        switch analysisRequest {
        case .image:
            guard aiService.isImageAnalysisConfigured else {
                analysisError = "AI service not configured. Please check settings."
                showingErrorAlert = true
                return
            }
        case .query:
            guard aiService.isTextSearchConfigured else {
                analysisError = "AI service not configured. Please check settings."
                showingErrorAlert = true
                return
            }
        }

        isAnalyzing = true
        analysisError = nil
        telemetryLogs = []

        searchTask?.cancel()
        searchTask = Task {
            do {
                switch analysisRequest {
                case let .image(image):
                    let result = try await aiService.analyzeFoodImage(image) { telemetryMessage in
                        Task { @MainActor in
                            addTelemetryLog(telemetryMessage)
                        }
                    }
                    await MainActor.run {
                        addTelemetryLog("✅ Analysis complete!")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            isAnalyzing = false
                            analysisStart = nil
                            onFoodAnalyzed(result, analysisRequest)
                        }
                    }
                case let .query(query):
                    let result = try await aiService.analyzeFoodQuery(query) { telemetryMessage in
                        Task { @MainActor in
                            addTelemetryLog(telemetryMessage)
                        }
                    }
                    await MainActor.run {
                        addTelemetryLog("✅ Analysis complete!")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            isAnalyzing = false
                            analysisStart = nil
                            onFoodSearched(result, analysisRequest)
                        }
                    }
                }

            } catch {
                await MainActor.run {
                    addTelemetryLog("⚠️ Connection interrupted")
                }
                try? await Task.sleep(nanoseconds: 300_000_000)

                await MainActor.run {
                    addTelemetryLog("❌ Analysis failed")

                    // ✅ VERBESSERT: Stabilere Fehlerbehandlung
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isAnalyzing = false
                        analysisStart = nil
                        analysisError = error.localizedDescription
                        showingErrorAlert = true
                    }
                }
            }
        }
    }

    private func addTelemetryLog(_ message: String) {
        telemetryLogs.append(NSLocalizedString(message, comment: "Telemetry log"))
        if telemetryLogs.count > 10 {
            telemetryLogs.removeFirst()
        }
    }
}

struct TelemetryWindow: View {
    let logs: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Spacer()
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.green)
                    .font(.caption2)
                Text("Analysis Status")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))

            // Scrolling logs
            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(logs.enumerated()), id: \.offset) { index, log in
                            HStack {
                                Text(NSLocalizedString(log, comment: "Log"))
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 2)
                            .id(index)
                        }
                        Color.clear.frame(height: 56)
                    }
                    .onAppear {
                        if !logs.isEmpty {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(logs.count - 1, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: logs.count) {
                        if !logs.isEmpty {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(logs.count - 1, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 14)
            .frame(height: 320)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .padding(.top, 8)
    }
}

struct AnalyzingPill: View {
    var title: LocalizedStringKey = "Analyzing…"
    var startDate: Date? = nil
    var onCancel: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var rotation: Double = 0
    @State private var shimmerPhase: CGFloat = -140

    var body: some View {
        // Local constants for palette and sizing
        let baseColors: [Color] = [
            Color.gray.opacity(0.22), Color.gray.opacity(0.22),
            Color.teal.opacity(0.45), Color.yellow.opacity(0.45), Color.red.opacity(0.45), Color.purple.opacity(0.45),
            Color.gray.opacity(0.22), Color.gray.opacity(0.22)
        ]
        let waveColors: [Color] = [
            .clear, .clear,
            Color.teal.opacity(0.7), Color.yellow.opacity(0.7), Color.red.opacity(0.7), Color.purple.opacity(0.7),
            .clear, .clear
        ]

        let innerFillBlur: CGFloat = 22
        let innerFillOpacityDark: CGFloat = 0.35
        let innerFillOpacityLight: CGFloat = 0.22

        let outerHaloLineWidth: CGFloat = 2
        let outerHaloBlur: CGFloat = 6
        let outerHaloOpacityDark: CGFloat = 0.32
        let outerHaloOpacityLight: CGFloat = 0.18

        let waveInnerBlur: CGFloat = 28
        let waveInnerOpacityDark: CGFloat = 0.45
        let waveInnerOpacityLight: CGFloat = 0.30

        let waveOuterLineWidth: CGFloat = 10
        let waveOuterBlur: CGFloat = 20
        let waveOuterOpacityDark: CGFloat = 0.50
        let waveOuterOpacityLight: CGFloat = 0.35

        let borderLineWidth: CGFloat = 0.6
        let borderBlur: CGFloat = 0.8
        let borderOpacity: CGFloat = 0.4

        let content = HStack(spacing: 10) {
            // Base text at 50% opacity, with a moving highlight overlay masked to the same glyphs
            Text(title)
                .font(.footnote)
                .foregroundStyle(.primary)
                .opacity(0.5)
                .overlay(
                    Text(title)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .mask(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .black.opacity(0.0), location: 0.0),
                                    .init(color: .white, location: 0.5),
                                    .init(color: .black.opacity(0.0), location: 1.0)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .offset(x: shimmerPhase)
                        )
                )
            Spacer(minLength: 8)
            if let startDate {
                Text(startDate, style: .relative)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 6)
            }

            if let onCancel {
                Button("Cancel", action: onCancel)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .backgroundStyle(.ultraThinMaterial)
                    .buttonStyle(.bordered)
                    .padding(.horizontal, -6)
                    .padding(.vertical, -4)
                    .buttonBorderShape(.capsule)
                    .accessibilityLabel("Cancel")
            }
        }

        return content
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            // Inner fill glow covering the whole capsule (subtle, neutral+color)
            .background(
                AngularGradient(
                    gradient: Gradient(colors: baseColors),
                    center: .center,
                    angle: .degrees(rotation)
                )
                .blur(radius: innerFillBlur)
                .opacity(colorScheme == .dark ? innerFillOpacityDark : innerFillOpacityLight)
                .blendMode(.plusLighter)
                .mask(Capsule())
            )
            // Outer halo (soft, subtle)
            .background(
                Capsule()
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: baseColors),
                            center: .center,
                            angle: .degrees(rotation)
                        ),
                        lineWidth: outerHaloLineWidth
                    )
                    .blur(radius: outerHaloBlur)
                    .opacity(colorScheme == .dark ? outerHaloOpacityDark : outerHaloOpacityLight)
                    .blendMode(.plusLighter)
            )
            // Running wave (inner fill) amplifies the glow and spills inside
            .background(
                AngularGradient(
                    gradient: Gradient(colors: waveColors),
                    center: .center,
                    angle: .degrees(rotation)
                )
                .blur(radius: waveInnerBlur)
                .opacity(colorScheme == .dark ? waveInnerOpacityDark : waveInnerOpacityLight)
                .blendMode(.plusLighter)
                .mask(Capsule())
            )
            // Running wave (outer halo) – larger around the hotspot
            .overlay(
                Capsule()
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: waveColors),
                            center: .center,
                            angle: .degrees(rotation)
                        ),
                        lineWidth: waveOuterLineWidth
                    )
                    .blur(radius: waveOuterBlur)
                    .opacity(colorScheme == .dark ? waveOuterOpacityDark : waveOuterOpacityLight)
                    .blendMode(.plusLighter)
            )
            // Subtle border that blends with the glow
            .overlay(
                Capsule()
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: baseColors),
                            center: .center,
                            angle: .degrees(rotation)
                        ),
                        lineWidth: borderLineWidth
                    )
                    .blur(radius: borderBlur)
                    .opacity(borderOpacity)
                    .blendMode(.plusLighter)
            )
            // Traveling spotlight using trim with wrap-around handling (timeline-driven)
            .overlay(
                TimelineView(.animation) { context in
                    let duration: TimeInterval = 5 // seconds per full revolution
                    let t = context.date.timeIntervalSinceReferenceDate
                    let phase = t.truncatingRemainder(dividingBy: duration) / duration
                    let seg: CGFloat = 0.05
                    let start = CGFloat(phase)
                    let end = start + seg

                    ZStack {
                        // Head segment (start ..< min(end, 1))
                        Capsule()
                            .inset(by: 1.5)
                            .trim(from: start, to: min(end, 1))
                            .stroke(
                                Color.white,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .blur(radius: 1)
                            .opacity(colorScheme == .dark ? 0.2 : 0.2)
                            .blendMode(.plusLighter)
                            .allowsHitTesting(false)

                        Capsule()
                            .inset(by: 1.5)
                            .trim(from: start, to: min(end, 1))
                            .stroke(
                                Color.white,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .blur(radius: 4)
                            .opacity(colorScheme == .dark ? 0.2 : 0.2)
                            .blendMode(.plusLighter)
                            .allowsHitTesting(false)

                        // Tail segment (wraps from 0 when end > 1)
                        if end > 1 {
                            Capsule()
                                .inset(by: 1.5)
                                .trim(from: 0, to: end - 1)
                                .stroke(
                                    Color.white,
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                                )
                                .blur(radius: 1)
                                .opacity(colorScheme == .dark ? 0.2 : 0.2)
                                .blendMode(.plusLighter)
                                .allowsHitTesting(false)

                            Capsule()
                                .inset(by: 1.5)
                                .trim(from: 0, to: end - 1)
                                .stroke(
                                    Color.white,
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .blur(radius: 4)
                                .opacity(colorScheme == .dark ? 0.2 : 0.2)
                                .blendMode(.plusLighter)
                                .allowsHitTesting(false)
                        }
                    }
                }
            )
            .compositingGroup()
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.1), radius: 10, x: 0, y: 5)
            .onAppear {
                // Delay animations slightly to allow navigation to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }

                    withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                        shimmerPhase = 140
                    }
                }
            }
//            .animation(.linear(duration: 6).repeatForever(autoreverses: false), value: rotation)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(title))
            .accessibilityHint("Analysis in progress")
            .accessibilityAddTraits(.updatesFrequently)
    }
}
