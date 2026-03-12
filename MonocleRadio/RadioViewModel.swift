// RadioViewModel.swift — @Observable view model orchestrating audio, UI state, media keys, now playing
// Monocle Radio — macOS menu bar player for Monocle 24

import SwiftUI
import MediaPlayer
import AppKit

/// Single source of truth for the entire app. Owns AudioEngine, episode cache,
/// show/episode selection, media key handling, and Now Playing integration.
@Observable
class RadioViewModel {
    let engine = AudioEngine()
    let shows = Show.all()

    var selectedShow: Show?
    var episodes: [Episode] = []
    var currentShow: Show?
    var currentEpisode: Episode?
    var isLoadingEpisodes = false
    var episodeError: String?

    // Volume persisted via UserDefaults (can't use @AppStorage outside SwiftUI views)
    var volume: Double {
        didSet {
            engine.volume = Float(volume / 100)
            UserDefaults.standard.set(volume, forKey: "volume")
        }
    }

    // Episode cache — simple dictionary with timestamps
    private var episodeCache: [String: (episodes: [Episode], fetched: Date)] = [:]
    private let cacheTTL: TimeInterval = 30 * 60  // 30 minutes

    init() {
        let saved = UserDefaults.standard.double(forKey: "volume")
        self.volume = saved > 0 ? saved : 75
        engine.volume = Float(self.volume / 100)
        setupMediaKeys()
        setupWakeObserver()

        // Auto-play live stream on launch
        Task { @MainActor in playLive() }
    }

    // MARK: - Computed Properties

    var isPlaying: Bool { engine.isPlaying }
    var isLive: Bool { engine.isLive }
    var streamTitle: String { engine.streamTitle }
    var progress: Double { engine.duration > 0 ? engine.elapsed / engine.duration : 0 }
    var currentCoverURL: URL? { currentShow?.coverURL }

    var subtitle: String {
        if isLive && !streamTitle.isEmpty { return streamTitle }
        if let ep = currentEpisode { return ep.title }
        return currentShow?.description ?? ""
    }

    var statusColor: Color {
        guard isPlaying else { return .secondary }
        return isLive ? .red : .green
    }

    var elapsedString: String { formatTime(engine.elapsed) }
    var durationString: String { formatTime(engine.duration) }

    // MARK: - Playback

    func playLive() {
        currentShow = shows.first
        currentEpisode = nil
        engine.play(url: Show.liveStreamURL, live: true)
        updateNowPlaying()
    }

    func play(_ episode: Episode, from show: Show) {
        guard let url = episode.audioURL else { return }
        currentShow = show
        currentEpisode = episode
        engine.play(url: url, live: false)
        updateNowPlaying()
    }

    func togglePlayPause() {
        engine.togglePlayPause()
        updateNowPlaying()
    }

    // MARK: - Show/Episode Selection

    func selectShow(_ show: Show) {
        selectedShow = show
        if show.isLive {
            playLive()
            return
        }

        // Check cache
        if let cached = episodeCache[show.slug],
           Date().timeIntervalSince(cached.fetched) < cacheTTL {
            episodes = cached.episodes
            episodeError = nil
            return
        }

        loadEpisodes(for: show)
    }

    func retryEpisodes() {
        guard let show = selectedShow else { return }
        loadEpisodes(for: show)
    }

    private func loadEpisodes(for show: Show) {
        isLoadingEpisodes = true
        episodeError = nil
        episodes = []
        Task { @MainActor in
            do {
                let eps = try await show.fetchEpisodes()
                episodeCache[show.slug] = (eps, Date())
                // Only update if still viewing this show
                if selectedShow == show {
                    episodes = eps
                }
            } catch {
                if selectedShow == show {
                    episodeError = "Could not load episodes. Tap to retry."
                }
            }
            if selectedShow == show {
                isLoadingEpisodes = false
            }
        }
    }

    // MARK: - Media Keys (MPRemoteCommandCenter)

    private func setupMediaKeys() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            self?.engine.resume()
            self?.updateNowPlaying()
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            self?.engine.pause()
            self?.updateNowPlaying()
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        // Disable unsupported commands
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
    }

    // MARK: - Now Playing Info Center

    private func updateNowPlaying() {
        let title: String
        if let ep = currentEpisode {
            title = ep.title
        } else if !streamTitle.isEmpty {
            title = streamTitle
        } else {
            title = currentShow?.name ?? "Monocle 24"
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: "Monocle 24",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: engine.elapsed,
        ]
        if engine.duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = engine.duration
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    // MARK: - Sleep/Wake

    private func setupWakeObserver() {
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, self.isLive, !self.isPlaying else { return }
            self.playLive()
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds > 0 else { return "0:00" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}
