// ContentView.swift — watch UI: Live page, show browser, system Now Playing
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

    var body: some View {
        TabView {
            CoverPage(viewModel: viewModel)
            LivePage(viewModel: viewModel)
            ShowsPage(viewModel: viewModel)
            NowPlayingView()   // system player: volume crown, route picker
        }
        .tabViewStyle(.verticalPage)
    }
}

// MARK: - Cover (full-bleed current artwork, tap to play/pause)

private struct CoverPage: View {
    @Bindable var viewModel: RadioViewModel

    private var artURL: URL? {
        if let episode = viewModel.currentEpisode, let image = episode.imageURL {
            return image
        }
        return viewModel.currentCoverURL
    }

    private var titleLine: String {
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
                        if viewModel.isLive {
                            Circle()
                                .fill(viewModel.isPlaying ? Color.monocleRed : Color.secondary)
                                .frame(width: 6, height: 6)
                        }
                        Kicker(
                            text: viewModel.isBuffering ? "Loading"
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
        .onTapGesture { viewModel.togglePlayPause() }
        .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Live

private struct LivePage: View {
    @Bindable var viewModel: RadioViewModel

    private var live: Show? { viewModel.shows.first(where: \.isLive) }
    private var isLivePlaying: Bool {
        viewModel.currentShow?.isLive == true && viewModel.isPlaying
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 5) {
                Circle()
                    .fill(isLivePlaying ? Color.monocleRed : Color.secondary)
                    .frame(width: 7, height: 7)
                Kicker(text: "Live", color: isLivePlaying ? .monocleRed : .secondary)
            }

            Text("Monocle 24")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(Color.paperWhite)

            Group {
                if !viewModel.streamTitle.isEmpty {
                    Text(viewModel.streamTitle)
                } else if let onAir = viewModel.onAirNow {
                    Text(onAir.title)
                } else {
                    Text("24/7 live radio")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .multilineTextAlignment(.center)

            Button {
                if viewModel.currentShow?.isLive == true {
                    viewModel.togglePlayPause()
                } else {
                    viewModel.playLive()
                }
            } label: {
                ZStack {
                    Circle().fill(Color.paperWhite)
                    if viewModel.isBuffering {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: isLivePlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(.black)
                    }
                }
                .frame(width: 52, height: 52)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isLivePlaying ? "Pause live radio" : "Play live radio")

            if let next = viewModel.upNext {
                HStack(spacing: 5) {
                    Text(next.time, format: .dateTime.hour().minute())
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.monocleGold)
                    Text(next.title)
                        .font(.system(size: 11, design: .serif))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .task { viewModel.loadSchedule() }
    }
}

// MARK: - Shows

private struct ShowsPage: View {
    @Bindable var viewModel: RadioViewModel

    var body: some View {
        NavigationStack {
            List(viewModel.shows.filter { !$0.isLive }) { show in
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
