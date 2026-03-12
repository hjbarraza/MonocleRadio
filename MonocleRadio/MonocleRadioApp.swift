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
        MenuBarExtra {
            PopoverView(viewModel: viewModel)
                .frame(width: 360, height: 520)
        } label: {
            if let url = Bundle.module.url(forResource: "MenuBarIcon", withExtension: "png",
                                           subdirectory: "Resources"),
               let nsImage = NSImage(contentsOf: url) {
                let image: NSImage = {
                    $0.size = NSSize(width: 18, height: 18)
                    $0.isTemplate = true
                    return $0
                }(nsImage)
                Image(nsImage: image)
            } else {
                Image(systemName: "radio")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
