// MonocleRadioiOSApp.swift — @main entry point for the iOS/iPadOS app
// Monocle Radio — iOS player for Monocle 24

import SwiftUI
import AVFAudio
import MonocleRadioKit

@main
struct MonocleRadioiOSApp: App {
    @State private var viewModel: RadioViewModel

    init() {
        // Category is set up front; the session is activated lazily on first
        // play (AudioEngine) so launching doesn't interrupt other audio.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)

        let vm = RadioViewModel()
        // Launch with the live stream selected but paused — one tap to listen
        vm.currentShow = vm.shows.first
        _viewModel = State(initialValue: vm)
    }

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
        }
    }
}
