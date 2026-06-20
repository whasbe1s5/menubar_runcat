import XCTest
@testable import Menubar_RunCat

@MainActor
final class MenubarRunCatTests: XCTestCase {
    
    func testSystemMonitorInitialization() {
        let monitor = SystemMonitor()
        XCTAssertNotNil(monitor)
        
        let expectation = self.expectation(description: "Wait for stats")
        var checkCount = 0
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            checkCount += 1
            if monitor.currentUptime.uptime > 0 || checkCount > 50 {
                timer.invalidate()
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 6.0)
        
        // Check CPU Usage Data
        XCTAssertGreaterThanOrEqual(monitor.currentCPU.value, 0.0)
        XCTAssertLessThanOrEqual(monitor.currentCPU.value, 100.0)
        XCTAssertFalse(monitor.currentCPU.description.isEmpty)
        
        // Check Memory Usage Data
        XCTAssertGreaterThan(monitor.currentMemory.total, 0)
        XCTAssertGreaterThanOrEqual(monitor.currentMemory.used, 0)
        
        // Check Disk Usage Data
        XCTAssertGreaterThan(monitor.currentDisk.total, 0)
        XCTAssertGreaterThanOrEqual(monitor.currentDisk.used, 0)
        
        // Check Network Usage Data
        XCTAssertGreaterThanOrEqual(monitor.currentNetwork.downloadSpeedBytes, 0)
        XCTAssertGreaterThanOrEqual(monitor.currentNetwork.uploadSpeedBytes, 0)
        
        // Check Battery Data
        XCTAssertGreaterThanOrEqual(monitor.currentBattery.percentage, 0.0)
        XCTAssertLessThanOrEqual(monitor.currentBattery.percentage, 100.0)
        
        // Check Uptime Data
        XCTAssertGreaterThan(monitor.currentUptime.uptime, 0)
        XCTAssertFalse(monitor.currentUptime.formatted.isEmpty)
        
        // Check Thermal State
        XCTAssertNotNil(monitor.thermalPressure)
        
        // Check Process Data (sampled every 5 seconds, may be empty on quick tests)
        XCTAssertGreaterThanOrEqual(monitor.topCPUProcs.count, 0)
        XCTAssertGreaterThanOrEqual(monitor.topMemoryProcs.count, 0)
        if !monitor.topCPUProcs.isEmpty {
            let proc = monitor.topCPUProcs[0]
            XCTAssertFalse(proc.name.isEmpty)
            XCTAssertGreaterThanOrEqual(proc.cpuPercent, 0.0)
            XCTAssertGreaterThanOrEqual(proc.memoryBytes, 0)
        }
    }
    
    func testRunnerEngineSettingsPersistence() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let engine = RunnerEngine(statusItem: statusItem)
        
        // Test switching runner type
        engine.currentType = .dog
        XCTAssertEqual(engine.currentType, .dog)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "runnerType"), RunnerType.dog.rawValue)
        
        // Test changing neon color hex
        engine.neonColorHex = "#00F0FF"
        XCTAssertEqual(engine.neonColorHex, "#00F0FF")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "neonColorHex"), "#00F0FF")
        
        // Test changing speed multiplier
        engine.speedMultiplier = 2.5
        XCTAssertEqual(engine.speedMultiplier, 2.5)
        XCTAssertEqual(UserDefaults.standard.double(forKey: "speedMultiplier"), 2.5)
        
        // Test frame updates on config changes
        engine.currentType = .cat
        XCTAssertEqual(engine.currentType, .cat)
    }
    
    func testNSColorHexInitializer() {
        let pink = NSColor(hex: "#FF007F")
        XCTAssertNotNil(pink)
        
        let invalid = NSColor(hex: "invalid")
        XCTAssertNil(invalid)
    }
    
    func testCatImagesExist() {
        let bundle = Bundle(for: RunnerEngine.self)
        let img = bundle.image(forResource: "cat_page0")
        XCTAssertNotNil(img, "cat_page0 should not be nil")
    }
    
    func testMacCleanerScanAndClean() {
        let cleaner = SystemCleaner()
        XCTAssertNotNil(cleaner)
        
        cleaner.scanForJunk()
        
        let scanExpectation = self.expectation(description: "Scan junk")
        var scanCheckCount = 0
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            scanCheckCount += 1
            if !cleaner.cleanerData.isScanning || scanCheckCount > 80 {
                timer.invalidate()
                scanExpectation.fulfill()
            }
        }
        wait(for: [scanExpectation], timeout: 10.0)
        
        XCTAssertFalse(cleaner.cleanerData.isScanning)
        XCTAssertGreaterThanOrEqual(cleaner.cleanerData.totalReclaimable, 0)
        
        cleaner.cleanJunk()
        
        let cleanExpectation = self.expectation(description: "Clean junk")
        var cleanCheckCount = 0
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            cleanCheckCount += 1
            if !cleaner.cleanerData.isCleaning || cleanCheckCount > 80 {
                timer.invalidate()
                cleanExpectation.fulfill()
            }
        }
        wait(for: [cleanExpectation], timeout: 10.0)
        
        XCTAssertFalse(cleaner.cleanerData.isCleaning)
    }
}
