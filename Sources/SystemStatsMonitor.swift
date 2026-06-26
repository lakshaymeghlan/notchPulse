import Foundation
import Darwin

/// Samples CPU and memory usage on a timer and keeps a short rolling history for
/// sparkline graphs. Public mach APIs only.
@MainActor
final class SystemStatsMonitor: ObservableObject {
    @Published private(set) var cpu: Double = 0          // 0...1
    @Published private(set) var memory: Double = 0       // 0...1 (used / total)
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var memHistory: [Double] = []

    private let maxSamples = 40
    private var timer: Timer?
    private var prevCPUTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?
    private let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)

    func start() {
        guard timer == nil else { return }
        sample()
        let t = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        t.tolerance = 0.3
        timer = t
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func sample() {
        cpu = readCPU()
        memory = readMemory()
        push(&cpuHistory, cpu)
        push(&memHistory, memory)
    }

    private func push(_ arr: inout [Double], _ v: Double) {
        arr.append(v)
        if arr.count > maxSamples { arr.removeFirst(arr.count - maxSamples) }
    }

    private func readCPU() -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return cpu }

        let user = info.cpu_ticks.0, system = info.cpu_ticks.1, idle = info.cpu_ticks.2, nice = info.cpu_ticks.3
        defer { prevCPUTicks = (user, system, idle, nice) }
        guard let prev = prevCPUTicks else { return 0 }

        let du = Double(user &- prev.user)
        let ds = Double(system &- prev.system)
        let di = Double(idle &- prev.idle)
        let dn = Double(nice &- prev.nice)
        let total = du + ds + di + dn
        guard total > 0 else { return cpu }
        return min(1, max(0, (du + ds + dn) / total))
    }

    private func readMemory() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS, totalMemory > 0 else { return memory }
        let page = Double(vm_kernel_page_size)
        let used = (Double(stats.active_count) + Double(stats.wire_count) + Double(stats.compressor_page_count)) * page
        return min(1, max(0, used / totalMemory))
    }
}
