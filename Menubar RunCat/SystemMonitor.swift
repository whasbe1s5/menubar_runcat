/*
 SystemMonitor.swift
 Menubar RunCat

 Created by Takuto Nakamura on 2026/06/16.
*/

import Foundation
import Darwin
import Combine
import IOKit.ps

// MARK: - Data Types

public struct CPUUsageData {
    public let value: Double
    public let description: String
}

public struct MemoryUsageData {
    public let used: UInt64
    public let total: UInt64
    public let free: UInt64
    public let active: UInt64
    public let wired: UInt64
    public let compressed: UInt64

    public var usedPercentage: Double {
        guard total > 0 else { return 0 }
        return min(Double(used) / Double(total) * 100.0, 100.0)
    }
}

public struct DiskUsageData {
    public let used: UInt64
    public let total: UInt64
    public let free: UInt64

    public var usedPercentage: Double {
        guard total > 0 else { return 0 }
        return min(Double(used) / Double(total) * 100.0, 100.0)
    }
}

public struct NetworkUsageData {
    public let downloadSpeedBytes: UInt64
    public let uploadSpeedBytes: UInt64
}

public struct BatteryData {
    public let percentage: Double
    public let isCharging: Bool
    public let isPresent: Bool
    public let timeRemaining: TimeInterval?
    public let cycleCount: Int?
    public let health: String?
}

public struct UptimeData {
    public let bootTime: Date
    public let uptime: TimeInterval

    public var formatted: String {
        let totalSeconds = Int(uptime)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

public struct ProcInfo: Identifiable {
    public let id: Int32
    public let name: String
    public let cpuPercent: Double
    public let memoryBytes: UInt64
}

public struct CleanerData {
    public let trashSize: UInt64
    public let cachesSize: UInt64
    public let logsSize: UInt64
    public let totalReclaimable: UInt64
    public let isCleaning: Bool
    public let isScanning: Bool
}

// MARK: - SystemMonitor

public final class SystemMonitor: ObservableObject {
    @Published var cpuHistory: [Double] = Array(repeating: 0.0, count: 30)
    @Published var currentCPU = CPUUsageData(value: 0.0, description: " 0.0% ")
    @Published var currentMemory = MemoryUsageData(used: 0, total: 1, free: 0, active: 0, wired: 0, compressed: 0)
    @Published var currentDisk = DiskUsageData(used: 0, total: 1, free: 0)
    @Published var currentNetwork = NetworkUsageData(downloadSpeedBytes: 0, uploadSpeedBytes: 0)
    @Published var currentBattery = BatteryData(percentage: 100, isCharging: false, isPresent: false, timeRemaining: nil, cycleCount: nil, health: nil)
    @Published var currentUptime = UptimeData(bootTime: Date(), uptime: 0)
    @Published var thermalPressure: ProcessInfo.ThermalState = .nominal
    @Published var topCPUProcs: [ProcInfo] = []
    @Published var topMemoryProcs: [ProcInfo] = []

    // These are accessed ONLY from the background queue (inside updateStats)
    private var prevProcTicks: [Int32: (user: UInt64, sys: UInt64)] = [:]
    private var procSampleCounter: Int = 0

    private let cpu = CPU()
    private var lastNetworkBytes: (ibytes: UInt64, obytes: UInt64)?
    private var lastNetworkTime = Date()

    private let queue = DispatchQueue(label: "com.kyome.Menubar-RunCat.stats", qos: .background)
    private var timer: DispatchSourceTimer?

    public init() {
        startMonitoring()
    }

    public func startMonitoring() {
        timer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: 1.0)
        t.setEventHandler { [weak self] in
            self?.updateStats()
        }
        t.resume()
        timer = t
    }

    public func stopMonitoring() {
        timer?.cancel()
        timer = nil
    }

    private func updateStats() {
        let cpuInfo = cpu.currentUsage()
        let cpuValue = cpuInfo.value
        let cpuDesc = cpuInfo.description
        let newMemory = getMemoryUsage()
        let newDisk = getDiskUsage()
        let newNetwork = getNetworkUsage()
        let newBattery = getBatteryInfo()
        let newUptime = getUptime()
        let newThermal = ProcessInfo.processInfo.thermalState

        procSampleCounter += 1
        let newTopProcs = sampleProcesses()

        let newCPU = CPUUsageData(value: cpuValue, description: cpuDesc)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentCPU = newCPU
            self.cpuHistory.removeFirst()
            self.cpuHistory.append(cpuValue)
            self.currentMemory = newMemory
            self.currentDisk = newDisk
            self.currentNetwork = newNetwork
            self.currentBattery = newBattery
            self.currentUptime = newUptime
            self.thermalPressure = newThermal
            if let (topCPU, topMemory) = newTopProcs {
                self.topCPUProcs = topCPU
                self.topMemoryProcs = topMemory
            }
        }
    }

    // MARK: - Process Sampling

    /// Returns nil when sampling is skipped (keeps existing published values).
    private func sampleProcesses() -> ([ProcInfo], [ProcInfo])? {
        guard procSampleCounter % 5 == 0 else { return nil }

        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return nil }

        let pids = UnsafeMutablePointer<pid_t>.allocate(capacity: Int(count))
        defer { pids.deallocate() }

        let written = proc_listallpids(pids, count)
        guard written > 0 else { return nil }

        var newTicks: [Int32: (user: UInt64, sys: UInt64)] = [:]
        var pidNames: [Int32: String] = [:]
        var pidResidency: [Int32: UInt64] = [:]

        // First pass: collect tick data for all PIDs
        let numPids = Int(written) / MemoryLayout<pid_t>.size
        for i in 0 ..< numPids {
            let pid = pids[i]

            var taskInfo = proc_taskinfo()
            let ret = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskinfo>.size))
            guard ret > 0 else { continue }

            var pathBuf = [CChar](repeating: 0, count: 4096)
            let pathLen = proc_pidpath(pid, &pathBuf, UInt32(pathBuf.count))
            guard pathLen > 0 else { continue }

            let path = String(cString: pathBuf)
            let name = (path as NSString).lastPathComponent

            newTicks[pid] = (user: taskInfo.pti_total_user, sys: taskInfo.pti_total_system)
            pidNames[pid] = name
            pidResidency[pid] = taskInfo.pti_resident_size
        }

        // Compute totalTicks across all PIDs (single denominator)
        var totalSystemTicks: UInt64 = 0
        for (pid, cur) in newTicks {
            if let prev = prevProcTicks[pid] {
                totalSystemTicks += (cur.user - prev.user) + (cur.sys - prev.sys)
            }
        }

        var currentCPUProcs: [ProcInfo] = []
        var currentMemoryProcs: [ProcInfo] = []

        // Second pass: compute per-process CPU%
        for (pid, cur) in newTicks {
            guard let name = pidNames[pid], let residency = pidResidency[pid] else { continue }

            let cpuPct: Double
            if let prev = prevProcTicks[pid], totalSystemTicks > 0 {
                let diff = (cur.user - prev.user) + (cur.sys - prev.sys)
                cpuPct = (Double(diff) / Double(totalSystemTicks)) * 100.0
            } else {
                cpuPct = 0
            }

            currentCPUProcs.append(ProcInfo(id: pid, name: name, cpuPercent: cpuPct, memoryBytes: residency))
            currentMemoryProcs.append(ProcInfo(id: pid, name: name, cpuPercent: cpuPct, memoryBytes: residency))
        }

        prevProcTicks = newTicks

        currentCPUProcs.sort { $0.cpuPercent > $1.cpuPercent }
        currentMemoryProcs.sort { $0.memoryBytes > $1.memoryBytes }

        return (Array(currentCPUProcs.prefix(5)), Array(currentMemoryProcs.prefix(5)))
    }

    // MARK: - Memory

    private func getMemoryUsage() -> MemoryUsageData {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kerr == KERN_SUCCESS else {
            return MemoryUsageData(used: 0, total: 1, free: 0, active: 0, wired: 0, compressed: 0)
        }

        let pageSize = vm_kernel_page_size
        let active = UInt64(stats.active_count) * UInt64(pageSize)
        let wired = UInt64(stats.wire_count) * UInt64(pageSize)
        let compressed = UInt64(stats.compressor_page_count) * UInt64(pageSize)
        let free = UInt64(stats.free_count) * UInt64(pageSize)
        let inactive = UInt64(stats.inactive_count) * UInt64(pageSize)

        let used = active + wired + compressed
        let total = ProcessInfo.processInfo.physicalMemory

        return MemoryUsageData(
            used: used,
            total: total,
            free: free + inactive,
            active: active,
            wired: wired,
            compressed: compressed
        )
    }

    // MARK: - Disk

    private func getDiskUsage() -> DiskUsageData {
        let fileURL = URL(fileURLWithPath: "/")
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            let total = UInt64(values.volumeTotalCapacity ?? 0)
            let free = UInt64(values.volumeAvailableCapacity ?? 0)
            let used = total > free ? total - free : 0
            return DiskUsageData(used: used, total: total, free: free)
        } catch {
            return DiskUsageData(used: 0, total: 1, free: 0)
        }
    }

    // MARK: - Network

    private func getNetworkUsage() -> NetworkUsageData {
        var ibytes: UInt64 = 0
        var obytes: UInt64 = 0
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else {
            return NetworkUsageData(downloadSpeedBytes: 0, uploadSpeedBytes: 0)
        }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            guard let interface = ptr?.pointee else { continue }
            let name = String(cString: interface.ifa_name)
            guard !name.hasPrefix("lo") else { continue }
            guard let data = interface.ifa_data else { continue }
            let ifData = data.assumingMemoryBound(to: if_data.self).pointee

            if interface.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                ibytes += UInt64(ifData.ifi_ibytes)
                obytes += UInt64(ifData.ifi_obytes)
            }
        }

        let now = Date()
        let timeDiff = now.timeIntervalSince(lastNetworkTime)
        lastNetworkTime = now

        guard let lastBytes = lastNetworkBytes, timeDiff > 0 else {
            lastNetworkBytes = (ibytes, obytes)
            return NetworkUsageData(downloadSpeedBytes: 0, uploadSpeedBytes: 0)
        }

        let downloadSpeed = timeDiff > 0 ? UInt64(Double(ibytes > lastBytes.ibytes ? ibytes - lastBytes.ibytes : 0) / timeDiff) : 0
        let uploadSpeed = timeDiff > 0 ? UInt64(Double(obytes > lastBytes.obytes ? obytes - lastBytes.obytes : 0) / timeDiff) : 0

        lastNetworkBytes = (ibytes, obytes)
        return NetworkUsageData(downloadSpeedBytes: downloadSpeed, uploadSpeedBytes: uploadSpeed)
    }

    // MARK: - Battery

    private func getBatteryInfo() -> BatteryData {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any]

        guard let sources = sources, !sources.isEmpty else {
            return BatteryData(percentage: 100, isCharging: false, isPresent: false, timeRemaining: nil, cycleCount: nil, health: nil)
        }

        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            let isPresent = (info[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType

            guard isPresent else { continue }

            let percentage = (info[kIOPSCurrentCapacityKey] as? Double) ?? 100.0
            let maxCapacity = (info[kIOPSMaxCapacityKey] as? Double) ?? 100.0
            let pct = maxCapacity > 0 ? (percentage / maxCapacity) * 100.0 : 100.0
            let isCharging = (info[kIOPSIsChargingKey] as? Bool) ?? false
            let timeRemaining = info[kIOPSTimeToEmptyKey] as? Int
            let cycleCount = info["CycleCount"] as? Int

            return BatteryData(
                percentage: pct,
                isCharging: isCharging,
                isPresent: true,
                timeRemaining: timeRemaining.map { TimeInterval($0) * 60.0 },
                cycleCount: cycleCount,
                health: nil
            )
        }

        return BatteryData(percentage: 100, isCharging: false, isPresent: false, timeRemaining: nil, cycleCount: nil, health: nil)
    }

    // MARK: - Uptime

    private func getUptime() -> UptimeData {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]

        let result = sysctl(&mib, u_int(mib.count), &boottime, &size, nil, 0)
        if result == 0 {
            let bootDate = Date(timeIntervalSince1970: TimeInterval(boottime.tv_sec))
            let uptime = Date().timeIntervalSince(bootDate)
            return UptimeData(bootTime: bootDate, uptime: uptime)
        }

        // Fallback: use process info uptime
        let uptime = ProcessInfo.processInfo.systemUptime
        let bootDate = Date().addingTimeInterval(-uptime)
        return UptimeData(bootTime: bootDate, uptime: uptime)
    }


    // MARK: - Memory Release

    public func releaseMemory() {
        queue.async { [weak self] in
            let size = 500 * 1024 * 1024
            let ptr = malloc(size)
            guard let ptr = ptr else { return }

            // Force physical allocation by touching each megabyte
            for i in stride(from: 0, to: size, by: 1024 * 1024) {
                ptr.advanced(by: i).assumingMemoryBound(to: UInt8.self).pointee = 0
            }

            Thread.sleep(forTimeInterval: 0.2)
            free(ptr)

            DispatchQueue.main.async { [weak self] in
                self?.updateStats()
            }
        }
    }
}
