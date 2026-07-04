// MonocleRadioWatchApp.swift — @main entry point for the watchOS app
// Monocle Radio — Apple Watch player for Monocle 24

import SwiftUI
import MonocleRadioKit

@main
struct MonocleRadioWatchApp: App {
    @State private var viewModel: RadioViewModel

    init() {
        let vm = RadioViewModel()
        // Live selected but paused — one tap to listen, same as iOS
        vm.currentShow = vm.shows.first
        _viewModel = State(initialValue: vm)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
