import AVFoundation
import AppKit
import SwiftUI

/// Manages the camera capture session for the mirror widget. The session is
/// only started while the widget is actually visible (see CameraSection), and
/// permission is requested lazily on first start — never at launch.
@MainActor
final class CameraController: ObservableObject {
    let session = AVCaptureSession()

    enum Permission { case unknown, authorized, denied }
    /// User intent — off by default; the camera light never turns on until the
    /// user explicitly turns it on.
    @Published private(set) var isOn = false
    @Published private(set) var permission: Permission = .unknown

    private var visible = false
    private var configured = false
    private let sessionQueue = DispatchQueue(label: "io.notchpulse.camera")

    /// Turn the camera on/off (user action).
    func toggle() {
        isOn.toggle()
        if isOn, permission == .unknown {
            requestPermission()
        } else {
            apply()
        }
    }

    /// Section visibility (expanded + on screen). The session only runs while
    /// visible, so the camera releases when you collapse or switch pages.
    func setVisible(_ v: Bool) {
        guard visible != v else { return }
        visible = v
        apply()
    }

    private func requestPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permission = .authorized; apply()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.permission = granted ? .authorized : .denied
                    self.apply()
                }
            }
        default:
            permission = .denied
        }
    }

    private func apply() {
        if isOn, visible, permission == .authorized {
            configureAndRun()
        } else {
            stop()
        }
    }

    private func stop() {
        guard configured else { return }
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configureAndRun() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .high
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                    ?? AVCaptureDevice.default(for: .video)
                if let device,
                   let input = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                self.session.commitConfiguration()
                self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }
}

/// SwiftUI wrapper around an AVCaptureVideoPreviewLayer.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewNSView {
        let view = PreviewNSView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {
        nsView.previewLayer.session = session
    }

    final class PreviewNSView: NSView {
        let previewLayer = AVCaptureVideoPreviewLayer()
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer = CALayer()
            previewLayer.frame = bounds
            layer?.addSublayer(previewLayer)
        }
        required init?(coder: NSCoder) { fatalError() }
        override func layout() {
            super.layout()
            previewLayer.frame = bounds
            applyMirroring()
        }
        /// Mirror like a selfie — but ONLY after disabling auto-mirroring and
        /// only if the connection supports it. Setting `isVideoMirrored` while
        /// `automaticallyAdjustsVideoMirroring` is true throws an exception that,
        /// during a layout pass, crashes the whole app.
        private func applyMirroring() {
            guard let c = previewLayer.connection else { return }
            if c.automaticallyAdjustsVideoMirroring {
                c.automaticallyAdjustsVideoMirroring = false
            }
            if c.isVideoMirroringSupported, !c.isVideoMirrored {
                c.isVideoMirrored = true
            }
        }
    }
}
