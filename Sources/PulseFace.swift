import SwiftUI

/// NotchPulse's mascot — a tiny living companion that reacts to what's happening
/// on your Mac, not just to agents. It naps while an agent runs, wakes with a
/// start when it finishes, throws on sunglasses while music plays, and idly
/// looks around when nothing's going on. The same view is reused collapsed (in
/// the notch ear) and expanded (in the dashboard bar); a `matchedGeometryEffect`
/// flies it between the two as the panel opens.
struct PulseFace: View {
    enum Mood: Equatable { case idle, sleeping, working, happy, sad, vibing }

    let mood: Mood
    var size: CGFloat = 22
    /// 0…1 — how hard the user is typing; drives the "working" nod depth.
    var intensity: Double = 0

    @State private var breathe = false
    @State private var gaze: CGFloat = 0     // -1…1 idle look-around
    @State private var pop: CGFloat = 1      // startle "wake up" bounce

    /// Face tint per mood — a calm periwinkle nap, party purple vibe, etc.
    private var tint: Color {
        switch mood {
        case .idle:     return Color(white: 0.84)
        case .sleeping: return Color(red: 0.52, green: 0.60, blue: 0.95)   // calm night blue
        case .working:  return Color(red: 0.36, green: 0.72, blue: 0.98)   // focused sky blue
        case .happy:    return Color(red: 0.30, green: 0.85, blue: 0.45)
        case .sad:      return Color(red: 1.00, green: 0.34, blue: 0.34)
        case .vibing:   return Color(red: 0.72, green: 0.42, blue: 0.98)   // party purple
        }
    }

    private var eyeStyle: EyePair.Style {
        switch mood {
        case .sleeping: return .closed
        case .working:  return .focused
        case .happy:    return .wide
        case .sad:      return .droopy
        case .idle, .vibing: return .open
        }
    }

    /// Mouth bend: +1 smile, 0 flat, -1 frown.
    private var mouthCurve: CGFloat {
        switch mood {
        case .happy:    return 1
        case .sad:      return -1
        case .vibing:   return 0.7
        case .working:  return 0.0        // lips pressed in concentration
        case .sleeping: return 0.05
        case .idle:     return 0.15
        }
    }

    // Bob (rhythmic nod): music sways gently; working nods to your typing speed.
    private var bobActive: Bool { mood == .vibing || mood == .working }
    private var bobAmount: CGFloat {
        mood == .working ? size * (0.03 + 0.11 * CGFloat(intensity)) : size * 0.09
    }
    private var bobDuration: Double { mood == .working ? 0.22 : 0.42 }

    var body: some View {
        ZStack {
            // Soft aura that breathes and flares with mood.
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

            // Face features. Nods to music while vibing, to your keys while working.
            VStack(spacing: size * 0.12) {
                ZStack {
                    EyePair(style: eyeStyle, size: size, gaze: gaze)
                    if mood == .vibing { Sunglasses(size: size) }
                    if mood == .working { CoderGlasses(size: size) }
                }
                MouthShape(curve: mouthCurve)
                    .stroke(.black.opacity(0.78),
                            style: StrokeStyle(lineWidth: max(1.2, size * 0.085), lineCap: .round))
                    .frame(width: size * 0.44, height: size * 0.24)
            }
            .modifier(Bob(active: bobActive, amount: bobAmount, duration: bobDuration))

            // Sleepy "z z z" drifting up from the temple.
            if mood == .sleeping {
                SleepZs(size: size)
                    .offset(x: size * 0.55, y: -size * 0.55)
            }
        }
        .frame(width: size * 1.5, height: size * 1.5)
        .scaleEffect(pop)
        .compositingGroup()
        .animation(.spring(response: 0.34, dampingFraction: 0.55), value: mood)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                breathe = true
            }
            withAnimation(.easeInOut(duration: 3.1).repeatForever(autoreverses: true)) {
                gaze = 1
            }
        }
        .onChange(of: mood) { old, new in
            // Wake up with a start when an agent finishes mid-nap.
            if new == .happy && old == .sleeping {
                pop = 1.4
                withAnimation(.spring(response: 0.4, dampingFraction: 0.42)) { pop = 1 }
            }
        }
    }
}

// MARK: - Eyes

private struct EyePair: View {
    enum Style { case open, wide, closed, droopy, focused }
    let style: Style
    let size: CGFloat
    let gaze: CGFloat

    var body: some View {
        HStack(spacing: size * 0.26) { eye; eye }
            .offset(x: style == .open ? gaze * size * 0.06 : 0)
    }

    @ViewBuilder private var eye: some View {
        switch style {
        case .open:
            Capsule()
                .fill(.black.opacity(0.82))
                .frame(width: size * 0.13, height: size * 0.22)
                // Quick blink every ~2.7s, holding open between.
                .phaseAnimator([false, true]) { v, closed in
                    v.scaleEffect(y: closed ? 0.12 : 1, anchor: .center)
                } animation: { closed in
                    closed ? .easeIn(duration: 0.08).delay(2.6) : .easeOut(duration: 0.10)
                }
        case .wide:
            Circle()
                .fill(.black.opacity(0.86))
                .frame(width: size * 0.26, height: size * 0.26)
                .overlay(Circle().fill(.white).frame(width: size * 0.08, height: size * 0.08)
                    .offset(x: size * 0.05, y: -size * 0.05))
        case .closed:
            ClosedEye()
                .stroke(.black.opacity(0.8),
                        style: StrokeStyle(lineWidth: max(1.2, size * 0.09), lineCap: .round))
                .frame(width: size * 0.24, height: size * 0.12)
        case .droopy:
            Circle()
                .fill(.black.opacity(0.7))
                .frame(width: size * 0.14, height: size * 0.14)
                .offset(y: size * 0.05)
        case .focused:
            // Narrowed, determined eyes cast slightly downward at the "screen".
            Capsule()
                .fill(.black.opacity(0.82))
                .frame(width: size * 0.16, height: size * 0.11)
                .offset(y: size * 0.04)
        }
    }
}

/// A gentle downward curve — content, closed eyes (also used sleeping).
private struct ClosedEye: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY),
                       control: CGPoint(x: r.midX, y: r.maxY))
        return p
    }
}

// MARK: - Accessories

/// Two dark lenses + a bridge, with a diagonal glint — worn while music plays.
private struct Sunglasses: View {
    let size: CGFloat

    var body: some View {
        let lensW = size * 0.30, lensH = size * 0.26
        HStack(spacing: 0) {
            lens(lensW, lensH)
            Rectangle().fill(.black.opacity(0.85))
                .frame(width: size * 0.10, height: size * 0.03)
            lens(lensW, lensH)
        }
    }

    private func lens(_ w: CGFloat, _ h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: h * 0.4)
            .fill(.black.opacity(0.85))
            .frame(width: w, height: h)
            .overlay(
                RoundedRectangle(cornerRadius: h * 0.4)
                    .stroke(.white.opacity(0.35), lineWidth: 0.6))
            .overlay(
                Capsule().fill(.white.opacity(0.45))
                    .frame(width: w * 0.5, height: h * 0.12)
                    .rotationEffect(.degrees(-30))
                    .offset(x: -w * 0.12, y: -h * 0.12))
    }
}

/// Clear rounded frames — reading/coder glasses worn while you're working.
private struct CoderGlasses: View {
    let size: CGFloat

    var body: some View {
        let lensW = size * 0.30, lensH = size * 0.24
        HStack(spacing: 0) {
            lens(lensW, lensH)
            Rectangle().fill(.black.opacity(0.55)).frame(width: size * 0.10, height: size * 0.028)
            lens(lensW, lensH)
        }
    }

    private func lens(_ w: CGFloat, _ h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: h * 0.4)
            .fill(.cyan.opacity(0.14))
            .overlay(RoundedRectangle(cornerRadius: h * 0.4)
                .stroke(.black.opacity(0.6), lineWidth: max(1, size * 0.045)))
            .overlay(Capsule().fill(.white.opacity(0.4))
                .frame(width: w * 0.45, height: h * 0.1)
                .rotationEffect(.degrees(-28))
                .offset(x: -w * 0.1, y: -h * 0.14))
            .frame(width: w, height: h)
    }
}

/// Three sleepy "z"s drifting up and fading, staggered.
private struct SleepZs: View {
    let size: CGFloat
    @State private var go = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Text("z")
                    .font(.system(size: size * (0.30 + CGFloat(i) * 0.08), weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .offset(x: CGFloat(i) * size * 0.14, y: go ? -size * 0.5 : 0)
                    .opacity(go ? 0 : 0.9)
                    .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)
                        .delay(Double(i) * 0.5), value: go)
            }
        }
        .onAppear { go = true }
    }
}

/// A rhythmic vertical nod that runs only while `active`. `amount` sets depth
/// (updates live with typing intensity) and `duration` sets the beat.
private struct Bob: ViewModifier {
    let active: Bool
    let amount: CGFloat
    var duration: Double = 0.42
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .offset(y: active ? (up ? -amount : amount) : 0)
            .onAppear { if active { start() } }
            .onChange(of: active) { _, on in
                if on { start() } else { up = false }
            }
    }

    private func start() {
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            up = true
        }
    }
}

// MARK: - Mood resolution

extension PulseFace.Mood {
    /// Pick the mascot's mood from everything happening on the Mac, by priority:
    /// a problem (fail) > a win (success) > *you* working > a working agent (nap)
    /// > media (vibe) > nothing (idle).
    ///
    /// If you're actively coding while an agent runs, you pair-program — the
    /// mascot works with you rather than napping; pause and it dozes off.
    static func resolve(summary: ActivityStore.Summary,
                        mediaPlaying: Bool,
                        working: Bool) -> PulseFace.Mood {
        switch summary {
        case .failure: return .sad
        case .success: return .happy
        case .running: return working ? .working : .sleeping
        case .idle:
            if working { return .working }
            if mediaPlaying { return .vibing }
            return .idle
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
