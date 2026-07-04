// LiveActivityController.swift — ON AIR in the Dynamic Island and lock screen
// Monocle Radio — iOS player for Monocle 24

import Foundation
import ActivityKit
import MonocleRadioKit

/// Mirrors playback into a Live Activity: started on play, updated on
/// pause/track changes, ended when paused for a while. RootView calls
/// sync() from onChange observers.
@MainActor
final class LiveActivityController {
    private var activity: Activity<NowPlayingActivityAttributes>?
    private var endTask: Task<Void, Never>?

    func sync(with viewModel: RadioViewModel) {
        let state = NowPlayingActivityAttributes.ContentState(
            title: viewModel.currentShow?.name ?? "Monocle 24",
            subtitle: viewModel.subtitle,
            isPlaying: viewModel.isPlaying,
            isLive: viewModel.isLive
        )

        if viewModel.isPlaying {
            endTask?.cancel()
            endTask = nil
            if let activity {
                Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
            } else if ActivityAuthorizationInfo().areActivitiesEnabled {
                activity = try? Activity.request(
                    attributes: NowPlayingActivityAttributes(),
                    content: ActivityContent(state: state, staleDate: nil)
                )
            }
        } else if let activity {
            // Show the paused state, then retire the activity if the pause sticks
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
            endTask?.cancel()
            endTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(10 * 60))
                guard !Task.isCancelled else { return }
                await self?.end()
            }
        }
    }

    func end() async {
        await activity?.end(nil, dismissalPolicy: .immediate)
        activity = nil
    }
}
