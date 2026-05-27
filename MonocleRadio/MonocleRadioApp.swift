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

/// Assembles a multi-resolution template NSImage from the bundled 1x/2x/3x PNGs.
/// Each rep's logical size is set to 18pt so NSImage can pick the rep matching
/// the display's backing scale instead of upscaling a single 18-pixel bitmap.
private func menuBarImage() -> NSImage? {
    let names = ["MenuBarIcon.png", "MenuBarIcon@2x.png", "MenuBarIcon@3x.png"]
    let reps: [NSImageRep] = names.compactMap { name in
        guard let url = Bundle.module.url(forResource: name, withExtension: nil,
                                          subdirectory: "Resources"),
              let data = try? Data(contentsOf: url),
              let rep = NSBitmapImageRep(data: data) else { return nil }
        rep.size = NSSize(width: 18, height: 18)
        return rep
    }
    guard !reps.isEmpty else { return nil }
    let image = NSImage(size: NSSize(width: 18, height: 18))
    reps.forEach { image.addRepresentation($0) }
    image.isTemplate = true
    return image
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
                .frame(width: 420, height: 520)
        } label: {
            if let image = menuBarImage() {
                Image(nsImage: image)
            } else {
                Image(systemName: "radio")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
