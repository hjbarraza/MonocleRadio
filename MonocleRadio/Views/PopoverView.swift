// PopoverView.swift — All UI: now playing card, show list, episode list, footer
// Monocle Radio — macOS menu bar player for Monocle 24

import SwiftUI
import ServiceManagement

// MARK: - Monocle Gold Accent

private let monocleGold = Color(red: 0.784, green: 0.647, blue: 0.353)  // #C8A55A

// MARK: - Root Popover View

struct PopoverView: View {
    @Bindable var viewModel: RadioViewModel

    var body: some View {
        VStack(spacing: 0) {
            NowPlayingCard(viewModel: viewModel)
            Divider()
            BrowserView(viewModel: viewModel)
            Divider()
            FooterView(volume: Binding(
                get: { viewModel.volume },
                set: { viewModel.volume = $0 }
            ))
        }
        .background(.regularMaterial)
    }
}

// MARK: - Now Playing Card

private struct NowPlayingCard: View {
    @Bindable var viewModel: RadioViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Cover art
            AsyncImage(url: viewModel.currentCoverURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "radio")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.secondary.opacity(0.1))
                default:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Info
            VStack(alignment: .leading, spacing: 3) {
                // Status dot + show name
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.statusColor)
                        .frame(width: 8, height: 8)
                    Text(viewModel.currentShow?.name ?? "Monocle 24")
                        .font(.headline)
                        .lineLimit(1)
                }

                // Subtitle (episode title or ICY metadata)
                Text(viewModel.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Progress bar (on-demand only)
                if !viewModel.isLive && viewModel.isPlaying {
                    ProgressBar(
                        progress: viewModel.progress,
                        elapsed: viewModel.elapsedString,
                        duration: viewModel.durationString
                    )
                }
            }

            Spacer()

            // Play/pause button
            Button { viewModel.togglePlayPause() } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
        }
        .padding(12)
    }
}

// MARK: - Progress Bar

private struct ProgressBar: View {
    let progress: Double
    let elapsed: String
    let duration: String

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 3)
                    Capsule()
                        .fill(monocleGold)
                        .frame(width: max(0, geo.size.width * min(progress, 1.0)), height: 3)
                }
            }
            .frame(height: 3)

            HStack {
                Text(elapsed).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text(duration).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Browser (Show List + Episode List)

private struct BrowserView: View {
    @Bindable var viewModel: RadioViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Shows sidebar
            ShowListView(
                shows: viewModel.shows,
                selectedShow: viewModel.selectedShow,
                currentShow: viewModel.currentShow,
                isPlaying: viewModel.isPlaying
            ) { show in
                viewModel.selectShow(show)
            }
            .frame(width: 140)

            Divider()

            // Episodes
            EpisodeListView(
                episodes: viewModel.episodes,
                selectedShow: viewModel.selectedShow,
                currentEpisode: viewModel.currentEpisode,
                isLoading: viewModel.isLoadingEpisodes,
                error: viewModel.episodeError,
                isPlaying: viewModel.isPlaying
            ) { episode in
                if let show = viewModel.selectedShow {
                    viewModel.play(episode, from: show)
                }
            } onRetry: {
                viewModel.retryEpisodes()
            }
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Show List

private struct ShowListView: View {
    let shows: [Show]
    let selectedShow: Show?
    let currentShow: Show?
    let isPlaying: Bool
    let onSelect: (Show) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(shows) { show in
                    ShowRow(
                        show: show,
                        isSelected: selectedShow == show,
                        isNowPlaying: currentShow == show && isPlaying
                    )
                    .onTapGesture { onSelect(show) }
                }
            }
        }
    }
}

private struct ShowRow: View {
    let show: Show
    let isSelected: Bool
    let isNowPlaying: Bool

    var body: some View {
        HStack(spacing: 6) {
            if isNowPlaying {
                Circle()
                    .fill(show.isLive ? .red : monocleGold)
                    .frame(width: 6, height: 6)
            } else if show.isLive {
                Circle()
                    .fill(.red.opacity(0.5))
                    .frame(width: 6, height: 6)
            } else {
                Spacer().frame(width: 6)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(show.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                Text(show.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.12) : .clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Episode List

private struct EpisodeListView: View {
    let episodes: [Episode]
    let selectedShow: Show?
    let currentEpisode: Episode?
    let isLoading: Bool
    let error: String?
    let isPlaying: Bool
    let onSelect: (Episode) -> Void
    let onRetry: () -> Void

    var body: some View {
        Group {
            if selectedShow == nil {
                // No show selected
                VStack {
                    Spacer()
                    Text("Select a show")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if selectedShow?.isLive == true {
                // Live stream — no episodes
                VStack {
                    Spacer()
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Live Stream")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading...")
                        .font(.caption)
                    Spacer()
                }
            } else if let error {
                VStack(spacing: 8) {
                    Spacer()
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { onRetry() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Spacer()
                }
                .padding()
            } else if episodes.isEmpty {
                VStack {
                    Spacer()
                    Text("No episodes found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                // Episode list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Header
                        if let show = selectedShow {
                            Text("EPISODES \u{00B7} \(show.name)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 8)
                                .padding(.top, 6)
                                .padding(.bottom, 4)
                        }

                        ForEach(episodes) { episode in
                            EpisodeRow(
                                episode: episode,
                                isNowPlaying: currentEpisode == episode && isPlaying
                            )
                            .onTapGesture { onSelect(episode) }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EpisodeRow: View {
    let episode: Episode
    let isNowPlaying: Bool

    var body: some View {
        HStack(spacing: 6) {
            if isNowPlaying {
                Circle()
                    .fill(monocleGold)
                    .frame(width: 6, height: 6)
            } else {
                Spacer().frame(width: 6)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if !episode.number.isEmpty {
                        Text(episode.number)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Text(episode.title)
                        .font(.caption)
                        .fontWeight(isNowPlaying ? .semibold : .regular)
                        .lineLimit(1)
                }
                if !episode.date.isEmpty {
                    Text(episode.date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isNowPlaying ? monocleGold.opacity(0.1) : .clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Footer (Volume + Launch at Login + Quit)

private struct FooterView: View {
    @Binding var volume: Double
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        HStack(spacing: 8) {
            // Volume
            Image(systemName: "speaker.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Slider(value: $volume, in: 0...100)
                .controlSize(.mini)
                .frame(width: 80)

            Spacer()

            // Launch at Login
            Toggle("Login", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .onChange(of: launchAtLogin) { _, on in
                    try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }

            // Quit
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit Monocle Radio")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
