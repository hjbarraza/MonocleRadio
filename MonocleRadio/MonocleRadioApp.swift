// MonocleRadioApp.swift — @main entry point with MenuBarExtra
// Monocle Radio — macOS menu bar player for Monocle 24

import SwiftUI
import AppKit

/// Checks for an existing instance on launch. If found, activates it and exits.
private func ensureSingleInstance() {
    let dominated = NSRunningApplication.runningApplications(
        withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.monocle.radio"
    ).filter { $0 != .current }

    if let existing = dominated.first {
        existing.activate()
        NSApp.terminate(nil)
    }
}

@main
struct MonocleRadioApp: App {
    @State private var viewModel = RadioViewModel()

    init() {
        ensureSingleInstance()
    }

    var body: some Scene {
        MenuBarExtra("Monocle Radio", systemImage: "radio") {
            PopoverView(viewModel: viewModel)
                .frame(width: 360, height: 520)
        }
        .menuBarExtraStyle(.window)
    }
}
