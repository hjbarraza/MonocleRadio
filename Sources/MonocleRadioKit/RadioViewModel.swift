// RadioViewModel.swift — @Observable view model orchestrating audio, UI state, media keys, now playing
// MonocleRadioKit — shared core for the macOS and iOS Monocle Radio apps

import SwiftUI
import MediaPlayer
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
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
        #if os(macOS)
        let saved = UserDefaults.standard.double(forKey: "volume")
        self.volume = saved > 0 ? saved : 75
        engine.volume = Float(self.volume / 100)
        #else
        // iOS: volume is the hardware buttons' job — play at full player volume
        self.volume = 100
        engine.volume = 1.0
        #endif
        loadResumeState()
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
    public var isBuffering: Bool { engine.isBuffering }
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
        updateCommandAvailability()
        loadArtwork(for: currentShow?.coverURL)
        updateNowPlaying()
    }

    public func play(_ episode: Episode, from show: Show) {
        guard let url = episode.audioURL else { return }
        currentShow = show
        currentEpisode = episode
        engine.play(url: url, live: false)
        updateCommandAvailability()
        loadArtwork(for: show.coverURL)
        updateNowPlaying()
    }

    public func togglePlayPause() {
        // Nothing loaded yet (iOS launches with live selected but paused, or
        // playback was stopped) — start whatever is current instead of
        // toggling a nonexistent player item.
        guard engine.hasCurrentItem else {
            if let ep = currentEpisode, let show = currentShow {
                play(ep, from: show)
            } else {
                playLive()
            }
            return
        }
        engine.togglePlayPause()
        updateNowPlaying()
    }

    /// Seek to an absolute position within the current on-demand episode.
    public func seek(to seconds: TimeInterval) {
        engine.seek(to: seconds)
        updateNowPlaying()
    }

    /// Skip forward/backward within the current on-demand episode.
    public func skip(by seconds: TimeInterval) {
        engine.skip(by: seconds)
        updateNowPlaying()
    }

    // MARK: - Show/Episode Selection

    /// `autoplayLive` keeps the macOS popover behavior (tap live row = listen);
    /// iOS passes `false` so navigating never starts audio uninvited.
    public func selectShow(_ show: Show, autoplayLive: Bool = true) {
        selectedShow = show
        if show.isLive {
            if autoplayLive { playLive() }
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

    // MARK: - Programme Schedule

    public private(set) var schedule: [ScheduleEntry] = []
    @ObservationIgnored private var scheduleFetched: Date?

    /// Today's entry currently on air (nil until the schedule loads).
    public var onAirNow: ScheduleEntry? {
        schedule.last { $0.time <= Date() }
    }

    /// The next programme after now.
    public var upNext: ScheduleEntry? {
        schedule.first { $0.time > Date() }
    }

    /// Fetch today's programme, throttled to every 30 minutes.
    public func loadSchedule() {
        if let fetched = scheduleFetched, Date().timeIntervalSince(fetched) < 30 * 60 { return }
        scheduleFetched = Date()
        Task { @MainActor in
            if let entries = try? await Schedule.fetchToday(), !entries.isEmpty {
                schedule = entries
            } else {
                // Allow a retry sooner than the throttle on failure
                scheduleFetched = nil
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

        // Skip ±15s and lock screen scrubbing (on-demand only; gated per-mode
        // in updateCommandAvailability and re-checked in the handlers)
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] _ in
            guard let self, !self.isLive else { return .commandFailed }
            self.skip(by: 15)
            return .success
        }

        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            guard let self, !self.isLive else { return .commandFailed }
            self.skip(by: -15)
            return .success
        }

        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, !self.isLive,
                  let event = event as? MPChangePlaybackPositionCommandEvent
            else { return .commandFailed }
            self.seek(to: event.positionTime)
            return .success
        }

        // Disable unsupported commands
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false

        updateCommandAvailability()
    }

    /// Skip/scrub only make sense for on-demand episodes, not the live stream.
    private func updateCommandAvailability() {
        let center = MPRemoteCommandCenter.shared()
        let onDemand = engine.hasCurrentItem && !isLive
        center.skipForwardCommand.isEnabled = onDemand
        center.skipBackwardCommand.isEnabled = onDemand
        center.changePlaybackPositionCommand.isEnabled = onDemand
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
            MPNowPlayingInfoPropertyIsLiveStream: isLive,
        ]
        if engine.duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = engine.duration
        }
        if let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        #if os(macOS)
        // playbackState is macOS-only; iOS infers state from playbackRate
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        #endif

        saveResumeState()
    }

    // MARK: - Resume (Continue Listening)

    public struct ResumeState {
        public let show: Show
        public let episode: Episode
        public let position: TimeInterval
    }

    /// Last on-demand listening position, restored across launches.
    public private(set) var continueListening: ResumeState?

    /// Persist the current on-demand position. Called from updateNowPlaying
    /// (play/pause/seek/skip) and from the app on scene-phase changes.
    public func saveResumeState() {
        guard !isLive, let ep = currentEpisode, let show = currentShow,
              let url = ep.audioURL, engine.elapsed > 30 else { return }
        // Within the last minute — treat as finished, don't offer a resume
        if engine.duration > 0, engine.elapsed > engine.duration - 60 {
            clearResumeState()
            return
        }
        let d = UserDefaults.standard
        d.set(show.slug, forKey: "resume.showSlug")
        d.set(url.absoluteString, forKey: "resume.audioURL")
        d.set(ep.title, forKey: "resume.title")
        d.set(ep.number, forKey: "resume.number")
        d.set(ep.date, forKey: "resume.date")
        d.set(ep.description, forKey: "resume.description")
        d.set(ep.imageURL?.absoluteString, forKey: "resume.imageURL")
        d.set(engine.elapsed, forKey: "resume.position")
        continueListening = ResumeState(show: show, episode: ep, position: engine.elapsed)
    }

    public func resumeContinueListening() {
        guard let state = continueListening else { return }
        play(state.episode, from: state.show)
        seek(to: state.position)
    }

    private func loadResumeState() {
        let d = UserDefaults.standard
        guard let slug = d.string(forKey: "resume.showSlug"),
              let show = shows.first(where: { $0.slug == slug }),
              let urlString = d.string(forKey: "resume.audioURL"),
              let url = URL(string: urlString),
              let title = d.string(forKey: "resume.title") else { return }
        let episode = Episode(
            title: title,
            audioURL: url,
            number: d.string(forKey: "resume.number") ?? "",
            date: d.string(forKey: "resume.date") ?? "",
            description: d.string(forKey: "resume.description") ?? "",
            imageURL: d.string(forKey: "resume.imageURL").flatMap(URL.init(string:))
        )
        continueListening = ResumeState(show: show, episode: episode, position: d.double(forKey: "resume.position"))
    }

    private func clearResumeState() {
        let d = UserDefaults.standard
        for key in ["resume.showSlug", "resume.audioURL", "resume.title", "resume.number",
                    "resume.date", "resume.description", "resume.imageURL", "resume.position"] {
            d.removeObject(forKey: key)
        }
        continueListening = nil
    }

    // MARK: - Sleep Timer

    /// When the current sleep timer fires, or nil if none is active.
    public private(set) var sleepTimerEnd: Date?
    @ObservationIgnored private var sleepTask: Task<Void, Never>?

    public func startSleepTimer(minutes: Int) {
        sleepTask?.cancel()
        sleepTimerEnd = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(minutes * 60))
            guard !Task.isCancelled else { return }
            engine.pause()
            sleepTimerEnd = nil
            updateNowPlaying()
        }
    }

    public func cancelSleepTimer() {
        sleepTask?.cancel()
        sleepTask = nil
        sleepTimerEnd = nil
    }

    // MARK: - Lock Screen / Control Center Artwork

    @ObservationIgnored private var artworkURL: URL?
    @ObservationIgnored private var artwork: MPMediaItemArtwork?

    /// Fetch the current show's cover once per show change and republish
    /// Now Playing info with it. Cached by URL; a stale fetch (user switched
    /// shows mid-download) is discarded.
    private func loadArtwork(for url: URL?) {
        guard url != artworkURL else { return }
        artworkURL = url
        artwork = nil
        guard let url else { return }
        Task { @MainActor in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  url == self.artworkURL else { return }
            #if canImport(UIKit)
            guard let image = UIImage(data: data) else { return }
            #elseif canImport(AppKit)
            guard let image = NSImage(data: data) else { return }
            #endif
            self.artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            self.updateNowPlaying()
        }
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
