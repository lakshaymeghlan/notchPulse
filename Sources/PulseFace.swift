import SwiftUI

/// NotchPulse's mascot — a tiny living face that expresses the current agent
/// state. It blinks at rest, focuses (breathes) while an agent runs, grins on
/// success and winces on failure. The same view is reused collapsed (in the
/// notch ear) and expanded (in the dashboard bar); a `matchedGeometryEffect`
/// flies it between the two as the panel opens.
struct PulseFace: View {
    enum Mood: Equatable { case idle, thinking, happy, sad }

    let mood: Mood
    var size: CGFloat = 22

    @State private var breathe = false

    /// Face tint per mood. Running uses the same brand pink as the collapsed
    /// pulse dot so the language stays consistent.
    private var tint: Color {
        switch mood {
        case .idle:     return Color(white: 0.82)
        case .thinking: return Color(red: 1, green: 0.36, blue: 0.45)
        case .happy:    return Color(red: 0.30, green: 0.85, blue: 0.45)
        case .sad:      return Color(red: 1, green: 0.32, blue: 0.32)
        }
    }

    /// Mouth bend: +1 smile, 0 flat, -1 frown.
    private var mouthCurve: CGFloat {
        switch mood {
        case .happy:    return 1
        case .sad:      return -1
        case .thinking: return -0.12
        case .idle:     return 0.08
        }
    }

    var body: some View {
        ZStack {
            // Soft aura that breathes while alive and flares with mood.
            Circle()
                .fill(tint.opacity(0.30))
                .frame(width: size * 1.45, height: size * 1.45)
                .blur(radius: size * 0.30)
                .scaleEffect(breathe ? 1.12 : 0.9)
                .opacity(breathe ? 1 : 0.65)

            // The face disc — a soft top-lit orb.
            Circle()
                .fill(RadialGradient(
                    colors: [tint.opacity(0.98), tint.opacity(0.55)],
                    center: .init(x: 0.35, y: 0.3),
                    startRadius: 0, endRadius: size * 0.72))
                .overlay(Circle().stroke(.white.opacity(0.28), lineWidth: 0.6))
                .frame(width: size, height: size)

            // Eyes + mouth.
            VStack(spacing: size * 0.13) {
                HStack(spacing: size * 0.26) { eye; eye }
                    // A quick blink every ~2.7s, holding the eyes open between.
                    .phaseAnimator([false, true]) { eyes, closed in
                        eyes.scaleEffect(y: closed ? 0.12 : 1, anchor: .center)
                    } animation: { closed in
                        closed ? .easeIn(duration: 0.08).delay(2.6)
                               : .easeOut(duration: 0.10)
                    }

                MouthShape(curve: mouthCurve)
                    .stroke(.black.opacity(0.78),
                            style: StrokeStyle(lineWidth: max(1.2, size * 0.085), lineCap: .round))
                    .frame(width: size * 0.44, height: size * 0.24)
            }
        }
        .frame(width: size * 1.5, height: size * 1.5)
        .compositingGroup()
        .animation(.spring(response: 0.34, dampingFraction: 0.55), value: mood)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }

    private var eye: some View {
        Capsule()
            .fill(.black.opacity(0.80))
            .frame(width: size * 0.12, height: size * 0.20)
    }
}

extension PulseFace.Mood {
    init(summary: ActivityStore.Summary) {
        switch summary {
        case .idle:    self = .idle
        case .running: self = .thinking
        case .success: self = .happy
        case .failure: self = .sad
        }
    }
}

/// A mouth that morphs smoothly between a frown and a smile as `curve` animates.
struct MouthShape: Shape {
    var curve: CGFloat   // -1 frown … 0 flat … 1 smile
    var animatableData: CGFloat {
        get { curve }
        set { curve = newValue }
    }

    func path(in r: CGRect) -> Path {
        let bend = curve * r.height          // control-point depth (down = smile)
        let corner = curve * r.height * 0.25 // corners lift on a smile
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY - corner))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY - corner),
                       control: CGPoint(x: r.midX, y: r.midY + bend))
        return p
    }
}
