// EpisodeListView.swift — episode list for a show, plus the live destination
// Monocle Radio — iOS player for Monocle 24

import SwiftUI
import MonocleRadioKit

struct EpisodeListView: View {
    @Bindable var viewModel: RadioViewModel
    let show: Show

    var body: some View {
        Group {
            if viewModel.isLoadingEpisodes {
                ProgressView("Loading episodes…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.episodeError != nil {
                ContentUnavailableView {
                    Label("Could not load episodes", systemImage: "wifi.exclamationmark")
                } description: {
                    Text("Check your connection and try again.")
                } actions: {
                    Button("Retry") { viewModel.retryEpisodes() }
                        .buttonStyle(.borderedProminent)
                }
            } else if viewModel.episodes.isEmpty {
                ContentUnavailableView(
                    "No episodes found",
                    systemImage: "questionmark.circle",
                    description: Text("This show has no episodes right now.")
                )
            } else {
                List {
                    ShowHeader(show: show)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.paper)
                    ForEach(viewModel.episodes) { episode in
                        EpisodeRow(
                            episode: episode,
                            isNowPlaying: viewModel.currentEpisode == episode && viewModel.isPlaying,
                            isBuffering: viewModel.currentEpisode == episode && viewModel.isBuffering
                        ) {
                            Haptics.play()
                            viewModel.play(episode, from: show)
                        }
                        .listRowBackground(Color.paper)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.paper)
                .refreshable { viewModel.retryEpisodes() }
            }
        }
        .background(Color.paper)
        .navigationTitle(show.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ShowHeader: View {
    let show: Show

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Color.clear
                .aspectRatio(CoverArt.aspect, contentMode: .fit)
                .overlay {
                    AsyncImage(url: show.coverURL) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.secondary.opacity(0.1)
                        }
                    }
                }
                .frame(maxWidth: 340)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(show.name)
                .font(.showTitle)
            Text(show.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct EpisodeRow: View {
    let episode: Episode
    let isNowPlaying: Bool
    let isBuffering: Bool
    let onPlay: () -> Void

    private var downloads: DownloadStore { .shared }

    private var playable: Bool { episode.audioURL != nil }

    var body: some View {
        Button(action: onPlay) {
            HStack(alignment: .top, spacing: 12) {
                if let image = episode.imageURL {
                    CoverArt(url: image, width: 76, cornerRadius: 5)
                        .padding(.top, 2)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title)
                        .font(.entryTitle)
                        .fontWeight(isNowPlaying ? .bold : .semibold)
                        .foregroundStyle(playable ? Color.primary : Color.secondary)
                        .multilineTextAlignment(.leading)
                    if !episode.description.isEmpty {
                        Text(episode.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    HStack(spacing: 8) {
                        if !episode.date.isEmpty { Text(episode.displayDate) }
                        if !episode.number.isEmpty { Text(episode.number) }
                        if downloads.revision >= 0, downloads.isDownloaded(episode) {
                            Kicker(text: "Downloaded", color: .monocleGold)
                        }
                        if !playable {
                            Kicker(text: "Unavailable")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
                if isBuffering {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 2)
                } else if isNowPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundStyle(Color.monocleGold)
                        .padding(.top, 4)
                        .accessibilityHidden(true)
                }
                if playable {
                    downloadControl
                }
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .disabled(!playable)
        .opacity(playable ? 1 : 0.55)
        .accessibilityHint(playable ? "Plays this episode" : "Episode unavailable")
    }

    @ViewBuilder
    private var downloadControl: some View {
        if let key = episode.audioURL?.absoluteString, let fraction = downloads.progress[key] {
            ProgressView(value: max(fraction, 0.02))
                .progressViewStyle(.circular)
                .controlSize(.small)
                .tint(Color.monocleGold)
                .padding(.top, 2)
                .accessibilityLabel("Downloading")
        } else if downloads.isDownloaded(episode) {
            Button {
                downloads.remove(episode)
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(Color.monocleGold)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove download")
        } else {
            Button {
                Haptics.tick()
                downloads.download(episode)
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Download episode")
        }
    }
}

// MARK: - Live Destination

/// The live pane as a real place: ink surface, artwork, ON AIR, transport.
struct LiveDetailView: View {
    @Bindable var viewModel: RadioViewModel
    let show: Show

    private var isCurrentAndPlaying: Bool {
        viewModel.currentShow == show && viewModel.isPlaying
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    CoverArt(
                        url: show.coverURL,
                        width: min(geo.size.width - 48, 480),
                        cornerRadius: 12
                    )
                    .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 6) {
                        LiveBadge(active: isCurrentAndPlaying)
                        Text("Monocle 24")
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundStyle(Color.paperWhite)
                        Text(show.description)
                            .font(.subheadline)
                            .foregroundStyle(Color.paperWhite.opacity(0.65))
                    }

                    if !viewModel.streamTitle.isEmpty || viewModel.onAirNow != nil {
                        VStack(alignment: .leading, spacing: 4) {
                            Kicker(text: "On Air", color: Color.monocleGold)
                            Text(viewModel.streamTitle.isEmpty
                                 ? (viewModel.onAirNow?.title ?? "")
                                 : viewModel.streamTitle)
                                .font(.system(.headline, design: .serif))
                                .foregroundStyle(Color.paperWhite)
                        }
                    }

                    if let next = viewModel.upNext {
                        VStack(alignment: .leading, spacing: 4) {
                            Kicker(text: "Up Next")
                            HStack(spacing: 8) {
                                Text(next.time, format: .dateTime.hour().minute())
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.monocleGold)
                                Text(next.title)
                                    .font(.system(.subheadline, design: .serif))
                                    .foregroundStyle(Color.paperWhite.opacity(0.85))
                            }
                        }
                    }

                    Button {
                        Haptics.play()
                        if viewModel.currentShow == show {
                            viewModel.togglePlayPause()
                        } else {
                            viewModel.playLive()
                        }
                    } label: {
                        ZStack {
                            Circle().fill(Color.paperWhite)
                            if viewModel.isBuffering && viewModel.currentShow == show {
                                ProgressView().tint(Color.ink)
                            } else {
                                Image(systemName: isCurrentAndPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 30))
                                    .foregroundStyle(Color.ink)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                        }
                        .frame(width: 76, height: 76)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .accessibilityLabel(isCurrentAndPlaying ? "Pause live radio" : "Play live radio")

                    if let error = viewModel.engine.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.monocleRed)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.ink.ignoresSafeArea())
        .navigationTitle("Monocle 24")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { viewModel.loadSchedule() }
    }
}
