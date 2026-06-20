/*
 RunnerEngine.swift
 Menubar RunCat

 Created by Takuto Nakamura on 2026/06/16.
*/

import Cocoa
import Combine

public enum RunnerType: String, CaseIterable, Codable {
    case cat = "Cat"
    case neonCat = "Neon Cat"
    case dog = "Dog"
    case rabbit = "Rabbit"
    case bird = "Bird"
    case humanoid = "Runner"
    case glitch = "Glitch"
}

@MainActor
public final class RunnerEngine: ObservableObject {
    @Published public var currentType: RunnerType = .cat {
        didSet {
            UserDefaults.standard.set(currentType.rawValue, forKey: "runnerType")
            updateFrames()
        }
    }
    
    @Published public var neonColorHex: String = "#FF007F" { // Neon Pink default
        didSet {
            UserDefaults.standard.set(neonColorHex, forKey: "neonColorHex")
            if currentType == .neonCat {
                updateFrames()
            }
        }
    }
    
    @Published public var speedMultiplier: Double = 0.5 {
        didSet {
            UserDefaults.standard.set(speedMultiplier, forKey: "speedMultiplier")
        }
    }
    
    private var frames: [NSImage] = []
    private var index: Int = 0
    private var interval: Double = 0.1
    private var runnerTimer: Timer?
    private let statusItem: NSStatusItem
    private var isRunning: Bool = false
    
    public init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
        
        // Load settings
        if let savedTypeRaw = UserDefaults.standard.string(forKey: "runnerType"),
           let savedType = RunnerType(rawValue: savedTypeRaw) {
            self.currentType = savedType
        }
        if let savedColor = UserDefaults.standard.string(forKey: "neonColorHex") {
            self.neonColorHex = savedColor
        }
        let savedMultiplier = UserDefaults.standard.double(forKey: "speedMultiplier")
        if savedMultiplier == 1.0 || savedMultiplier == 0.0 {
            self.speedMultiplier = 0.5
            UserDefaults.standard.set(0.5, forKey: "speedMultiplier")
        } else if savedMultiplier > 0 {
            self.speedMultiplier = savedMultiplier
        }
        
        updateFrames()
    }
    
    public func start() {
        isRunning = true
        scheduleTimer()
    }
    
    public func stop() {
        isRunning = false
        runnerTimer?.invalidate()
        runnerTimer = nil
    }
    
    public func updateSpeed(cpuUsage: Double) {
        // Base interval is 0.2s, decreases to 0.01s at 100% CPU.
        // Multiply by 1/speedMultiplier to scale speed.
        let baseInterval = 0.2 / max(1.0, min(25.0, cpuUsage / 4.0))
        interval = (baseInterval / speedMultiplier)
        
        if isRunning {
            scheduleTimer()
        }
    }
    
    private func scheduleTimer() {
        runnerTimer?.invalidate()
        runnerTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.nextFrame()
            }
        }
        RunLoop.main.add(runnerTimer!, forMode: .common)
    }
    
    private func nextFrame() {
        guard !frames.isEmpty else { return }
        index = (index + 1) % frames.count
        statusItem.button?.image = frames[index]
    }
    
    public func updateFrames() {
        let size = NSSize(width: 24, height: 16)
        
        switch currentType {
        case .cat:
            let bundle = Bundle(for: RunnerEngine.self)
            frames = (0 ..< 5).compactMap { n in
                let img = bundle.image(forResource: "cat_page\(n)")
                img?.size = size
                return img
            }
        case .neonCat:
            let bundle = Bundle(for: RunnerEngine.self)
            let color = NSColor(hex: neonColorHex) ?? .systemPink
            frames = (0 ..< 5).compactMap { n in
                guard let img = bundle.image(forResource: "cat_page\(n)") else { return nil }
                img.size = size
                return tintedImage(img, tintColor: color)
            }
        case .dog:
            frames = ["🐶", "🐕", "🐩", "🐕"].map { emoji in
                imageFromString(emoji, size: size)
            }
        case .rabbit:
            frames = ["🐰", "🐇", "💨", "🐇"].map { emoji in
                imageFromString(emoji, size: size)
            }
        case .bird:
            frames = ["🐦", "🦅", "🕊️", "🦅"].map { emoji in
                imageFromString(emoji, size: size)
            }
        case .humanoid:
            frames = ["🏃", "🏃‍♂️", "🏃‍♀️", "🏃‍♂️"].map { emoji in
                imageFromString(emoji, size: size)
            }
        case .glitch:
            // Custom pixel glitch blocks
            frames = (0 ..< 4).map { n in
                generateGlitchFrame(index: n, size: size)
            }
        }
        
        index = 0
        if !frames.isEmpty {
            statusItem.button?.image = frames[0]
        }
    }
    
    private func tintedImage(_ image: NSImage, tintColor: NSColor) -> NSImage {
        guard let tinted = image.copy() as? NSImage else { return image }
        tinted.isTemplate = false // Turn off template mode to keep custom color tint
        tinted.lockFocus()
        tintColor.set()
        let rect = NSRect(origin: .zero, size: tinted.size)
        rect.fill(using: .sourceAtop)
        tinted.unlockFocus()
        return tinted
    }
    
    private func imageFromString(_ string: String, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size.height)
        ]
        let stringSize = string.size(withAttributes: attributes)
        let rect = NSRect(
            x: (size.width - stringSize.width) / 2,
            y: (size.height - stringSize.height) / 2,
            width: stringSize.width,
            height: stringSize.height
        )
        string.draw(in: rect, withAttributes: attributes)
        image.unlockFocus()
        return image
    }
    
    private func generateGlitchFrame(index: Int, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let color = NSColor(hex: neonColorHex) ?? .systemGreen
        color.setStroke()
        
        let path = NSBezierPath()
        path.lineWidth = 1.5
        
        // Draw some tech-looking geometric structures depending on index
        switch index {
        case 0:
            path.move(to: NSPoint(x: 2, y: 4))
            path.line(to: NSPoint(x: 10, y: 4))
            path.line(to: NSPoint(x: 14, y: 12))
            path.line(to: NSPoint(x: 22, y: 12))
        case 1:
            path.move(to: NSPoint(x: 2, y: 8))
            path.line(to: NSPoint(x: 12, y: 8))
            path.line(to: NSPoint(x: 16, y: 4))
            path.line(to: NSPoint(x: 22, y: 4))
        case 2:
            path.move(to: NSPoint(x: 4, y: 12))
            path.line(to: NSPoint(x: 10, y: 12))
            path.line(to: NSPoint(x: 14, y: 4))
            path.line(to: NSPoint(x: 20, y: 4))
        default:
            path.move(to: NSPoint(x: 2, y: 6))
            path.line(to: NSPoint(x: 8, y: 10))
            path.line(to: NSPoint(x: 16, y: 10))
            path.line(to: NSPoint(x: 22, y: 6))
        }
        path.stroke()
        
        // Add a tiny random rect block
        let blockRect = NSRect(x: 4 * CGFloat(index + 1), y: 3 * CGFloat(index), width: 4, height: 3)
        color.setFill()
        blockRect.fill()
        
        image.unlockFocus()
        return image
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
