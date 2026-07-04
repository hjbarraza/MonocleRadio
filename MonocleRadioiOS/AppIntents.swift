// AppIntents.swift — Siri, Shortcuts, and Action Button support
// "Hey Siri, play Monocle 24" — Monocle Radio, iOS player for Monocle 24

import AppIntents
import MonocleRadioKit

/// Starts the live stream without opening the UI (audio intents run in-process).
struct PlayMonocleLiveIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Play Monocle 24"
    static var description = IntentDescription("Start the Monocle 24 live radio stream.")

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.viewModel.playLive()
        return .result()
    }
}

/// Toggles playback of whatever is current (live or episode).
struct TogglePlaybackIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Play or Pause Monocle Radio"
    static var description = IntentDescription("Toggle Monocle Radio playback.")

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.viewModel.togglePlayPause()
        return .result()
    }
}

/// Resumes the last on-demand episode where it left off.
struct ContinueListeningIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Continue Listening"
    static var description = IntentDescription("Resume your last Monocle Radio episode.")

    @MainActor
    func perform() async throws -> some IntentResult {
        if AppModel.viewModel.continueListening != nil {
            AppModel.viewModel.resumeContinueListening()
        } else {
            AppModel.viewModel.playLive()
        }
        return .result()
    }
}

struct MonocleRadioShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayMonocleLiveIntent(),
            phrases: [
                "Play \(.applicationName)",
                "Play Monocle 24 in \(.applicationName)",
                "Listen to \(.applicationName)",
            ],
            shortTitle: "Play Live",
            systemImageName: "radio"
        )
        AppShortcut(
            intent: ContinueListeningIntent(),
            phrases: [
                "Continue listening in \(.applicationName)",
                "Resume \(.applicationName)",
            ],
            shortTitle: "Continue",
            systemImageName: "play.circle"
        )
    }
}
