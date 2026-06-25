import Foundation
import IOKit.ps
import Combine

/// Reads battery state via the public IOKit power-sources API. Polls on a timer
/// (cheap) — good enough for a glanceable widget.
@MainActor
final class BatteryMonitor: ObservableObject {
    @Published private(set) var level: Int = 100      // 0...100
    @Published private(set) var isCharging: Bool = false
    @Published private(set) var isPluggedIn: Bool = false
    @Published private(set) var isPresent: Bool = false

    private var timer: Timer?

    init() {
        update()
        // Light polling; battery doesn't change fast.
        let t = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
        t.tolerance = 5
        timer = t
    }

    deinit { timer?.invalidate() }

    func update() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            isPresent = false
            return
        }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
            else { continue }

            // Only consider the internal battery.
            let type = desc[kIOPSTypeKey] as? String
            guard type == kIOPSInternalBatteryType else { continue }

            isPresent = true
            if let cur = desc[kIOPSCurrentCapacityKey] as? Int,
               let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 {
                level = Int((Double(cur) / Double(max) * 100).rounded())
            }
            let state = desc[kIOPSPowerSourceStateKey] as? String
            isPluggedIn = (state == kIOPSACPowerValue)
            isCharging = (desc[kIOPSIsChargingKey] as? Bool) ?? false
            return
        }
        isPresent = false
    }

    /// SF Symbol name reflecting level + charging.
    var symbolName: String {
        if isCharging || isPluggedIn { return "battery.100.bolt" }
        switch level {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }
}
