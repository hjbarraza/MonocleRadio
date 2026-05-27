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
                isPlaying: viewModel.isPlaying,
                streamTitle: viewModel.streamTitle
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
                let live = shows.filter(\.isLive)
                let onDemand = shows.filter { !$0.isLive }

                if !live.isEmpty {
                    SectionLabel("LIVE")
                    ForEach(live) { row(for: $0) }
                }
                if !onDemand.isEmpty {
                    SectionLabel("ON DEMAND")
                    ForEach(onDemand) { row(for: $0) }
                }
            }
        }
    }

    private func row(for show: Show) -> some View {
        ShowRow(
            show: show,
            isSelected: selectedShow == show,
            isNowPlaying: currentShow == show && isPlaying
        )
        .onTapGesture { onSelect(show) }
    }
}

private struct SectionLabel: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 3)
    }
}

private struct ShowRow: View {
    let show: Show
    let isSelected: Bool
    let isNowPlaying: Bool
    @State private var isHovered = false

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

            Text(show.name)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected ? Color.accentColor.opacity(0.12)
            : isHovered ? Color.primary.opacity(0.04)
            : .clear
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
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
    let streamTitle: String
    let onSelect: (Episode) -> Void
    let onRetry: () -> Void

    var body: some View {
        Group {
            if selectedShow == nil {
                centered { Text("Select a show").font(.subheadline).foregroundStyle(.secondary) }
            } else if let show = selectedShow, show.isLive {
                LivePane(show: show, streamTitle: streamTitle)
            } else if isLoading {
                centered { ProgressView("Loading…").font(.caption) }
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
                centered { Text("No episodes found").font(.subheadline).foregroundStyle(.secondary) }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if let show = selectedShow {
                            EpisodeHeader(show: show)
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

    @ViewBuilder
    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack { Spacer(); content(); Spacer() }
    }
}

private struct EpisodeHeader: View {
    let show: Show
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(show.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
            Text(show.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LivePane: View {
    let show: Show
    let streamTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(.red).frame(width: 7, height: 7)
                Text("LIVE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(.red)
            }

            Text(show.name)
                .font(.headline)

            Text(show.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !streamTitle.isEmpty {
                Divider().padding(.vertical, 2)
                Text("ON AIR")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.tertiary)
                Text(streamTitle)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EpisodeRow: View {
    let episode: Episode
    let isNowPlaying: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Leading indicator: now-playing dot, hover ▶, or nothing
            ZStack {
                if isNowPlaying {
                    Circle().fill(monocleGold).frame(width: 6, height: 6)
                } else if isHovered {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 10, height: 14)
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(episode.title)
                    .font(.caption)
                    .fontWeight(isNowPlaying ? .semibold : .regular)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !episode.number.isEmpty || !episode.date.isEmpty {
                    HStack(spacing: 6) {
                        if !episode.number.isEmpty {
                            Text(episode.number)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        if !episode.date.isEmpty {
                            Text(episode.date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isNowPlaying ? monocleGold.opacity(0.1)
            : isHovered ? Color.primary.opacity(0.05)
            : .clear
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
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
            Toggle("Start at login", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .help("Launch Monocle Radio automatically when you log in")
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
