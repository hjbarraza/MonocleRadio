// ContentView.swift — watch UI: Cover, Schedule, Shows, system Now Playing
// Monocle Radio — Apple Watch player for Monocle 24
//
// Editorial language per DESIGN.md, adapted to the wrist: ink is the native
// canvas, serif titles, red means live, gold for playback.

import SwiftUI
import WatchKit
import MonocleRadioKit

// MARK: - Palette (watch target keeps its own copy of the tokens)

extension Color {
    static let monocleGold = Color(red: 0.784, green: 0.647, blue: 0.353)
    static let monocleRed = Color(red: 0.804, green: 0.114, blue: 0.114)
    static let paperWhite = Color(red: 0.980, green: 0.969, blue: 0.945)
}

/// Wrist haptics — the watch is the one device that touches skin.
enum WatchHaptics {
    static func tap() { WKInterfaceDevice.current().play(.click) }
    static func start() { WKInterfaceDevice.current().play(.start) }
    static func success() { WKInterfaceDevice.current().play(.success) }
}

struct Kicker: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.3)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

/// 4:3 cover thumb, wrist-sized.
struct WatchCoverArt: View {
    let url: URL?
    var width: CGFloat = 42

    var body: some View {
        AsyncImage(url: url) { phase in
            if case .success(let image) = phase {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                Color.white.opacity(0.08)
            }
        }
        .frame(width: width, height: width * 616 / 822)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Root

struct ContentView: View {
    @Bindable var viewModel: RadioViewModel
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            CoverPage(viewModel: viewModel).tag(0)
            SchedulePage(viewModel: viewModel).tag(1)
            ShowsPage(viewModel: viewModel).tag(2)
            NowPlayingView().tag(3)   // system player: volume crown, route picker
        }
        .tabViewStyle(.verticalPage)
        .onChange(of: viewModel.currentEpisode) { _, episode in
            // Starting an episode lands you on the full-screen cover
            if episode != nil { withAnimation { selection = 0 } }
        }
    }
}

// MARK: - Cover (full-bleed current artwork, tap to play/pause or resume)

private struct CoverPage: View {
    @Bindable var viewModel: RadioViewModel

    /// Paused, nothing loaded beyond the default live selection, and a saved
    /// position exists — the raise-and-tap should continue, not restart live.
    private var resumable: RadioViewModel.ResumeState? {
        guard !viewModel.isPlaying, viewModel.currentEpisode == nil else { return nil }
        return viewModel.continueListening
    }

    private var artURL: URL? {
        if let resume = resumable {
            return resume.episode.imageURL ?? resume.show.coverURL
        }
        if let episode = viewModel.currentEpisode, let image = episode.imageURL {
            return image
        }
        return viewModel.currentCoverURL
    }

    private var titleLine: String {
        if let resume = resumable { return resume.episode.title }
        if !viewModel.subtitle.isEmpty { return viewModel.subtitle }
        return viewModel.currentShow?.name ?? "Monocle 24"
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                AsyncImage(url: artURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.white.opacity(0.06)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.85), .black.opacity(0.35), .clear],
                    startPoint: .bottom, endPoint: .center
                )
                .frame(height: geo.size.height * 0.6)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        if viewModel.isLive && resumable == nil {
                            Circle()
                                .fill(viewModel.isPlaying ? Color.monocleRed : Color.secondary)
                                .frame(width: 6, height: 6)
                        }
                        Kicker(
                            text: resumable != nil ? "Continue"
                                : viewModel.isBuffering ? "Loading"
                                : viewModel.isPlaying ? (viewModel.isLive ? "On Air" : "Playing")
                                : "Paused",
                            color: viewModel.isLive && viewModel.isPlaying ? .monocleRed : .monocleGold
                        )
                        if !viewModel.isPlaying && !viewModel.isBuffering {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.paperWhite.opacity(0.7))
                        }
                    }
                    Text(titleLine)
                        .font(.system(.footnote, design: .serif).weight(.semibold))
                        .foregroundStyle(Color.paperWhite)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
            if resumable != nil {
                WatchHaptics.success()
                viewModel.resumeContinueListening()
            } else {
                WatchHaptics.tap()
                viewModel.togglePlayPause()
            }
        }
        .accessibilityLabel(resumable != nil ? "Continue listening"
                            : viewModel.isPlaying ? "Pause" : "Play")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Schedule (today's programme, NOW marker, local times)

private struct SchedulePage: View {
    @Bindable var viewModel: RadioViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.schedule.isEmpty {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Loading programme…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List(viewModel.schedule) { entry in
                        ScheduleRow(
                            entry: entry,
                            isNow: viewModel.onAirNow == entry,
                            isPast: entry.time < Date() && viewModel.onAirNow != entry,
                            show: show(for: entry),
                            viewModel: viewModel
                        )
                    }
                }
            }
            .navigationTitle("Schedule")
        }
        .task { viewModel.loadSchedule() }
    }

    private func show(for entry: ScheduleEntry) -> Show? {
        viewModel.shows.first { !$0.isLive && $0.name.caseInsensitiveCompare(entry.title) == .orderedSame }
    }
}

private struct ScheduleRow: View {
    let entry: ScheduleEntry
    let isNow: Bool
    let isPast: Bool
    let show: Show?
    @Bindable var viewModel: RadioViewModel

    private var label: some View {
        HStack(spacing: 8) {
            Text(entry.time, format: .dateTime.hour().minute())
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(isNow ? Color.monocleRed : isPast ? Color.secondary : Color.monocleGold)
                .frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                if isNow {
                    Kicker(text: "Now", color: .monocleRed)
                }
                Text(entry.title)
                    .font(.system(.footnote, design: .serif).weight(isNow ? .bold : .semibold))
                    .foregroundStyle(isPast ? Color.secondary : Color.paperWhite)
                    .lineLimit(2)
            }
        }
        .opacity(isPast ? 0.55 : 1)
    }

    var body: some View {
        if let show {
            NavigationLink { EpisodesPage(viewModel: viewModel, show: show) } label: { label }
        } else {
            label
        }
    }
}

// MARK: - Shows (desk sections)

private struct ShowsPage: View {
    @Bindable var viewModel: RadioViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(Desk.allCases, id: \.self) { desk in
                    let deskShows = viewModel.shows.filter { !$0.isLive && $0.desk == desk }
                    if !deskShows.isEmpty {
                        Section {
                            ForEach(deskShows) { show in
                                NavigationLink {
                                    EpisodesPage(viewModel: viewModel, show: show)
                                } label: {
                                    HStack(spacing: 8) {
                                        WatchCoverArt(url: show.coverURL)
                                        Text(show.name)
                                            .font(.system(.footnote, design: .serif).weight(.semibold))
                                            .lineLimit(2)
                                    }
                                }
                            }
                        } header: {
                            Kicker(text: desk.rawValue)
                        }
                    }
                }
            }
            .navigationTitle("Shows")
        }
    }
}

private struct EpisodesPage: View {
    @Bindable var viewModel: RadioViewModel
    let show: Show

    var body: some View {
        Group {
            if viewModel.isLoadingEpisodes {
                ProgressView()
            } else if viewModel.episodes.isEmpty {
                Text(viewModel.episodeError ?? "No episodes right now.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                List(viewModel.episodes) { episode in
                    Button {
                        WatchHaptics.start()
                        viewModel.play(episode, from: show)
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            if let image = episode.imageURL {
                                WatchCoverArt(url: image)
                                    .padding(.top, 2)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(episode.title)
                                    .font(.system(.footnote, design: .serif).weight(.semibold))
                                    .lineLimit(3)
                                HStack(spacing: 5) {
                                    if viewModel.currentEpisode == episode && viewModel.isPlaying {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.monocleGold)
                                    }
                                    if !episode.date.isEmpty {
                                        Text(episode.displayDate)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .disabled(episode.audioURL == nil)
                }
            }
        }
        .navigationTitle(show.name)
        .task { viewModel.selectShow(show, autoplayLive: false) }
    }
}
