import PhotosUI
import SwiftUI
import UIKit

/// Camera view for AI-powered food analysis - iOS 26 COMPATIBLE
struct AICameraView: View {
    let onFoodAnalyzed: (FoodAnalysisResult, UIImage?) -> Void
    let onCancel: () -> Void

    @State private var capturedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var isAnalyzing = false
    @State private var analysisError: String?
    @State private var showingErrorAlert = false
    @State private var imageSourceType: ImageSourceType = .camera
    @State private var telemetryLogs: [String] = []
    @State private var showTelemetry = false
    @State private var showingTips = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    enum ImageSourceType {
        case camera
        case photoLibrary
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Auto-launch camera interface
                if capturedImage == nil {
                    VStack(spacing: 20) {
                        Spacer()

                        // Simple launch message
                        VStack(spacing: 16) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 64))
                                .foregroundColor(.accentColor)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Better photos = better estimates")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                VStack(alignment: .leading, spacing: 8) {
                                    CameraTipRow(
                                        icon: "sun.max.fill",
                                        title: "Use bright, even light",
                                        detail: "Harsh shadows confuse the AI and dim light can hide textures."
                                    )
                                    CameraTipRow(
                                        icon: "arrow.2.circlepath",
                                        title: "Clear the area",
                                        detail: "Remove napkins, lids, or packaging that may be misidentified as food."
                                    )
                                    CameraTipRow(
                                        icon: "square.dashed",
                                        title: "Frame the full meal",
                                        detail: "Make sure every food item is in the frame."
                                    )
                                    CameraTipRow(
                                        icon: "ruler",
                                        title: "Add a size reference",
                                        detail: "Forks, cups, or hands help AI calculate realistic portions."
                                    )
                                    CameraTipRow(
                                        icon: "camera.metering.spot",
                                        title: "Shoot from slightly above",
                                        detail: "Keep the camera level to reduce distortion and keep portions proportional."
                                    )
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        Spacer()

                        // Quick action buttons - iOS 26 COMPATIBLE
                        VStack(spacing: 12) {
                            Button(action: {
                                imageSourceType = .camera
                                showingImagePicker = true
                            }) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 14))
                                    Text("Take a Photo")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }

                            // ✅ PhotosPicker statt UIImagePickerController
                            PhotosPicker(
                                selection: $selectedPhotoItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                HStack {
                                    Image(systemName: "photo.fill")
                                    Text("Choose from Library")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                            }
                            .onChange(of: selectedPhotoItem) {
                                Task {
                                    if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data)
                                    {
                                        await MainActor.run {
                                            capturedImage = uiImage
                                            selectedPhotoItem = nil // Reset selection
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                } else {
                    // Show captured image and auto-start analysis
                    VStack(spacing: 20) {
                        // Captured image
                        Image(uiImage: capturedImage!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                            .padding(.horizontal)

                        // Analysis in progress (auto-started)
                        VStack(spacing: 16) {
                            AnalyzingPill(title: "Analyzing food with AI…") {
                                capturedImage = nil
                                isAnalyzing = false
                            }

                            Text("Use Cancel to retake photo")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            // Telemetry window
                            if showTelemetry && !telemetryLogs.isEmpty {
                                TelemetryWindow(logs: telemetryLogs)
                                    .transition(.opacity.combined(with: .scale))
                            }
                        }
                        .padding()

                        Spacer()
                    }
                    .padding(.top)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if !isAnalyzing, analysisError == nil {
                                analyzeImage()
                            }
                        }
                    }
                }
            }
            .navigationTitle("AI Food Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("Cancel") {
//                        onCancel()
//                    }
//                }
//            }
        }
        .fullScreenCover(isPresented: $showingImagePicker) {
            if imageSourceType == .camera {
                ModernCameraView(image: $capturedImage, isPresented: $showingImagePicker)
            }
        }
        .alert("Analysis Error", isPresented: $showingErrorAlert) {
            // Credit/quota exhaustion errors - provide direct guidance
            if analysisError?.contains("credits exhausted") == true || analysisError?.contains("quota exceeded") == true {
                Button("Check Account") {
                    analysisError = nil
                }
                Button("Try Different Provider") {
                    ConfigurableAIService.shared.resetToDefault()
                    analysisError = nil
                    analyzeImage()
                }
                Button("Retake Photo") {
                    capturedImage = nil
                    analysisError = nil
                }
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
                Button("Try Different Provider") {
                    ConfigurableAIService.shared.resetToDefault()
                    analysisError = nil
                    analyzeImage()
                }
                Button("Retake Photo") {
                    capturedImage = nil
                    analysisError = nil
                }
                Button("Cancel", role: .cancel) {
                    analysisError = nil
                }
            }
            // General errors - provide standard options
            else {
                Button("Retry Analysis") {
                    analyzeImage()
                }
                Button("Retake Photo") {
                    capturedImage = nil
                    analysisError = nil
                }
                if analysisError?.contains("404") == true || analysisError?.contains("service error") == true {
                    Button("Reset to Default") {
                        ConfigurableAIService.shared.resetToDefault()
                        analysisError = nil
                        analyzeImage()
                    }
                }
                Button("Cancel", role: .cancel) {
                    analysisError = nil
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
        guard let image = capturedImage else { return }

        // Check if AI service is configured
        let aiService = ConfigurableAIService.shared
        guard aiService.isImageAnalysisConfigured else {
            analysisError = "AI service not configured. Please check settings."
            showingErrorAlert = true
            return
        }

        isAnalyzing = true
        analysisError = nil
        telemetryLogs = []
        showTelemetry = true

        Task {
            do {
                let result = try await aiService.analyzeFoodImage(image) { telemetryMessage in
                    Task { @MainActor in
                        addTelemetryLog(telemetryMessage)
                    }
                }

                await MainActor.run {
                    addTelemetryLog("✅ Analysis complete!")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        showTelemetry = false
                        isAnalyzing = false
                        onFoodAnalyzed(result, capturedImage)
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
                        showTelemetry = false
                        isAnalyzing = false
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

struct ModernCameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.allowsEditing = false
        picker.navigationBar.tintColor = .systemBlue
        picker.view.tintColor = .systemBlue

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context _: Context) {
        uiViewController.navigationBar.tintColor = .systemBlue
        uiViewController.view.tintColor = .systemBlue
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ModernCameraView

        init(_ parent: ModernCameraView) {
            self.parent = parent
        }

        func imagePickerController(
            _: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

private struct CameraTipRow: View {
    let icon: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .font(.system(size: 20, weight: .semibold))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            Text(title)
                .font(.footnote)
                .foregroundStyle(.primary.opacity(0.9))
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .white.opacity(0.7), location: 0.0),
                            .init(color: .white.opacity(1.0), location: 0.5),
                            .init(color: .white.opacity(0.7), location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: shimmerPhase)
                )
            Spacer(minLength: 8)
            if let onCancel {
                Button("Cancel", action: onCancel)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .buttonStyle(.borderless)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .contentShape(Capsule())
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
            .compositingGroup()
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.1), radius: 10, x: 0, y: 5)
            .onAppear {
                rotation = 360
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    shimmerPhase = 140
                }
            }
            // 2× slower than before (6s per rotation)
            .animation(.linear(duration: 6).repeatForever(autoreverses: false), value: rotation)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(title))
            .accessibilityHint("Analysis in progress")
            .accessibilityAddTraits(.updatesFrequently)
    }
}
