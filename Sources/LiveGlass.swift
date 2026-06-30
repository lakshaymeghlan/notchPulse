import SwiftUI
import ScreenCaptureKit
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreMedia
import CoreVideo

/// Phase 3 — "Live Glass": capture the screen region behind the notch with
/// ScreenCaptureKit, blur it, and show it as the panel background. Opt-in.
///
/// - Excludes our own app from the capture (no feedback loop).
/// - Throttled to 15fps, captured at half size (then blurred), so it's cheap.
/// - Started only while the view is on-screen (notch expanded) and stopped on
///   disappear, so it isn't running while collapsed.
/// - Needs the Screen Recording permission (the system shows a recurring prompt).
final class LiveGlassEngine: NSObject, ObservableObject, SCStreamOutput {
    @Published var frame: CGImage?

    private var stream: SCStream?
    private var starting = false
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let sampleQueue = DispatchQueue(label: "io.notchpulse.liveglass")

    func start() {
        guard stream == nil, !starting else { return }
        starting = true
        // Surface the Screen Recording prompt / add us to the list.
        CGRequestScreenCaptureAccess()
        Task { await begin() }
    }

    func stop() {
        starting = false
        stream?.stopCapture { _ in }
        stream = nil
    }

    private func begin() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else { starting = false; return }

            // Exclude our own app so the glass never captures itself.
            let mine = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
            let filter = SCContentFilter(display: display, excludingApplications: mine, exceptingWindows: [])

            let cfg = SCStreamConfiguration()
            // Just the top-center strip behind the expanded panel.
            let w = Int(NotchMetrics.expandedWidth)
            let h = Int(NotchMetrics.expandedHeight) + 70
            cfg.sourceRect = CGRect(x: (display.width - w) / 2, y: 0, width: w, height: h)
            cfg.width = max(2, w / 2)
            cfg.height = max(2, h / 2)
            cfg.minimumFrameInterval = CMTime(value: 1, timescale: 15)
            cfg.pixelFormat = kCVPixelFormatType_32BGRA
            cfg.queueDepth = 3
            cfg.showsCursor = false

            let stream = SCStream(filter: filter, configuration: cfg, delegate: nil)
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
            try await stream.startCapture()
            self.stream = stream
        } catch {
            NSLog("[NotchPulse] LiveGlass failed: \(error.localizedDescription)")
            starting = false
        }
    }

    // SCStreamOutput — called on `sampleQueue`.
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              sampleBuffer.isValid,
              let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let source = CIImage(cvPixelBuffer: pixel)
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = source.clampedToExtent()
        blur.radius = 22
        guard let blurred = blur.outputImage?.cropped(to: source.extent),
              let cg = ciContext.createCGImage(blurred, from: source.extent) else { return }

        DispatchQueue.main.async { [weak self] in self?.frame = cg }
    }
}

/// SwiftUI view that renders the live blurred capture, with a dark scrim so
/// foreground text stays readable. Falls back to a dark fill until the first
/// frame (or if permission is denied).
struct LiveGlassView: View {
    @StateObject private var engine = LiveGlassEngine()

    var body: some View {
        ZStack {
            if let cg = engine.frame {
                Image(decorative: cg, scale: 1, orientation: .up)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                LinearGradient(colors: [GlassStyle.topTint, GlassStyle.bottomTint],
                               startPoint: .top, endPoint: .bottom)
            }
            // Legibility scrim over the live blur.
            Color.black.opacity(0.28)
        }
        .animation(.easeOut(duration: 0.25), value: engine.frame != nil)
        .onAppear { engine.start() }
        .onDisappear { engine.stop() }
    }
}
