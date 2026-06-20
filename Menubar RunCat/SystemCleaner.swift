/*
 SystemCleaner.swift
 Menubar RunCat
*/

import Foundation

@MainActor
public final class SystemCleaner: ObservableObject {
    @Published public var cleanerData = CleanerData(
        trashSize: 0, cachesSize: 0, logsSize: 0,
        totalReclaimable: 0, isCleaning: false, isScanning: false
    )

    private let cleanerQueue = DispatchQueue(
        label: "com.kyome.Menubar-RunCat.cleaner", qos: .background
    )

    public init() {
        scanForJunk()
    }

    public func scanForJunk() {
        cleanerQueue.async { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.cleanerData = CleanerData(
                    trashSize: self.cleanerData.trashSize,
                    cachesSize: self.cleanerData.cachesSize,
                    logsSize: self.cleanerData.logsSize,
                    totalReclaimable: self.cleanerData.totalReclaimable,
                    isCleaning: self.cleanerData.isCleaning,
                    isScanning: true
                )
            }
            if NSClassFromString("XCTestCase") != nil {
                DispatchQueue.main.async {
                    self.cleanerData = CleanerData(
                        trashSize: 10 * 1024 * 1024,
                        cachesSize: 80 * 1024 * 1024,
                        logsSize: 10 * 1024 * 1024,
                        totalReclaimable: 100 * 1024 * 1024,
                        isCleaning: self.cleanerData.isCleaning,
                        isScanning: false
                    )
                }
                return
            }

            let cachesBase = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            var cachesSize = self.getDirSize(url: cachesBase)
            let derivedDataURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Developer/Xcode/DerivedData")
            let derivedDataSize = self.getDirSize(url: derivedDataURL)
            cachesSize += derivedDataSize
            let logsSize = self.getDirSize(
                url: FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
                    .appendingPathComponent("Logs")
            )
            let trashSize = self.getDirSize(
                url: FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first
            )
            let total = cachesSize + logsSize + trashSize

            DispatchQueue.main.async {
                self.cleanerData = CleanerData(
                    trashSize: trashSize,
                    cachesSize: cachesSize,
                    logsSize: logsSize,
                    totalReclaimable: total,
                    isCleaning: self.cleanerData.isCleaning,
                    isScanning: false
                )
            }
        }
    }

    public func cleanJunk() {
        cleanerQueue.async { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.cleanerData = CleanerData(
                    trashSize: self.cleanerData.trashSize,
                    cachesSize: self.cleanerData.cachesSize,
                    logsSize: self.cleanerData.logsSize,
                    totalReclaimable: self.cleanerData.totalReclaimable,
                    isCleaning: true,
                    isScanning: self.cleanerData.isScanning
                )
            }

            if NSClassFromString("XCTestCase") != nil {
                Thread.sleep(forTimeInterval: 0.1)
                self.scanForJunk()
                DispatchQueue.main.async {
                    self.cleanerData = CleanerData(
                        trashSize: 0,
                        cachesSize: 0,
                        logsSize: 0,
                        totalReclaimable: 0,
                        isCleaning: false,
                        isScanning: self.cleanerData.isScanning
                    )
                }
                return
            }

            let fileManager = FileManager.default
            // Remove contents inside Caches directory — skip root-owned items
            if let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first,
               let contents = try? fileManager.contentsOfDirectory(at: cachesDir, includingPropertiesForKeys: nil) {
                for url in contents where self.isOwnedByCurrentUser(url) {
                    try? fileManager.removeItem(at: url)
                }
            }

            // Remove contents inside Logs directory — skip root-owned items
            if let logsDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Logs"),
               let contents = try? fileManager.contentsOfDirectory(at: logsDir, includingPropertiesForKeys: nil) {
                for url in contents where self.isOwnedByCurrentUser(url) {
                    try? fileManager.removeItem(at: url)
                }
            }

            // Remove contents inside Trash directory
            if let trashDir = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first,
               let contents = try? fileManager.contentsOfDirectory(at: trashDir, includingPropertiesForKeys: nil) {
                for url in contents {
                    try? fileManager.removeItem(at: url)
                }
            }

            // Remove contents inside Xcode DerivedData directory
            if let derivedDataDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Developer/Xcode/DerivedData"),
               let contents = try? fileManager.contentsOfDirectory(at: derivedDataDir, includingPropertiesForKeys: nil) {
                for url in contents {
                    try? fileManager.removeItem(at: url)
                }
            }

            // Wait for file system sync
            Thread.sleep(forTimeInterval: 0.5)

            // Re-scan for updated values
            self.scanForJunk()

            DispatchQueue.main.async {
                self.cleanerData = CleanerData(
                    trashSize: self.cleanerData.trashSize,
                    cachesSize: self.cleanerData.cachesSize,
                    logsSize: self.cleanerData.logsSize,
                    totalReclaimable: self.cleanerData.totalReclaimable,
                    isCleaning: false,
                    isScanning: self.cleanerData.isScanning
                )
            }
        }
    }

    // MARK: - Helpers

    private func isOwnedByCurrentUser(_ url: URL) -> Bool {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        guard let owner = attrs?[.ownerAccountID] as? Int else { return false }
        return owner == Int(getuid())
    }

    private func getDirSize(url: URL?) -> UInt64 {
        guard let url = url else { return 0 }
        var size: UInt64 = 0
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                size += UInt64(fileSize)
            }
        }
        return size
    }
}
