/*
 AppEntry.swift
 Menubar RunCat

 Created by Takuto Nakamura on 2023/05/19.
 Copyright © 2023 Takuto Nakamura. All rights reserved.
*/

import Cocoa

final class TestAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Do nothing for tests
    }
}

@main
struct AppEntry {
    @MainActor
    static func main() {
        if NSClassFromString("XCTestCase") == nil {
            let delegate = AppDelegate()
            NSApplication.shared.delegate = delegate
            _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
        } else {
            let delegate = TestAppDelegate()
            NSApplication.shared.delegate = delegate
            _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
        }
    }
}
