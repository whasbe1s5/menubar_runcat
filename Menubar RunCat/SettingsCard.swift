/*
 SettingsCard.swift
 Menubar RunCat
*/

import SwiftUI

struct SettingsCard: View {
    @ObservedObject var engine: RunnerEngine
    @Binding var showPercentage: Bool

    var body: some View {
        WidgetCard {
            VStack(spacing: 12) {
                // Runner type picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Runner")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Picker("Runner Type", selection: $engine.currentType) {
                        ForEach(RunnerType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    if engine.currentType == .neonCat {
                        HStack(spacing: 8) {
                            Text("Neon Color")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            ColorPicker("Neon Color", selection: Binding(
                                get: { Color(hex: engine.neonColorHex) ?? .pink },
                                set: { engine.neonColorHex = $0.toHex() ?? "#FF007F" }
                            ))
                            .labelsHidden()
                            .frame(width: 24, height: 24)
                        }
                    }
                }

                Divider()

                // Animation speed
                VStack(alignment: .leading, spacing: 4) {
                    Text("Animation Speed")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Image(systemName: "tortoise")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Slider(value: $engine.speedMultiplier, in: 0.1...4.0, step: 0.1)
                            .tint(.accentColor)
                        Image(systemName: "hare")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                Toggle(isOn: Binding(
                    get: { showPercentage },
                    set: { val in
                        showPercentage = val
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ToggleShowPercentage"),
                            object: nil
                        )
                    }
                )) {
                    Text("Show CPU in menu bar")
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .toggleStyle(.switch)

                Button(role: .destructive) {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "xmark.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
            }
        }
    }
}

// MARK: - Hex color helpers

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String? {
        guard let components = cgColor?.components, components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
