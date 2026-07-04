// MonocleRadioiOSApp.swift — @main entry point for the iOS/iPadOS app
// Monocle Radio — iOS player for Monocle 24

import SwiftUI
import AVFAudio
import MonocleRadioKit

/// Process-wide model handle so App Intents (Siri/Shortcuts) reach the same
/// player the UI drives.
enum AppModel {
    @MainActor static let viewModel: RadioViewModel = {
        let vm = RadioViewModel()
        // Launch with the live stream selected but paused — one tap to listen
        vm.currentShow = vm.shows.first
        return vm
    }()
}

@main
struct MonocleRadioiOSApp: App {
    init() {
        // Category is set up front; the session is activated lazily on first
        // play (AudioEngine) so launching doesn't interrupt other audio.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
    }

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: AppModel.viewModel)
        }
    }
}
