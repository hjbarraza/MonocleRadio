// AudioSessionController.swift — iOS-only playback resilience
// Monocle Radio — iOS player for Monocle 24

import AVFAudio
import Network
import MonocleRadioKit

/// Handles the playback concerns that only exist on iOS: audio session
/// interruptions (phone calls, Siri, alarms), route changes (headphones
/// unplugged), and network-path-driven recovery of the live stream.
@MainActor
final class AudioSessionController {
    private let viewModel: RadioViewModel
    private var wasPlayingBeforeInterruption = false
    private var wasPlayingLiveWhenPathLost = false
    private var pathWasSatisfied = true
    private let pathMonitor = NWPathMonitor()
    private var observers: [NSObjectProtocol] = []

    init(viewModel: RadioViewModel) {
        self.viewModel = viewModel
        let session = AVAudioSession.sharedInstance()

        observers.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session, queue: .main
        ) { [weak self] note in
            let userInfo = note.userInfo
            Task { @MainActor in self?.handleInterruption(userInfo) }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session, queue: .main
        ) { [weak self] note in
            let userInfo = note.userInfo
            Task { @MainActor in self?.handleRouteChange(userInfo) }
        })

        pathMonitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            Task { @MainActor in self?.handlePathUpdate(satisfied: satisfied) }
        }
        pathMonitor.start(queue: DispatchQueue(label: "com.monocle.radio.pathmonitor"))
    }

    deinit {
        pathMonitor.cancel()
    }

    // MARK: - Interruptions (calls, Siri, alarms)

    private func handleInterruption(_ userInfo: [AnyHashable: Any]?) {
        guard let typeValue = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            wasPlayingBeforeInterruption = viewModel.isPlaying
            if viewModel.isPlaying { viewModel.togglePlayPause() }
        case .ended:
            let optionsValue = userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if wasPlayingBeforeInterruption, options.contains(.shouldResume) {
                if viewModel.isLive {
                    // Rejoin the live edge — resuming a stalled live buffer
                    // plays stale audio or fails outright
                    viewModel.playLive()
                } else {
                    viewModel.togglePlayPause()
                }
            }
            wasPlayingBeforeInterruption = false
        @unknown default:
            break
        }
    }

    // MARK: - Route changes (headphones unplugged)

    private func handleRouteChange(_ userInfo: [AnyHashable: Any]?) {
        guard let reasonValue = userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
              reason == .oldDeviceUnavailable, viewModel.isPlaying else { return }
        // Never switch a private listen to the open speaker
        viewModel.togglePlayPause()
    }

    // MARK: - Network path (cellular <-> Wi-Fi, airplane mode)

    private func handlePathUpdate(satisfied: Bool) {
        defer { pathWasSatisfied = satisfied }
        if !satisfied, pathWasSatisfied {
            wasPlayingLiveWhenPathLost = viewModel.isPlaying && viewModel.isLive
        } else if satisfied, !pathWasSatisfied, wasPlayingLiveWhenPathLost {
            wasPlayingLiveWhenPathLost = false
            viewModel.playLive()
        }
    }
}
