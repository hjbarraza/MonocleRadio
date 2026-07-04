// RadioViewModel.swift — @Observable view model orchestrating audio, UI state, media keys, now playing
// MonocleRadioKit — shared core for the macOS and iOS Monocle Radio apps

import SwiftUI
import MediaPlayer
#if os(macOS)
import AppKit
#endif

/// Single source of truth for the entire app. Owns AudioEngine, episode cache,
/// show/episode selection, media key handling, and Now Playing integration.
@Observable
public class RadioViewModel {
    public let engine = AudioEngine()
    public let shows = Show.all()

    public var selectedShow: Show?
    public var episodes: [Episode] = []
    public var currentShow: Show?
    public var currentEpisode: Episode?
    public var isLoadingEpisodes = false
    public var episodeError: String?

    // Volume persisted via UserDefaults (can't use @AppStorage outside SwiftUI views)
    public var volume: Double {
        didSet {
            engine.volume = Float(volume / 100)
            UserDefaults.standard.set(volume, forKey: "volume")
        }
    }

    // Episode cache — simple dictionary with timestamps
    private var episodeCache: [String: (episodes: [Episode], fetched: Date)] = [:]
    private let cacheTTL: TimeInterval = 30 * 60  // 30 minutes

    public init() {
        let saved = UserDefaults.standard.double(forKey: "volume")
        self.volume = saved > 0 ? saved : 75
        engine.volume = Float(self.volume / 100)
        setupMediaKeys()

        #if os(macOS)
        setupWakeObserver()
        // Auto-play live stream on launch (macOS only — on iOS the app may
        // launch into the background and users expect silence until they act)
        Task { @MainActor in playLive() }
        #endif
    }

    // MARK: - Computed Properties

    public var isPlaying: Bool { engine.isPlaying }
    public var isLive: Bool { engine.isLive }
    public var streamTitle: String { engine.streamTitle }
    public var progress: Double { engine.duration > 0 ? engine.elapsed / engine.duration : 0 }
    public var currentCoverURL: URL? { currentShow?.coverURL }

    public var subtitle: String {
        if isLive && !streamTitle.isEmpty { return streamTitle }
        if let ep = currentEpisode { return ep.title }
        return currentShow?.description ?? ""
    }

    public var statusColor: Color {
        guard isPlaying else { return .secondary }
        return isLive ? .red : .green
    }

    public var elapsedString: String { formatTime(engine.elapsed) }
    public var durationString: String { formatTime(engine.duration) }

    // MARK: - Playback

    public func playLive() {
        currentShow = shows.first
        currentEpisode = nil
        engine.play(url: Show.liveStreamURL, live: true)
        updateNowPlaying()
    }

    public func play(_ episode: Episode, from show: Show) {
        guard let url = episode.audioURL else { return }
        currentShow = show
        currentEpisode = episode
        engine.play(url: url, live: false)
        updateNowPlaying()
    }

    public func togglePlayPause() {
        engine.togglePlayPause()
        updateNowPlaying()
    }

    // MARK: - Show/Episode Selection

    public func selectShow(_ show: Show) {
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

    public func retryEpisodes() {
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

    func updateNowPlaying() {
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
        #if os(macOS)
        // playbackState is macOS-only; iOS infers state from playbackRate
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        #endif
    }

    // MARK: - Sleep/Wake (macOS)

    #if os(macOS)
    private func setupWakeObserver() {
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, self.isLive, !self.isPlaying else { return }
            self.playLive()
        }
    }
    #endif

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds > 0 else { return "0:00" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}
