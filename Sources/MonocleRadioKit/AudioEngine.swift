// AudioEngine.swift — AVPlayer wrapper for live streaming and on-demand playback
// MonocleRadioKit — shared core for the macOS and iOS Monocle Radio apps

import AVFoundation
import Combine

/// Handles audio playback via AVPlayer with ICY metadata extraction,
/// periodic time observation, and auto-reconnect for live streams.
@Observable
public class AudioEngine: NSObject, AVPlayerItemMetadataOutputPushDelegate {
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var reconnectAttempts = 0
    private let maxReconnects = 3
    private var lastPlayedURL: URL?

    // Published state
    public var isPlaying = false
    public var isLive = false
    public var streamTitle = ""
    public var elapsed: TimeInterval = 0
    public var duration: TimeInterval = 0
    public var volume: Float = 0.75 {
        didSet { player?.volume = volume }
    }
    public var error: String?

    /// Whether a player item is currently loaded (playing or paused).
    public var hasCurrentItem: Bool { playerItem != nil }

    public override init() {
        super.init()
    }

    // MARK: - Playback Controls

    public func play(url: URL, live: Bool = false) {
        stop()

        #if os(iOS)
        // Activate lazily so launching the app doesn't interrupt other audio
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        isLive = live
        lastPlayedURL = url
        reconnectAttempts = 0
        error = nil

        let asset = AVURLAsset(url: url)
        playerItem = AVPlayerItem(asset: asset)

        // ICY metadata output
        let metaOutput = AVPlayerItemMetadataOutput(identifiers: nil)
        metaOutput.setDelegate(self, queue: .main)
        playerItem?.add(metaOutput)

        player = AVPlayer(playerItem: playerItem)
        player?.volume = volume

        if !live { addTimeObserver() }
        observeStatus()

        player?.play()
        isPlaying = true
    }

    public func pause() {
        player?.pause()
        isPlaying = false
    }

    public func resume() {
        player?.play()
        isPlaying = true
    }

    public func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }

    /// Seek to an absolute position (on-demand only; no-op for live streams).
    public func seek(to seconds: TimeInterval) {
        guard !isLive, let player else { return }
        let clamped = max(0, duration > 0 ? min(seconds, duration) : seconds)
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
        elapsed = clamped
    }

    /// Skip forward (positive) or backward (negative) relative to the current position.
    public func skip(by seconds: TimeInterval) {
        seek(to: elapsed + seconds)
    }

    public func stop() {
        if let t = timeObserver {
            player?.removeTimeObserver(t)
            timeObserver = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
        player?.pause()
        player = nil
        playerItem = nil
        isPlaying = false
        elapsed = 0
        duration = 0
        streamTitle = ""
        error = nil
    }

    // MARK: - ICY Metadata Delegate

    public func metadataOutput(
        _ output: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
        from track: AVPlayerItemTrack?
    ) {
        let items = groups.flatMap(\.items)
        Task { @MainActor in
            for item in items {
                if let title = try? await item.load(.stringValue), !title.isEmpty {
                    self.streamTitle = title
                    return
                }
            }
        }
    }

    // MARK: - Time Observer (on-demand episodes)

    private func addTimeObserver() {
        let interval = CMTime(seconds: 1, preferredTimescale: 1)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
            [weak self] time in
            guard let self else { return }
            self.elapsed = CMTimeGetSeconds(time)
            if let d = self.playerItem?.duration, d.isNumeric {
                self.duration = CMTimeGetSeconds(d)
            }
        }
    }

    // MARK: - Status Observation & Auto-Reconnect

    private func observeStatus() {
        statusObservation = playerItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            switch item.status {
            case .failed:
                self.handleFailure()
            case .readyToPlay:
                self.error = nil
            default:
                break
            }
        }
    }

    private func handleFailure() {
        guard isLive, reconnectAttempts < maxReconnects, let url = lastPlayedURL else {
            isPlaying = false
            error = "Playback failed. Tap to retry."
            return
        }
        reconnectAttempts += 1
        error = "Reconnecting... (\(reconnectAttempts)/\(maxReconnects))"
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            self.play(url: url, live: true)
        }
    }
}
