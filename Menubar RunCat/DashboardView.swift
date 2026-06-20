/*
 DashboardView.swift
 Menubar RunCat

 Inspired by Lume's clean, minimalist widget design.
*/

import SwiftUI
import Charts

// MARK: - Widget Card

struct WidgetCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(12).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.quaternary.opacity(0.4)))
    }
}

// MARK: - CPU Wide Card

struct CPUWideCard: View {
    let cpuUsage: Double
    let cpuHistory: [Double]
    let uptime: UptimeData
    let thermal: ProcessInfo.ThermalState

    private var cpuMin: Double { cpuHistory.min() ?? 0 }
    private var cpuMax: Double { cpuHistory.max() ?? 0 }

    var body: some View {
        WidgetCard {
            VStack(spacing: 0) {
                // Top: CPU percentage + chart
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .symbolRenderingMode(.hierarchical)
                            Text("CPU")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        HStack(alignment: .bottom, spacing: 4) {
                            Text(String(format: "%.0f", cpuUsage))
                                .font(.system(size: 36, weight: .light, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("%")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.bottom, 4)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(String(format: "%.0f", cpuMax))%")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Chart {
                            ForEach(Array(cpuHistory.enumerated()), id: \.offset) { index, value in
                                AreaMark(
                                    x: .value("t", index),
                                    y: .value("v", value)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.2), .blue.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                LineMark(
                                    x: .value("t", index),
                                    y: .value("v", value)
                                )
                                .lineStyle(StrokeStyle(lineWidth: 1.5))
                                .foregroundStyle(.blue)
                            }
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .chartYScale(domain: 0...100)
                        .frame(width: 120, height: 38)
                        Text("\(String(format: "%.0f", cpuMin))%")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }

                Divider()
                    .padding(.vertical, 4)

                // Bottom: uptime + thermal + time-scale
                HStack {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("Uptime:")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(uptime.formatted)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer()

                    Text("30s")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.trailing, 4)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(thermalColor)
                            .frame(width: 6, height: 6)
                        Text(thermalLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            .frame(height: 105)
        }
    }

    var thermalLabel: String {
        switch thermal {
        case .nominal:   return "Nominal"
        case .fair:      return "Fair"
        case .serious:   return "Serious"
        case .critical:  return "Critical"
        @unknown default: return "Unknown"
        }
    }

    var thermalColor: Color {
        switch thermal {
        case .nominal:  return .green
        case .fair:     return .yellow
        case .serious:  return .orange
        case .critical: return .red
        @unknown default: return .gray
        }
    }
}

struct MemoryGaugeCard: View {
    let used: UInt64
    let total: UInt64
    let fraction: Double
    let onBoost: () -> Void
    @State private var showBoostInfo = false

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                    Text("Memory")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    HStack(spacing: 2) {
                        Button(action: { showBoostInfo.toggle() }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showBoostInfo, arrowEdge: .bottom) {
                            Text("Allocates memory to flush compressed pages — helps free RAM under pressure.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(12)
                                .frame(width: 220)
                        }
                        Button(action: onBoost) {
                            Text("Boost")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.purple))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer()
                HStack {
                    Spacer()
                    Gauge(value: fraction) {
                        EmptyView()
                    } currentValueLabel: {
                        Text(String(format: "%.0f%%", fraction * 100))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(.purple)
                    Spacer()
                }
                .padding(.vertical, 4)
                Spacer()
                Text("\(ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .memory)) / \(ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .memory))")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(height: 106)
        }
    }
}

struct DiskGaugeCard: View {
    let used: UInt64
    let total: UInt64
    let fraction: Double

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                    Text("Disk")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer()
                HStack {
                    Spacer()
                    Gauge(value: fraction) {
                        EmptyView()
                    } currentValueLabel: {
                        Text(String(format: "%.0f%%", fraction * 100))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(.orange)
                    Spacer()
                }
                .padding(.vertical, 4)
                Spacer()
                Text("\(ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file))")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(height: 106)
        }
    }
}

// MARK: - Network Card

struct NetworkCard: View {
    let downloadBytes: UInt64
    let uploadBytes: UInt64

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "network")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                    Text("Network")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer()
                speedRow(icon: "arrow.down", label: "Download", bps: downloadBytes, color: .blue)
                Spacer()
                speedRow(icon: "arrow.up", label: "Upload", bps: uploadBytes, color: .green)
            }
            .frame(height: 86)
        }
    }

    func speedRow(icon: String, label: String, bps: UInt64, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Text(formatSpeed(bps))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    func formatSpeed(_ bps: UInt64) -> String {
        if bps == 0 { return "0 KB/s" }
        return ByteCountFormatter.string(fromByteCount: Int64(bps), countStyle: .file) + "/s"
    }
}

// MARK: - Battery Card

struct BatteryCard: View {
    let data: BatteryData

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: data.isCharging ? "battery.100.bolt" : batteryIcon(for: data.percentage))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(batteryColor)
                        .symbolRenderingMode(.hierarchical)
                    Text("Battery")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    if data.isCharging {
                        Text("Charging")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.green)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.15), in: Capsule())
                    }
                }
                Spacer()
                if data.isPresent {
                    HStack(alignment: .bottom, spacing: 2) {
                        Text(String(format: "%.0f", data.percentage))
                            .font(.system(size: 32, weight: .light, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("%")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.bottom, 4)
                    }
                } else {
                    Text("No battery")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(height: 86)
        }
    }

    var batteryColor: Color {
        guard data.isPresent else { return .secondary }
        if data.isCharging { return .green }
        if data.percentage <= 10 { return .red }
        if data.percentage <= 20 { return .orange }
        return .secondary
    }

    func batteryIcon(for pct: Double) -> String {
        switch pct {
        case 0..<5:   return "battery.0"
        case 5..<35:  return "battery.25"
        case 35..<60: return "battery.50"
        case 60..<85: return "battery.75"
        default:      return "battery.100"
        }
    }
}


struct CleanerCard: View {
    let data: CleanerData
    let onClean: () -> Void
    @State private var showCleanConfirmation = false

    var body: some View {
        WidgetCard {
            HStack(spacing: 12) {
                // Left side: header + size + breakdown
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.blue, .indigo)
                            .symbolRenderingMode(.hierarchical)
                        Text("Mac Cleaner")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    if data.isScanning || data.isCleaning {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text(data.isScanning ? "Scanning..." : "Cleaning...")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(formattedSize)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text("Junk Files")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                            if data.totalReclaimable > 0 {
                                Text(breakdown)
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                    }
                }

                Spacer()

                // Right side: Clean button
                Button(action: { showCleanConfirmation = true }) {
                    Text("Clean")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(data.totalReclaimable > 0 ? .white : .white.opacity(0.3))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(data.totalReclaimable > 0
                                    ? LinearGradient(colors: [.blue, .indigo], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(data.totalReclaimable == 0)
            }
            .frame(height: data.totalReclaimable > 0 ? 74 : 62)
        }
        .alert("Clean junk files?", isPresented: $showCleanConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) { onClean() }
        } message: {
            Text("This will empty Trash, clear system caches, logs, and Xcode DerivedData. This action cannot be undone.")
        }
    }

    private var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: Int64(data.totalReclaimable))
    }

    private var breakdown: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        let trash = formatter.string(fromByteCount: Int64(data.trashSize))
        let caches = formatter.string(fromByteCount: Int64(data.cachesSize))
        let logs = formatter.string(fromByteCount: Int64(data.logsSize))
        return "Trash: \(trash)  ·  Caches: \(caches)  ·  Logs: \(logs)"
    }
}

// MARK: - Top Processes Card

struct TopProcessesCard: View {
    let cpuProcs: [ProcInfo]
    let memoryProcs: [ProcInfo]

    var body: some View {
        WidgetCard {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                        Text("Top CPU")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    ForEach(cpuProcs.prefix(3)) { proc in
                        HStack(spacing: 4) {
                            Text(proc.name)
                                .font(.system(size: 10))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .truncationMode(.tail)
                            Spacer()
                            Text(String(format: "%.1f", proc.cpuPercent))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("%")
                                .font(.system(size: 9, weight: .regular, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    if cpuProcs.prefix(3).isEmpty {
                        Text("Sampling...")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity)

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "memorychip.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                        Text("Top Memory")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    ForEach(memoryProcs.prefix(3)) { proc in
                        HStack(spacing: 4) {
                            Text(proc.name)
                                .font(.system(size: 10))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .truncationMode(.tail)
                            Spacer()
                            Text(formatMemory(proc.memoryBytes))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    if memoryProcs.prefix(3).isEmpty {
                        Text("Sampling...")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 86)
        }
    }

    func formatMemory(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useMB, .useGB]
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Dashboard View

public struct DashboardView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var cleaner: SystemCleaner
    @ObservedObject var engine: RunnerEngine
    @AppStorage("showPercentageInMenuBar") private var showPercentage = false

    public init(monitor: SystemMonitor, cleaner: SystemCleaner, engine: RunnerEngine) {
        self.monitor = monitor
        self.cleaner = cleaner
        self.engine = engine
    }

    public var body: some View {
        ScrollView {
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                // Row 1: CPU Wide (with uptime + thermal)
                GridRow {
                    CPUWideCard(
                        cpuUsage: monitor.currentCPU.value,
                        cpuHistory: monitor.cpuHistory,
                        uptime: monitor.currentUptime,
                        thermal: monitor.thermalPressure
                    )
                    .gridCellColumns(2)
                }

                // Row 2: Memory & Disk Gauges
                GridRow {
                    MemoryGaugeCard(
                        used: monitor.currentMemory.used,
                        total: monitor.currentMemory.total,
                        fraction: monitor.currentMemory.usedPercentage / 100.0,
                        onBoost: { monitor.releaseMemory() }
                    )
                    DiskGaugeCard(
                        used: monitor.currentDisk.used,
                        total: monitor.currentDisk.total,
                        fraction: monitor.currentDisk.usedPercentage / 100.0
                    )
                }

                // Row 3: Network & Battery
                GridRow {
                    NetworkCard(
                        downloadBytes: monitor.currentNetwork.downloadSpeedBytes,
                        uploadBytes: monitor.currentNetwork.uploadSpeedBytes
                    )
                    BatteryCard(data: monitor.currentBattery)
                }

                // Row 4: Cleaner Wide
                GridRow {
                    CleanerCard(
                        data: cleaner.cleanerData,
                        onClean: { cleaner.cleanJunk() }
                    )
                    .gridCellColumns(2)
                }

                // Row 5: Top Processes
                GridRow {
                    TopProcessesCard(
                        cpuProcs: monitor.topCPUProcs,
                        memoryProcs: monitor.topMemoryProcs
                    )
                    .gridCellColumns(2)
                }

                // Row 6: Settings Footer
                GridRow {
                    SettingsCard(engine: engine, showPercentage: $showPercentage)
                        .gridCellColumns(2)
                }
            }
            .padding(10)
        }
        .frame(width: 320)
    }

}
