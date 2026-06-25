import SwiftUI

/// The widgets that can appear in the expanded notch. Add a case here and a
/// view in Widgets.swift to grow the surface.
enum WidgetKind: String, CaseIterable, Identifiable, Codable {
    case clock
    case battery
    case activity
    case shelf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clock: return "Clock"
        case .battery: return "Battery"
        case .activity: return "Activity"
        case .shelf: return "Shelf"
        }
    }

    var systemImage: String {
        switch self {
        case .clock: return "clock"
        case .battery: return "battery.100"
        case .activity: return "waveform.path.ecg"
        case .shelf: return "tray.full"
        }
    }

    var blurb: String {
        switch self {
        case .clock: return "Time and date at a glance."
        case .battery: return "Charge level and power state."
        case .activity: return "Live tasks from Claude Code & other tools."
        case .shelf: return "Drag files onto the notch to stash them."
        }
    }
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
            // Sensible defaults on first run.
            enabled = [.clock, .battery, .activity, .shelf]
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
