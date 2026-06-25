import SwiftUI

/// The widgets that can appear in the expanded notch. Add a case here and a
/// view in Widgets.swift to grow the surface.
enum WidgetKind: String, CaseIterable, Identifiable, Codable {
    case clock
    case agent
    case battery
    case apps
    case windows
    case music
    case camera
    case teleprompter
    case calendar
    case shelf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clock: return "Clock"
        case .agent: return "Agent"
        case .battery: return "Battery"
        case .apps: return "Open Apps"
        case .windows: return "Open Windows"
        case .music: return "Music"
        case .camera: return "Camera"
        case .teleprompter: return "Teleprompter"
        case .calendar: return "Calendar"
        case .shelf: return "Shelf"
        }
    }

    var systemImage: String {
        switch self {
        case .clock: return "clock"
        case .agent: return "waveform.path.ecg"
        case .battery: return "battery.100"
        case .apps: return "square.grid.2x2"
        case .windows: return "macwindow.on.rectangle"
        case .music: return "music.note"
        case .camera: return "camera"
        case .teleprompter: return "text.alignleft"
        case .calendar: return "calendar"
        case .shelf: return "tray.full"
        }
    }

    var blurb: String {
        switch self {
        case .clock: return "Time and date at a glance."
        case .agent: return "Live tasks from Claude Code & other tools."
        case .battery: return "Charge level and power state."
        case .apps: return "Apps you currently have open — click to focus."
        case .windows: return "Open windows — click to bring one forward."
        case .music: return "Now playing in Spotify / Apple Music."
        case .camera: return "A live camera mirror (off until you turn it on)."
        case .teleprompter: return "Scroll a script while you look at the lens."
        case .calendar: return "Your next events (asks permission)."
        case .shelf: return "Drag files onto the notch to stash them."
        }
    }

    static var ordered: [WidgetKind] { [.clock, .calendar, .agent, .battery, .apps, .windows, .music, .teleprompter, .camera, .shelf] }
}

/// User's enabled widgets, persisted to UserDefaults. This is the "add a widget"
/// surface — toggles live in the Settings window.
@MainActor
final class WidgetSettings: ObservableObject {
    private let defaultsKey = "enabledWidgets"

    @Published var enabled: Set<WidgetKind> {
        didSet { persist() }
    }

    init() {
        if let raw = UserDefaults.standard.array(forKey: defaultsKey) as? [String] {
            enabled = Set(raw.compactMap(WidgetKind.init(rawValue:)))
        } else {
            // On by default. Calendar & Music only do work (and prompt for
            // permission) once their page is actually viewed; Camera stays off
            // until explicitly enabled.
            enabled = [.clock, .agent, .battery, .apps, .windows, .calendar, .music]
        }
    }

    func isOn(_ kind: WidgetKind) -> Bool { enabled.contains(kind) }

    func toggle(_ kind: WidgetKind) {
        if enabled.contains(kind) { enabled.remove(kind) } else { enabled.insert(kind) }
    }

    func binding(for kind: WidgetKind) -> Binding<Bool> {
        Binding(
            get: { self.enabled.contains(kind) },
            set: { isOn in
                if isOn { self.enabled.insert(kind) } else { self.enabled.remove(kind) }
            }
        )
    }

    private func persist() {
        UserDefaults.standard.set(enabled.map(\.rawValue), forKey: defaultsKey)
    }
}
