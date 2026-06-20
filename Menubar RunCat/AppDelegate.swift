/*
 AppDelegate.swift
 Menubar RunCat

 Created by Takuto Nakamura on 2019/08/06.
 Copyright © 2019 Takuto Nakamura. All rights reserved.
*/

import Cocoa
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var statusItem: NSStatusItem = {
        return NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    }()
    
    private let popover = NSPopover()
    private var monitor: SystemMonitor!
    private var engine: RunnerEngine!
    private var cancellables = Set<AnyCancellable>()
    private var cleaner: SystemCleaner!
    private var showPercentage = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize Monitor & Engine
        monitor = SystemMonitor()
        cleaner = SystemCleaner()
        engine = RunnerEngine(statusItem: statusItem)
        
        // Load settings
        showPercentage = UserDefaults.standard.bool(forKey: "showPercentageInMenuBar")
        
        setupStatusItem()
        setupPopover()
        setNotifications()
        
        // Start animating
        engine.start()
        
        // Wire Monitor updates to Engine speed & Status Item title
        monitor.$currentCPU
            .sink { [weak self] cpuData in
                guard let self = self else { return }
                self.engine.updateSpeed(cpuUsage: cpuData.value)
                
                if self.showPercentage {
                    self.statusItem.button?.title = cpuData.description
                } else {
                    self.statusItem.button?.title = ""
                }
            }
            .store(in: &cancellables)
        
        // Listen to settings toggle notification
        NotificationCenter.default.publisher(for: NSNotification.Name("ToggleShowPercentage"))
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.showPercentage = UserDefaults.standard.bool(forKey: "showPercentageInMenuBar")
                if !self.showPercentage {
                    self.statusItem.button?.title = ""
                }
            }
            .store(in: &cancellables)
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
        monitor.stopMonitoring()
    }

    private func setupStatusItem() {
        statusItem.button?.imagePosition = .imageTrailing
        statusItem.button?.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))
    }
    
    private func setupPopover() {
        popover.contentSize = NSSize(width: 320, height: 520)
        popover.behavior = .transient
        
        let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 320, height: 520))
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        
        let hostingView = NSHostingView(rootView: DashboardView(monitor: monitor, cleaner: cleaner, engine: engine))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(hostingView)
        
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
        ])
        
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = visualEffect
    }
    

    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }

    private func showPopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
    }

    @objc func receiveSleep(_ notification: NSNotification) {
        engine.stop()
        monitor.stopMonitoring()
    }

    @objc func receiveWakeUp(_ notification: NSNotification) {
        engine.start()
        monitor.startMonitoring()
    }

    private func setNotifications() {
        NSWorkspace.shared.notificationCenter
            .addObserver(self, selector: #selector(receiveSleep(_:)),
                         name: NSWorkspace.willSleepNotification,
                         object: nil)
        NSWorkspace.shared.notificationCenter
            .addObserver(self, selector: #selector(receiveWakeUp(_:)),
                         name: NSWorkspace.didWakeNotification,
                         object: nil)
    }
}
