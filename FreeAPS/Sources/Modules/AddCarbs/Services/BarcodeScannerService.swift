import AVFoundation
import Combine
import Foundation
import os.log
import UIKit
import Vision

/// Service for barcode scanning using the device camera and Vision framework
class BarcodeScannerService: NSObject, ObservableObject {
    // MARK: - Properties

    /// Published scan results
    @Published var lastScanResult: BarcodeScanResult?

    /// Published scanning state
    @Published var isScanning: Bool = false

    /// Published error state
    @Published var scanError: BarcodeScanError?

    /// Camera authorization status
    @Published var cameraAuthorizationStatus: AVAuthorizationStatus = .notDetermined

    // MARK: - Scanning State Management

    /// Tracks recently scanned barcodes to prevent duplicates
    private var recentlyScannedBarcodes: Set<String> = []

    /// Timer to clear recently scanned barcodes
    private var duplicatePreventionTimer: Timer?

    /// Flag to prevent multiple simultaneous scan processing
    private var isProcessingScan: Bool = false

    /// Session health monitoring
    private var lastValidFrameTime = Date()
    private var sessionHealthTimer: Timer?

    // Camera session components
    private let captureSession = AVCaptureSession()
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "barcode.scanner.session", qos: .userInitiated)
    private var _previewLayer: AVCaptureVideoPreviewLayer?

    // Vision request for barcode detection
    private lazy var barcodeRequest: VNDetectBarcodesRequest = {
        let request = VNDetectBarcodesRequest(completionHandler: handleDetectedBarcodes)
        request.symbologies = [
            .ean8, .ean13, .upce, .code128, .code39, .code93,
            .dataMatrix, .qr, .pdf417, .aztec, .i2of5
        ]
        return request
    }()

    private let log = OSLog(subsystem: "", category: "BarcodeScannerService")

    // MARK: - Public Interface

    /// Shared instance for app-wide use
    static let shared = BarcodeScannerService()

    /// Focus the camera at a specific point
    func focusAtPoint(_ point: CGPoint) {
        sessionQueue.async { [weak self] in
            self?.setFocusPoint(point)
        }
    }

    override init() {
        super.init()
        checkCameraAuthorization()
        // setupSessionNotifications()
    }

    /* private func setupSessionNotifications() {
         NotificationCenter.default.addObserver(
             self,
             selector: #selector(sessionWasInterrupted),
             name: .AVCaptureSessionWasInterrupted,
             object: captureSession
         )

         NotificationCenter.default.addObserver(
             self,
             selector: #selector(sessionInterruptionEnded),
             name: .AVCaptureSessionInterruptionEnded,
             object: captureSession
         )

         NotificationCenter.default.addObserver(
             self,
             selector: #selector(sessionRuntimeError),
             name: .AVCaptureSessionRuntimeError,
             object: captureSession
         )
     } */

    @objc private func sessionWasInterrupted(notification: NSNotification) {
        print("🎥 ========== Session was interrupted ==========")

        if let userInfo = notification.userInfo,
           let reasonValue = userInfo[AVCaptureSessionInterruptionReasonKey] as? Int,
           let reason = AVCaptureSession.InterruptionReason(rawValue: reasonValue)
        {
            print("🎥 Interruption reason: \(reason)")

            switch reason {
            case .videoDeviceNotAvailableInBackground:
                print("🎥 Interruption: App went to background")
            case .audioDeviceInUseByAnotherClient:
                print("🎥 Interruption: Audio device in use by another client")
            case .videoDeviceInUseByAnotherClient:
                print("🎥 Interruption: Video device in use by another client")
            case .videoDeviceNotAvailableWithMultipleForegroundApps:
                print("🎥 Interruption: Video device not available with multiple foreground apps")
            case .videoDeviceNotAvailableDueToSystemPressure:
                print("🎥 Interruption: Video device not available due to system pressure")
            default:
                print("🎥 Interruption: Unknown reason")
            }
        }

        DispatchQueue.global().async { [weak self] in
            self?.isScanning = false
            // Don't immediately set an error - wait to see if interruption ends
        }
    }

    @objc private func sessionInterruptionEnded(notification _: NSNotification) {
        print("🎥 ========== Session interruption ended ==========")

        sessionQueue.async {
            print("🎥 Attempting to restart session after interruption...")

            // Wait a bit before restarting
            Thread.sleep(forTimeInterval: 0.5)

            if !self.captureSession.isRunning {
                print("🎥 Session not running, starting...")
                self.captureSession.startRunning()

                // Check if it actually started
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if self.captureSession.isRunning {
                        print("🎥 ✅ Session successfully restarted after interruption")
                        self.isScanning = true
                        self.scanError = nil
                    } else {
                        print("🎥 ❌ Session failed to restart after interruption")
                        self.scanError = BarcodeScanError.sessionSetupFailed
                        self.isScanning = false
                    }
                }
            } else {
                print("🎥 Session already running after interruption ended")
                DispatchQueue.main.async {
                    self.isScanning = true
                    self.scanError = nil
                }
            }
        }
    }

    @objc private func sessionRuntimeError(notification: NSNotification) {
        print("🎥 Session runtime error occurred")
        if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError {
            print("🎥 Runtime error: \(error.localizedDescription)")

            DispatchQueue.global().async { [weak self] in
                self?.scanError = .sessionSetupFailed
                self?.isScanning = false
            }
        }
    }

    /// Start barcode scanning session
    func startScanning() {
        print("🎥 ========== BarcodeScannerService.startScanning() CALLED ==========")
        print("🎥 Current thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")
        print("🎥 Camera authorization status: \(cameraAuthorizationStatus)")
        print("🎥 Current session state - isRunning: \(captureSession.isRunning)")
        print("🎥 Current session inputs: \(captureSession.inputs.count)")
        print("🎥 Current session outputs: \(captureSession.outputs.count)")

        // Check camera authorization fresh from the system
        let freshStatus = AVCaptureDevice.authorizationStatus(for: .video)
        print("🎥 Fresh authorization status from system: \(freshStatus)")
        cameraAuthorizationStatus = freshStatus

        // Ensure we have camera permission before proceeding
        guard freshStatus == .authorized else {
            print("🎥 ERROR: Camera not authorized, status: \(freshStatus)")
            DispatchQueue.global().async {
                if freshStatus == .notDetermined {
                    // Try to request permission
                    print("🎥 Permission not determined, requesting...")
                    AVCaptureDevice.requestAccess(for: .video) { granted in
                        DispatchQueue.global().async { [weak self] in
                            if granted {
                                print("🎥 Permission granted, retrying scan setup...")
                                self?.startScanning()
                            } else {
                                self?.scanError = .cameraPermissionDenied
                                self?.isScanning = false
                            }
                        }
                    }
                } else {
                    self.scanError = .cameraPermissionDenied
                    self.isScanning = false
                }
            }
            return
        }

        // Do session setup on background queue
        sessionQueue.async { [weak self] in
            guard let self = self else {
                print("🎥 ERROR: Self is nil in sessionQueue")
                return
            }

            print("🎥 Setting up session on background queue...")

            do {
                try self.setupCaptureSession()
                print("🎥 Session setup completed successfully")

                // Start session on background queue to avoid blocking main thread
                print("🎥 Starting capture session...")
                self.captureSession.startRunning()
                print("🎥 startRunning() called, waiting for session to stabilize...")

                // Wait a moment for the session to start and stabilize
                Thread.sleep(forTimeInterval: 0.3)

                // Check if the session is running and not interrupted
                let isRunningNow = self.captureSession.isRunning
                let isInterrupted = self.captureSession.isInterrupted
                print("🎥 Session status after start: running=\(isRunningNow), interrupted=\(isInterrupted)")

                if isRunningNow && !isInterrupted {
                    // Session started successfully
                    DispatchQueue.main.async { [weak self] in
                        self?.isScanning = true
                        self?.scanError = nil
                        print("🎥 ✅ SUCCESS: Session running and not interrupted")

                        // Start session health monitoring
                        self?.startSessionHealthMonitoring()
                    }

                    // Monitor for delayed interruption
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if !self.captureSession.isRunning || self.captureSession.isInterrupted {
                            print("🎥 ⚠️ DELAYED INTERRUPTION: Session was interrupted after starting")
                            // Don't set error immediately - interruption handler will deal with it
                        } else {
                            print("🎥 ✅ Session still running after 1 second - stable")
                        }
                    }
                } else {
                    // Session failed to start or was immediately interrupted
                    print("🎥 ❌ Session failed to start properly")
                    DispatchQueue.main.async {
                        self.scanError = BarcodeScanError.sessionSetupFailed
                        self.isScanning = false
                    }
                }

                os_log("Barcode scanning session setup completed", log: self.log, type: .info)

            } catch let error as BarcodeScanError {
                print("🎥 ❌ BarcodeScanError caught during setup: \(error)")
                print("🎥 Error description: \(error.localizedDescription)")
                print("🎥 Recovery suggestion: \(error.recoverySuggestion ?? "none")")
                DispatchQueue.main.async {
                    self.scanError = error
                    self.isScanning = false
                }
            } catch {
                print("🎥 ❌ Unknown error caught during setup: \(error)")
                print("🎥 Error description: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("🎥 Error domain: \(nsError.domain)")
                    print("🎥 Error code: \(nsError.code)")
                    print("🎥 Error userInfo: \(nsError.userInfo)")
                }
                DispatchQueue.main.async {
                    self.scanError = .sessionSetupFailed
                    self.isScanning = false
                }
            }
        }
    }

    /// Stop barcode scanning session
    func stopScanning() {
        print("🎥 stopScanning() called")

        // Stop health monitoring
        stopSessionHealthMonitoring()

        // Clear scanning state
        DispatchQueue.main.async { [weak self] in
            self?.isScanning = false
            self?.lastScanResult = nil
        }

        // Internal state on background thread
        DispatchQueue.global().async { [weak self] in
            self?.isProcessingScan = false
            self?.recentlyScannedBarcodes.removeAll()
        }

        // Stop timers
        duplicatePreventionTimer?.invalidate()
        duplicatePreventionTimer = nil

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            print("🎥 Performing complete session cleanup...")

            // Stop the session if running
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                print("🎥 Session stopped")
            }

            // Wait for session to fully stop
            Thread.sleep(forTimeInterval: 0.3)

            // Clear all inputs and outputs to prepare for clean restart
            self.captureSession.beginConfiguration()

            // Remove all inputs
            for input in self.captureSession.inputs {
                print("🎥 Removing input: \(type(of: input))")
                self.captureSession.removeInput(input)
            }

            // Remove all outputs
            for output in self.captureSession.outputs {
                print("🎥 Removing output: \(type(of: output))")
                self.captureSession.removeOutput(output)
            }

            self.captureSession.commitConfiguration()
            print(
                "🎥 Session completely cleaned - inputs: \(self.captureSession.inputs.count), outputs: \(self.captureSession.outputs.count)"
            )

            os_log("Barcode scanning session stopped and cleaned", log: self.log, type: .info)

            _previewLayer = nil // ✅ Wichtig für Cleanup
        }
    }

    deinit {
        //   NotificationCenter.default.removeObserver(self)
        stopScanning()
    }

    /// Request camera permission
    func requestCameraPermission() -> AnyPublisher<Bool, Never> {
        print("🎥 ========== requestCameraPermission() CALLED ==========")
        print("🎥 Current authorization status: \(cameraAuthorizationStatus)")

        return Future<Bool, Never> { [weak self] promise in
            print("🎥 Requesting camera access...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                print("🎥 Camera access request result: \(granted)")
                let newStatus = AVCaptureDevice.authorizationStatus(for: .video)
                print("🎥 New authorization status: \(newStatus)")

                DispatchQueue.main.async {
                    self?.cameraAuthorizationStatus = newStatus
                    print("🎥 Updated service authorization status to: \(newStatus)")
                    promise(.success(granted))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// Clear scan state to prepare for next scan
    func clearScanState() {
        print("🔍 Clearing scan state for next scan")
        DispatchQueue.global().async { [weak self] in
            // Don't clear lastScanResult immediately - other observers may need it
            self?.isProcessingScan = false
        }

        // Clear recently scanned after a delay to allow for a fresh scan
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            self.recentlyScannedBarcodes.removeAll()
            print("🔍 Ready for next scan")
        }

        // Clear scan result after a longer delay to allow all observers to process
        DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
            self.lastScanResult = nil
            print("🔍 Cleared lastScanResult after delay")
        }
    }

    /// Complete reset of the scanner service
    func resetService() {
        print("🎥 ========== resetService() CALLED ==========")

        // Stop everything first
        stopScanning()

        // Wait for cleanup to complete
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            // Wait for session to be fully stopped and cleaned
            Thread.sleep(forTimeInterval: 0.5)

            DispatchQueue.main.async {
                // Reset all state
                self.lastScanResult = nil
                self.isProcessingScan = false
                self.scanError = nil
                self.recentlyScannedBarcodes.removeAll()

                // Reset session health monitoring
                self.lastValidFrameTime = Date()

                print("🎥 ✅ Scanner service completely reset")
            }
        }
    }

    /// Check if the session has existing configuration
    var hasExistingSession: Bool {
        !captureSession.inputs.isEmpty || !captureSession.outputs.isEmpty
    }

    /// Simple test function to verify basic camera access without full session setup
    func testCameraAccess() {
        print("🎥 ========== testCameraAccess() ==========")

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("🎥 Current authorization: \(status)")

        #if targetEnvironment(simulator)
            print("🎥 Running in simulator - skipping device test")
            return
        #endif

        guard status == .authorized else {
            print("🎥 Camera not authorized - status: \(status)")
            return
        }

        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera],
            mediaType: .video,
            position: .unspecified
        ).devices

        print("🎥 Available devices: \(devices.count)")
        for (index, device) in devices.enumerated() {
            print("🎥   Device \(index): \(device.localizedName) (\(device.modelID))")
            print("🎥     Position: \(device.position)")
            print("🎥     Connected: \(device.isConnected)")
        }

        if let defaultDevice = AVCaptureDevice.default(for: .video) {
            print("🎥 Default device: \(defaultDevice.localizedName)")

            do {
                let input = try AVCaptureDeviceInput(device: defaultDevice)
                print("🎥 ✅ Successfully created device input")

                let testSession = AVCaptureSession()
                if testSession.canAddInput(input) {
                    print("🎥 ✅ Session can add input")
                } else {
                    print("🎥 ❌ Session cannot add input")
                }
            } catch {
                print("🎥 ❌ Failed to create device input: \(error)")
            }
        } else {
            print("🎥 ❌ No default video device available")
        }
    }

    /// Setup camera session without starting scanning (for preview layer)
    func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                try self.setupCaptureSession()

                DispatchQueue.main.async {
                    self.scanError = nil
                }

                os_log("Camera session setup completed", log: self.log, type: .info)

            } catch let error as BarcodeScanError {
                DispatchQueue.main.async {
                    self.scanError = error
                }
            } catch {
                DispatchQueue.main.async {
                    self.scanError = .sessionSetupFailed
                }
            }
        }
    }

    /// Reset and reinitialize the camera session
    func resetSession() {
        print("🎥 ========== resetSession() CALLED ==========")

        sessionQueue.async { [weak self] in
            guard let self = self else {
                print("🎥 ERROR: Self is nil in resetSession")
                return
            }

            print("🎥 Performing complete session reset...")

            // Stop current session
            if self.captureSession.isRunning {
                print("🎥 Stopping running session...")
                self.captureSession.stopRunning()
                Thread.sleep(forTimeInterval: 0.5) // Longer wait
            }

            // Clear all inputs and outputs
            print("🎥 Clearing session configuration...")
            self.captureSession.beginConfiguration()
            self.captureSession.inputs.forEach {
                print("🎥 Removing input: \(type(of: $0))")
                self.captureSession.removeInput($0)
            }
            self.captureSession.outputs.forEach {
                print("🎥 Removing output: \(type(of: $0))")
                self.captureSession.removeOutput($0)
            }
            self.captureSession.commitConfiguration()
            print("🎥 Session cleared and committed")

            // Wait longer before attempting to rebuild
            Thread.sleep(forTimeInterval: 0.5)

            print("🎥 Attempting to rebuild session...")
            do {
                try self.setupCaptureSession()
                DispatchQueue.main.async {
                    self.scanError = nil
                    print("🎥 ✅ Session reset successful")
                }
            } catch {
                print("🎥 ❌ Session reset failed: \(error)")
                DispatchQueue.main.async {
                    self.scanError = .sessionSetupFailed
                }
            }
        }
    }

    /// Alternative simple session setup method
    func simpleSetupSession() throws {
        print("🎥 ========== simpleSetupSession() STARTING ==========")

        #if targetEnvironment(simulator)
            throw BarcodeScanError.cameraNotAvailable
        #endif

        guard cameraAuthorizationStatus == .authorized else {
            throw BarcodeScanError.cameraPermissionDenied
        }

        guard let device = AVCaptureDevice.default(for: .video) else {
            throw BarcodeScanError.cameraNotAvailable
        }

        print("🎥 Using device: \(device.localizedName)")

        // Create a completely new session
        let newSession = AVCaptureSession()
        newSession.sessionPreset = .high

        // Create input
        let input = try AVCaptureDeviceInput(device: device)
        guard newSession.canAddInput(input) else {
            throw BarcodeScanError.sessionSetupFailed
        }

        // Create output
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        guard newSession.canAddOutput(output) else {
            throw BarcodeScanError.sessionSetupFailed
        }

        // Configure session
        newSession.beginConfiguration()
        newSession.addInput(input)
        newSession.addOutput(output)
        output.setSampleBufferDelegate(self, queue: sessionQueue)
        newSession.commitConfiguration()

        // Replace the old session
        if captureSession.isRunning {
            captureSession.stopRunning()
        }

        // This is not ideal but might be necessary
        // We'll need to use reflection or recreate the session property
        print("🎥 Simple session setup completed")
    }

    /// Get video preview layer for UI integration
    /*   func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
         // Always create a new preview layer to avoid conflicts
         // Each view should have its own preview layer instance
         let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
         previewLayer.videoGravity = .resizeAspectFill
         print("🎥 Created preview layer for session: \(captureSession)")
         print(
             "🎥 Session running: \(captureSession.isRunning), inputs: \(captureSession.inputs.count), outputs: \(captureSession.outputs.count)"
         )
         return previewLayer
     }*/

    /// Get shared video preview layer
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        if _previewLayer == nil {
            _previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            _previewLayer?.videoGravity = .resizeAspectFill
            print("🎥 Created SINGLETON preview layer")
        }
        return _previewLayer
    }

    // MARK: - Private Methods

    private func checkCameraAuthorization() {
        cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        print("🎥 Camera authorization status: \(cameraAuthorizationStatus)")

        #if targetEnvironment(simulator)
            print("🎥 WARNING: Running in iOS Simulator - camera functionality will be limited")
        #endif

        switch cameraAuthorizationStatus {
        case .notDetermined:
            print("🎥 Camera permission not yet requested")
        case .denied:
            print("🎥 Camera permission denied by user")
        case .restricted:
            print("🎥 Camera access restricted by system")
        case .authorized:
            print("🎥 Camera permission granted")
        @unknown default:
            print("🎥 Unknown camera authorization status")
        }
    }

    private func setupCaptureSession() throws {
        print("🎥 ========== setupCaptureSession() STARTING ==========")
        print("🎥 Current thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")
        print("🎥 Camera authorization status: \(cameraAuthorizationStatus)")

        // Check if running in simulator
        #if targetEnvironment(simulator)
            print("🎥 WARNING: Running in iOS Simulator - camera not available")
            throw BarcodeScanError.cameraNotAvailable
        #endif

        guard cameraAuthorizationStatus == .authorized else {
            print("🎥 ERROR: Camera permission denied - status: \(cameraAuthorizationStatus)")
            throw BarcodeScanError.cameraPermissionDenied
        }

        print("🎥 Finding best available camera device...")

        // Try to get the best available camera (like AI camera does)
        /*  let discoverySession = AVCaptureDevice.DiscoverySession(
             deviceTypes: [
                // .builtInTripleCamera, // iPhone Pro models
                 .builtInDualWideCamera, // iPhone models with dual camera
                 .builtInWideAngleCamera, // Standard camera
                 .builtInUltraWideCamera // Ultra-wide as fallback
             ],
             mediaType: .video,
             position: .back // Prefer back camera for scanning
         )*/
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera // ✅ Nur Wide Angle - zuverlässigste
            ],
            mediaType: .video,
            position: .back
        )

        guard let videoCaptureDevice = discoverySession.devices.first else {
            print("🎥 ERROR: No video capture device available")
            print("🎥 DEBUG: Available devices: \(discoverySession.devices.map(\.modelID))")
            throw BarcodeScanError.cameraNotAvailable
        }

        print("🎥 ✅ Got video capture device: \(videoCaptureDevice.localizedName)")
        print("🎥 Device model: \(videoCaptureDevice.modelID)")
        print("🎥 Device position: \(videoCaptureDevice.position)")
        print("🎥 Device available: \(videoCaptureDevice.isConnected)")

        // Enhanced camera configuration for optimal scanning (like AI camera)
        do {
            try videoCaptureDevice.lockForConfiguration()

            // Enhanced autofocus configuration
            if videoCaptureDevice.isFocusModeSupported(.continuousAutoFocus) {
                videoCaptureDevice.focusMode = .continuousAutoFocus
                print("🎥 ✅ Enabled continuous autofocus")
            } else if videoCaptureDevice.isFocusModeSupported(.autoFocus) {
                videoCaptureDevice.focusMode = .autoFocus
                print("🎥 ✅ Enabled autofocus")
            }

            // Set focus point to center for optimal scanning
            if videoCaptureDevice.isFocusPointOfInterestSupported {
                videoCaptureDevice.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                print("🎥 ✅ Set autofocus point to center")
            }

            // Enhanced exposure settings for better barcode/QR code detection
            if videoCaptureDevice.isExposureModeSupported(.continuousAutoExposure) {
                videoCaptureDevice.exposureMode = .continuousAutoExposure
                print("🎥 ✅ Enabled continuous auto exposure")
            } else if videoCaptureDevice.isExposureModeSupported(.autoExpose) {
                videoCaptureDevice.exposureMode = .autoExpose
                print("🎥 ✅ Enabled auto exposure")
            }

            // Set exposure point to center
            if videoCaptureDevice.isExposurePointOfInterestSupported {
                videoCaptureDevice.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
                print("🎥 ✅ Set auto exposure point to center")
            }

            // Configure for optimal performance
            if videoCaptureDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                videoCaptureDevice.whiteBalanceMode = .continuousAutoWhiteBalance
                print("🎥 ✅ Enabled continuous auto white balance")
            }

            // Set flash to auto for low light conditions
            if videoCaptureDevice.hasFlash {
                AVCapturePhotoSettings().flashMode = .auto
                print("🎥 ✅ Set flash mode to auto")
            }

            videoCaptureDevice.unlockForConfiguration()
            print("🎥 ✅ Enhanced camera configuration complete")
        } catch {
            print("🎥 ❌ Failed to configure camera: \(error)")
        }

        // Stop session if running to avoid conflicts
        if captureSession.isRunning {
            print("🎥 Stopping existing session before reconfiguration")
            captureSession.stopRunning()

            // Wait longer for the session to fully stop
            Thread.sleep(forTimeInterval: 0.3)
            print("🎥 Session stopped, waiting completed")
        }

        // Clear existing inputs and outputs
        print("🎥 Session state before cleanup:")
        print("🎥   - Inputs: \(captureSession.inputs.count)")
        print("🎥   - Outputs: \(captureSession.outputs.count)")
        print("🎥   - Running: \(captureSession.isRunning)")
        print("🎥   - Interrupted: \(captureSession.isInterrupted)")

        captureSession.beginConfiguration()
        print("🎥 Session configuration began")

        // Remove existing connections
        captureSession.inputs.forEach {
            print("🎥 Removing input: \(type(of: $0))")
            captureSession.removeInput($0)
        }
        captureSession.outputs.forEach {
            print("🎥 Removing output: \(type(of: $0))")
            captureSession.removeOutput($0)
        }

        do {
            print("🎥 Creating video input from device...")
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            print("🎥 ✅ Created video input successfully")

            // Set appropriate session preset for barcode scanning BEFORE adding inputs
            print("🎥 Setting session preset...")
            if captureSession.canSetSessionPreset(.high) {
                captureSession.sessionPreset = .high
                print("🎥 ✅ Set session preset to HIGH quality")
            } else if captureSession.canSetSessionPreset(.medium) {
                captureSession.sessionPreset = .medium
                print("🎥 ✅ Set session preset to MEDIUM quality")
            } else {
                print("🎥 ⚠️ Could not set preset to high or medium, using: \(captureSession.sessionPreset)")
            }

            print("🎥 Checking if session can add video input...")
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                print("🎥 ✅ Added video input to session successfully")
            } else {
                print("🎥 ❌ ERROR: Cannot add video input to session")
                print("🎥 Session preset: \(captureSession.sessionPreset)")
                print("🎥 Session interrupted: \(captureSession.isInterrupted)")
                captureSession.commitConfiguration()
                throw BarcodeScanError.sessionSetupFailed
            }

            print("🎥 Setting up video output...")
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ]

            print("🎥 Checking if session can add video output...")
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)

                // Set sample buffer delegate on the session queue
                videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
                print("🎥 ✅ Added video output to session successfully")
                print("🎥 Video output settings: \(videoOutput.videoSettings ?? [:])")
            } else {
                print("🎥 ❌ ERROR: Cannot add video output to session")
                captureSession.commitConfiguration()
                throw BarcodeScanError.sessionSetupFailed
            }

            print("🎥 Committing session configuration...")
            captureSession.commitConfiguration()
            print("🎥 ✅ Session configuration committed successfully")

            print("🎥 ========== FINAL SESSION STATE ==========")
            print("🎥 Inputs: \(captureSession.inputs.count)")
            print("🎥 Outputs: \(captureSession.outputs.count)")
            print("🎥 Preset: \(captureSession.sessionPreset)")
            print("🎥 Running: \(captureSession.isRunning)")
            print("🎥 Interrupted: \(captureSession.isInterrupted)")
            print("🎥 ========== SESSION SETUP COMPLETE ==========")

        } catch let error as BarcodeScanError {
            print("🎥 ❌ BarcodeScanError during setup: \(error)")
            captureSession.commitConfiguration()
            throw error
        } catch {
            print("🎥 ❌ Failed to setup capture session with error: \(error)")
            print("🎥 Error type: \(type(of: error))")
            print("🎥 Error details: \(error.localizedDescription)")

            if let nsError = error as NSError? {
                print("🎥 NSError domain: \(nsError.domain)")
                print("🎥 NSError code: \(nsError.code)")
                print("🎥 NSError userInfo: \(nsError.userInfo)")
            }

            // Check for specific AVFoundation errors
            if let avError = error as? AVError {
                print("🎥 AVError code: \(avError.code.rawValue)")
                print("🎥 AVError description: \(avError.localizedDescription)")

                switch avError.code {
                case .deviceNotConnected:
                    print("🎥 SPECIFIC ERROR: Camera device not connected")
                    captureSession.commitConfiguration()
                    throw BarcodeScanError.cameraNotAvailable
                case .deviceInUseByAnotherApplication:
                    print("🎥 SPECIFIC ERROR: Camera device in use by another application")
                    captureSession.commitConfiguration()
                    throw BarcodeScanError.sessionSetupFailed
                case .deviceWasDisconnected:
                    print("🎥 SPECIFIC ERROR: Camera device was disconnected")
                    captureSession.commitConfiguration()
                    throw BarcodeScanError.cameraNotAvailable
                case .mediaServicesWereReset:
                    print("🎥 SPECIFIC ERROR: Media services were reset")
                    captureSession.commitConfiguration()
                    throw BarcodeScanError.sessionSetupFailed
                default:
                    print("🎥 OTHER AVERROR: \(avError.localizedDescription)")
                }
            }

            captureSession.commitConfiguration()
            os_log("Failed to setup capture session: %{public}@", log: log, type: .error, error.localizedDescription)
            throw BarcodeScanError.sessionSetupFailed
        }
    }

    private func handleDetectedBarcodes(request: VNRequest, error: Error?) {
        // Update health monitoring
        lastValidFrameTime = Date()

        guard let observations = request.results as? [VNBarcodeObservation] else {
            if let error = error {
                os_log("Barcode detection failed: %{public}@", log: log, type: .error, error.localizedDescription)
            }
            return
        }

        // Prevent concurrent processing
        guard !isProcessingScan else {
            print("🔍 Skipping barcode processing - already processing another scan")
            return
        }

        // Find the best barcode detection with improved filtering
        let validBarcodes = observations.compactMap { observation -> BarcodeScanResult? in
            guard let barcodeString = observation.payloadStringValue,
                  !barcodeString.isEmpty,
                  observation.confidence > 0.5
            else { // Lower confidence for QR codes
                print(
                    "🔍 Filtered out barcode: '\(observation.payloadStringValue ?? "nil")' confidence: \(observation.confidence)"
                )
                return nil
            }

            // Handle QR codes differently from traditional barcodes
            if observation.symbology == .qr {
                print("🔍 QR Code detected - Raw data: '\(barcodeString.prefix(100))...'")

                // For QR codes, try to extract product identifier
                let processedBarcodeString = extractProductIdentifier(from: barcodeString) ?? barcodeString
                print("🔍 QR Code processed ID: '\(processedBarcodeString)'")

                return BarcodeScanResult(
                    barcodeString: processedBarcodeString,
                    barcodeType: observation.symbology,
                    confidence: observation.confidence,
                    bounds: observation.boundingBox
                )
            } else {
                // Traditional barcode validation
                guard barcodeString.count >= 8,
                      isValidBarcodeFormat(barcodeString)
                else {
                    print("🔍 Invalid traditional barcode format: '\(barcodeString)'")
                    return nil
                }

                return BarcodeScanResult(
                    barcodeString: barcodeString,
                    barcodeType: observation.symbology,
                    confidence: observation.confidence,
                    bounds: observation.boundingBox
                )
            }
        }

        // Prioritize traditional barcodes over QR codes when both are present
        UserDefaults.standard.barcodeSearchProvider = .openFoodFacts

        let bestBarcode = selectBestBarcode(from: validBarcodes)
        guard let selectedBarcode = bestBarcode else {
            return
        }

        // Enhanced validation - only proceed with high-confidence detections
        let minimumConfidence: Float = selectedBarcode.barcodeType == .qr ? 0.6 : 0.8
        guard selectedBarcode.confidence >= minimumConfidence else {
            print("🔍 Barcode confidence too low: \(selectedBarcode.confidence) < \(minimumConfidence)")
            return
        }

        // Ensure barcode string is valid and not empty
        guard !selectedBarcode.barcodeString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("🔍 Empty or whitespace-only barcode string detected")
            return
        }

        // Check for duplicates
        guard !recentlyScannedBarcodes.contains(selectedBarcode.barcodeString) else {
            print("🔍 Skipping duplicate barcode: \(selectedBarcode.barcodeString)")
            return
        }

        // Mark as processing to prevent duplicates
        isProcessingScan = true

        print(
            "🔍 ✅ Valid barcode detected: \(selectedBarcode.barcodeString) (confidence: \(selectedBarcode.confidence), minimum: \(minimumConfidence))"
        )

        // Add to recent scans to prevent duplicates
        recentlyScannedBarcodes.insert(selectedBarcode.barcodeString)

        // Publish result on main queue
        DispatchQueue.global().async { [weak self] in
            self?.lastScanResult = selectedBarcode

            // Reset processing flag after a brief delay
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                self?.isProcessingScan = false
            }

            // Clear recently scanned after a longer delay to allow for duplicate detection
            self?.duplicatePreventionTimer?.invalidate()
            self?.duplicatePreventionTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                self?.recentlyScannedBarcodes.removeAll()
                print("🔍 Cleared recently scanned barcodes cache")
            }

            os_log(
                "Barcode detected: %{public}@ (confidence: %.2f)",

                log: self?.log ?? OSLog.disabled,

                type: .info,

                selectedBarcode.barcodeString,

                selectedBarcode.confidence
            )
        }
    }

    /// Validates barcode format to filter out false positives
    private func isValidBarcodeFormat(_ barcode: String) -> Bool {
        // Check for common barcode patterns
        let numericPattern = "^[0-9]+$"
        let alphanumericPattern = "^[A-Z0-9]+$"

        // EAN-13, UPC-A: 12-13 digits
        if barcode.count == 12 || barcode.count == 13 {
            return barcode.range(of: numericPattern, options: .regularExpression) != nil
        }

        // EAN-8, UPC-E: 8 digits
        if barcode.count == 8 {
            return barcode.range(of: numericPattern, options: .regularExpression) != nil
        }

        // Code 128, Code 39: Variable length alphanumeric
        if barcode.count >= 8, barcode.count <= 40 {
            return barcode.range(of: alphanumericPattern, options: .regularExpression) != nil
        }

        // QR codes: Handle various data formats
        if barcode.count >= 10 {
            return isValidQRCodeData(barcode)
        }

        return false
    }

    /// Validates QR code data and extracts product identifiers if present
    private func isValidQRCodeData(_ qrData: String) -> Bool {
        // URL format QR codes (common for food products)
        if qrData.hasPrefix("http://") || qrData.hasPrefix("https://") {
            return URL(string: qrData) != nil
        }

        // JSON format QR codes
        if qrData.hasPrefix("{"), qrData.hasSuffix("}") {
            // Try to parse as JSON to validate structure
            if let data = qrData.data(using: .utf8),
               let _ = try? JSONSerialization.jsonObject(with: data)
            {
                return true
            }
        }

        // Product identifier formats (various standards)
        // GTIN format: (01)12345678901234
        if qrData.contains("(01)") {
            return true
        }

        // UPC/EAN codes within QR data
        let numericOnlyPattern = "^[0-9]+$"
        if qrData.range(of: numericOnlyPattern, options: .regularExpression) != nil {
            return qrData.count >= 8 && qrData.count <= 14
        }

        // Allow other structured data formats
        if qrData.count <= 500 { // Reasonable size limit for food product QR codes
            return true
        }

        return false
    }

    /// Select the best barcode from detected options, prioritizing traditional barcodes over QR codes
    private func selectBestBarcode(from barcodes: [BarcodeScanResult]) -> BarcodeScanResult? {
        guard !barcodes.isEmpty else { return nil }

        // Separate traditional barcodes from QR codes
        let traditionalBarcodes = barcodes.filter { result in
            result.barcodeType != .qr && result.barcodeType != .dataMatrix
        }
        let qrCodes = barcodes.filter { result in
            result.barcodeType == .qr || result.barcodeType == .dataMatrix
        }

        // If we have traditional barcodes, pick the one with highest confidence
        if !traditionalBarcodes.isEmpty {
            let bestTraditional = traditionalBarcodes.max { $0.confidence < $1.confidence }!
            print(
                "🔍 Prioritizing traditional barcode: \(bestTraditional.barcodeString) (confidence: \(bestTraditional.confidence))"
            )
            return bestTraditional
        }

        // Only use QR codes if no traditional barcodes are present
        if !qrCodes.isEmpty {
            let bestQR = qrCodes.max { $0.confidence < $1.confidence }!
            print("🔍 Using QR code (no traditional barcode found): \(bestQR.barcodeString) (confidence: \(bestQR.confidence))")

            // Check if QR code is actually food-related
            if isNonFoodQRCode(bestQR.barcodeString) {
                print("🔍 Rejecting non-food QR code")
                // We could show a specific error here, but for now we'll just return nil
                DispatchQueue.global().async {
                    self.scanError = BarcodeScanError
                        .scanningFailed("This QR code is not a food product code and cannot be scanned")
                }
                return nil
            }

            return bestQR
        }

        return nil
    }

    /// Check if a QR code is a non-food QR code (e.g., pointing to a website)
    private func isNonFoodQRCode(_ qrData: String) -> Bool {
        // Check if it's just a URL without any product identifier
        if qrData.hasPrefix("http://") || qrData.hasPrefix("https://") {
            // If we can't extract a product identifier from the URL, it's likely non-food
            return extractProductIdentifier(from: qrData) == nil
        }

        // Check for common non-food QR code patterns
        let nonFoodPatterns = [
            "mailto:",
            "tel:",
            "sms:",
            "wifi:",
            "geo:",
            "contact:",
            "vcard:",
            "youtube.com",
            "instagram.com",
            "facebook.com",
            "twitter.com",
            "linkedin.com"
        ]

        let lowerQRData = qrData.lowercased()
        for pattern in nonFoodPatterns {
            if lowerQRData.contains(pattern) {
                return true
            }
        }

        return false
    }

    /// Extracts a usable product identifier from QR code data
    private func extractProductIdentifier(from qrData: String) -> String? {
        print("🔍 Extracting product ID from QR data: '\(qrData.prefix(200))'")

        // If it's already a simple barcode, return as-is
        let numericPattern = "^[0-9]+$"
        if qrData.range(of: numericPattern, options: .regularExpression) != nil,
           qrData.count >= 8, qrData.count <= 14
        {
            print("🔍 Found direct numeric barcode: '\(qrData)'")
            return qrData
        }

        // Extract from GTIN format: (01)12345678901234
        if qrData.contains("(01)") {
            let gtinPattern = "\\(01\\)([0-9]{12,14})"
            if let regex = try? NSRegularExpression(pattern: gtinPattern),
               let match = regex.firstMatch(in: qrData, range: NSRange(qrData.startIndex..., in: qrData)),
               let gtinRange = Range(match.range(at: 1), in: qrData)
            {
                let gtin = String(qrData[gtinRange])
                print("🔍 Extracted GTIN: '\(gtin)'")
                return gtin
            }
        }

        // Extract from URL path (e.g., https://example.com/product/1234567890123)
        if let url = URL(string: qrData) {
            print("🔍 Processing URL: '\(url.absoluteString)'")
            let pathComponents = url.pathComponents
            for component in pathComponents.reversed() {
                if component.range(of: numericPattern, options: .regularExpression) != nil,
                   component.count >= 8, component.count <= 14
                {
                    print("🔍 Extracted from URL path: '\(component)'")
                    return component
                }
            }

            // Check URL query parameters for product IDs
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems
            {
                let productIdKeys = ["id", "product_id", "gtin", "upc", "ean", "barcode"]
                for queryItem in queryItems {
                    if productIdKeys.contains(queryItem.name.lowercased()),
                       let value = queryItem.value,
                       value.range(of: numericPattern, options: .regularExpression) != nil,
                       value.count >= 8, value.count <= 14
                    {
                        print("🔍 Extracted from URL query: '\(value)'")
                        return value
                    }
                }
            }
        }

        // Extract from JSON (look for common product ID fields)
        if qrData.hasPrefix("{"), qrData.hasSuffix("}"),
           let data = qrData.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            print("🔍 Processing JSON QR code")
            // Common field names for product identifiers
            let idFields = ["gtin", "upc", "ean", "barcode", "product_id", "id", "code", "productId"]
            for field in idFields {
                if let value = json[field] as? String,
                   value.range(of: numericPattern, options: .regularExpression) != nil,
                   value.count >= 8, value.count <= 14
                {
                    print("🔍 Extracted from JSON field '\(field)': '\(value)'")
                    return value
                }
                // Also check for numeric values
                if let numValue = json[field] as? NSNumber {
                    let stringValue = numValue.stringValue
                    if stringValue.count >= 8, stringValue.count <= 14 {
                        print("🔍 Extracted from JSON numeric field '\(field)': '\(stringValue)'")
                        return stringValue
                    }
                }
            }
        }

        // Look for embedded barcodes in any text (more flexible extraction)
        let embeddedBarcodePattern = "([0-9]{8,14})"
        if let regex = try? NSRegularExpression(pattern: embeddedBarcodePattern),
           let match = regex.firstMatch(in: qrData, range: NSRange(qrData.startIndex..., in: qrData)),
           let barcodeRange = Range(match.range(at: 1), in: qrData)
        {
            let extractedBarcode = String(qrData[barcodeRange])
            print("🔍 Found embedded barcode: '\(extractedBarcode)'")
            return extractedBarcode
        }

        // If QR code is short enough, try using it directly as a product identifier
        if qrData.count <= 50, !qrData.contains(" "), !qrData.contains("http") {
            print("🔍 Using short QR data directly: '\(qrData)'")
            return qrData
        }

        print("🔍 No product identifier found, returning nil")
        return nil
    }

    // MARK: - Session Health Monitoring

    /// Set focus point for the camera
    private func setFocusPoint(_ point: CGPoint) {
        guard let device = captureSession.inputs.first as? AVCaptureDeviceInput else {
            print("🔍 No camera device available for focus")
            return
        }

        let cameraDevice = device.device

        do {
            try cameraDevice.lockForConfiguration()

            // Set focus point if supported
            if cameraDevice.isFocusPointOfInterestSupported {
                cameraDevice.focusPointOfInterest = point
                print("🔍 Set focus point to: \(point)")
            }

            // Set autofocus mode
            if cameraDevice.isFocusModeSupported(.autoFocus) {
                cameraDevice.focusMode = .autoFocus
                print("🔍 Triggered autofocus at point: \(point)")
            }

            // Set exposure point if supported
            if cameraDevice.isExposurePointOfInterestSupported {
                cameraDevice.exposurePointOfInterest = point
                print("🔍 Set exposure point to: \(point)")
            }

            // Set exposure mode
            if cameraDevice.isExposureModeSupported(.autoExpose) {
                cameraDevice.exposureMode = .autoExpose
                print("🔍 Set auto exposure at point: \(point)")
            }

            cameraDevice.unlockForConfiguration()

        } catch {
            print("🔍 Error setting focus point: \(error)")
        }
    }

    /// Start monitoring session health
    private func startSessionHealthMonitoring() {
        print("🎥 Starting session health monitoring")
        lastValidFrameTime = Date()

        sessionHealthTimer?.invalidate()
        sessionHealthTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkSessionHealth()
        }
    }

    /// Stop session health monitoring
    private func stopSessionHealthMonitoring() {
        print("🎥 Stopping session health monitoring")
        sessionHealthTimer?.invalidate()
        sessionHealthTimer = nil
    }

    /// Check if the session is healthy
    private func checkSessionHealth() {
        let timeSinceLastFrame = Date().timeIntervalSince(lastValidFrameTime)

        print("🎥 Health check - seconds since last frame: \(timeSinceLastFrame)")

        // If no frames for more than 10 seconds, session may be stalled
        if timeSinceLastFrame > 10.0, captureSession.isRunning, isScanning {
            print("🎥 ⚠️ Session appears stalled - no frames for \(timeSinceLastFrame) seconds")

            // Attempt to restart the session
            sessionQueue.async { [weak self] in
                guard let self = self else { return }

                print("🎥 Attempting session restart due to stall...")

                // Stop and restart
                self.captureSession.stopRunning()
                Thread.sleep(forTimeInterval: 0.5)

                if !self.captureSession.isInterrupted {
                    self.captureSession.startRunning()
                    self.lastValidFrameTime = Date()
                    print("🎥 Session restarted after stall")
                } else {
                    print("🎥 Cannot restart - session is interrupted")
                }
            }
        }

        // Check session state
        if !captureSession.isRunning, isScanning {
            print("🎥 ⚠️ Session stopped but still marked as scanning")
            DispatchQueue.global().async {
                self.isScanning = false
                self.scanError = BarcodeScanError.sessionSetupFailed
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension BarcodeScannerService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection) {
        // Skip processing if already processing a scan or not actively scanning
        guard isScanning, !isProcessingScan else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("🔍 Failed to get pixel buffer from sample")
            return
        }

        // Throttle processing to improve performance - process every 3rd frame
        guard arc4random_uniform(3) == 0 else { return }

        // Update frame time for health monitoring
        lastValidFrameTime = Date()

        // Determine image orientation based on device orientation
        let deviceOrientation = UIDevice.current.orientation
        let imageOrientation: CGImagePropertyOrientation

        switch deviceOrientation {
        case .portrait:
            imageOrientation = .right
        case .portraitUpsideDown:
            imageOrientation = .left
        case .landscapeLeft:
            imageOrientation = .up
        case .landscapeRight:
            imageOrientation = .down
        default:
            imageOrientation = .right
        }

        let imageRequestHandler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: imageOrientation,
            options: [:]
        )

        do {
            try imageRequestHandler.perform([barcodeRequest])
        } catch {
            os_log("Vision request failed: %{public}@", log: log, type: .error, error.localizedDescription)
            print("🔍 Vision request error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Testing Support

#if DEBUG
    extension BarcodeScannerService {
        /// Create a mock scanner for testing
        static func mock() -> BarcodeScannerService {
            let scanner = BarcodeScannerService()
            scanner.cameraAuthorizationStatus = .authorized
            return scanner
        }

        /// Simulate a successful barcode scan for testing
        func simulateScan(barcode: String) {
            let result = BarcodeScanResult.sample(barcode: barcode)
            DispatchQueue.global().async {
                self.lastScanResult = result
                self.isScanning = false
            }
        }

        /// Simulate a scan error for testing
        func simulateError(_ error: BarcodeScanError) {
            DispatchQueue.global().async {
                self.scanError = error
                self.isScanning = false
            }
        }
    }
#endif
