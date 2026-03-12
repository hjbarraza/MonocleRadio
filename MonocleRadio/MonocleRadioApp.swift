// MonocleRadioApp.swift — @main entry point with MenuBarExtra
// Monocle Radio — macOS menu bar player for Monocle 24

import SwiftUI

@main
struct MonocleRadioApp: App {
    @State private var viewModel = RadioViewModel()

    var body: some Scene {
        MenuBarExtra("Monocle Radio", systemImage: "radio") {
            PopoverView(viewModel: viewModel)
                .frame(width: 360, height: 520)
        }
        .menuBarExtraStyle(.window)
    }
}
