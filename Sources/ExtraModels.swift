import SwiftUI
import IOBluetooth
import ApplicationServices

// MARK: - To-Do

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var done = false
}

@MainActor
final class TodoModel: ObservableObject {
    @Published var items: [TodoItem] { didSet { persist() } }
    private let key = "notch.todos.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) {
            items = decoded
        } else {
            items = []
        }
    }

    func add(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        items.insert(TodoItem(text: t), at: 0)
    }
    func toggle(_ item: TodoItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].done.toggle()
    }
    func remove(_ item: TodoItem) { items.removeAll { $0.id == item.id } }
    func clearDone() { items.removeAll { $0.done } }

    var remaining: Int { items.filter { !$0.done }.count }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Notes (quick scratchpad)

@MainActor
final class NotesModel: ObservableObject {
    @Published var text: String { didSet { UserDefaults.standard.set(text, forKey: "notch.notes.v1") } }
    init() { text = UserDefaults.standard.string(forKey: "notch.notes.v1") ?? "" }
}

// MARK: - Keyboard shortcuts cheat-sheet

struct ShortcutItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var keys: String
    var label: String
}

@MainActor
final class ShortcutsModel: ObservableObject {
    @Published var items: [ShortcutItem] { didSet { persist() } }
    private let key = "notch.shortcuts.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ShortcutItem].self, from: data) {
            items = decoded
        } else {
            items = [
                ShortcutItem(keys: "⌥⌘N", label: "Open NotchPulse settings"),
                ShortcutItem(keys: "⌘⇧4", label: "Screenshot selection"),
                ShortcutItem(keys: "⌘Space", label: "Spotlight search"),
                ShortcutItem(keys: "⌃⌘Q", label: "Lock screen"),
                ShortcutItem(keys: "⌘`", label: "Cycle app windows"),
            ]
        }
    }

    func add(keys: String, label: String) {
        let k = keys.trimmingCharacters(in: .whitespaces)
        let l = label.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty, !l.isEmpty else { return }
        items.append(ShortcutItem(keys: k, label: l))
    }
    func remove(at offsets: IndexSet) { items.remove(atOffsets: offsets) }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Bluetooth devices

@MainActor
final class BluetoothMonitor: ObservableObject {
    struct Device: Identifiable {
        let id: String
        let name: String
        let connected: Bool
        let symbol: String
    }

    @Published private(set) var devices: [Device] = []
    private var timer: Timer?

    init() {
        refresh()
        let t = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        t.tolerance = 5
        timer = t
    }
    deinit { timer?.invalidate() }

    func refresh() {
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        devices = paired.map { d in
            let name = d.name ?? "Device"
            return Device(id: d.addressString ?? name,
                          name: name,
                          connected: d.isConnected(),
                          symbol: Self.symbol(for: name, classOfDevice: d.classOfDevice))
        }
        .sorted { ($0.connected ? 0 : 1, $0.name) < ($1.connected ? 0 : 1, $1.name) }
    }

    private static func symbol(for name: String, classOfDevice: BluetoothClassOfDevice) -> String {
        let n = name.lowercased()
        if n.contains("airpod") || n.contains("buds") || n.contains("headphone") || n.contains("pod") { return "airpodspro" }
        if n.contains("keyboard") || n.contains("magic key") { return "keyboard" }
        if n.contains("mouse") || n.contains("magic mouse") { return "magicmouse" }
        if n.contains("trackpad") { return "trackpad" }
        if n.contains("speaker") || n.contains("homepod") || n.contains("sound") { return "hifispeaker" }
        if n.contains("watch") { return "applewatch" }
        if n.contains("phone") || n.contains("iphone") { return "iphone" }
        return "dot.radiowaves.right"
    }
}

// MARK: - Window snap (needs Accessibility permission)

enum WindowSnap {
    enum Slot { case left, right, top, bottom, full, center }

    static var trusted: Bool { AXIsProcessTrusted() }

    /// Prompt for Accessibility access (shows the system dialog the first time).
    static func requestAccess() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    static func snap(_ slot: Slot) {
        guard trusted else { requestAccess(); return }
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let window = windowRef else { return }
        let axWindow = window as! AXUIElement

        // Visible frame of the screen under the menu bar / above the Dock.
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let full = screen.frame
        // AX uses top-left origin; Cocoa uses bottom-left. Convert.
        let topY = full.height - vf.maxY

        let target: CGRect
        switch slot {
        case .left:   target = CGRect(x: vf.minX, y: topY, width: vf.width / 2, height: vf.height)
        case .right:  target = CGRect(x: vf.minX + vf.width / 2, y: topY, width: vf.width / 2, height: vf.height)
        case .top:    target = CGRect(x: vf.minX, y: topY, width: vf.width, height: vf.height / 2)
        case .bottom: target = CGRect(x: vf.minX, y: topY + vf.height / 2, width: vf.width, height: vf.height / 2)
        case .full:   target = CGRect(x: vf.minX, y: topY, width: vf.width, height: vf.height)
        case .center:
            let w = vf.width * 0.6, h = vf.height * 0.7
            target = CGRect(x: vf.minX + (vf.width - w) / 2, y: topY + (vf.height - h) / 2, width: w, height: h)
        }

        var pos = target.origin
        var size = target.size
        if let posValue = AXValueCreate(.cgPoint, &pos) {
            AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, posValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)
        }
    }
}
