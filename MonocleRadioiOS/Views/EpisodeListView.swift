// EpisodeListView.swift — episode list for a show, plus the live stream detail pane
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
                    ForEach(viewModel.episodes) { episode in
                        EpisodeRow(
                            episode: episode,
                            isNowPlaying: viewModel.currentEpisode == episode && viewModel.isPlaying
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.play(episode, from: show) }
                    }
                }
                .listStyle(.plain)
                .refreshable { viewModel.retryEpisodes() }
            }
        }
        .navigationTitle(show.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ShowHeader: View {
    let show: Show

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AsyncImage(url: show.coverURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.secondary.opacity(0.1)
                }
            }
            .aspectRatio(822.0 / 616.0, contentMode: .fit)
            .frame(maxWidth: 300)
            .clipShape(RoundedRectangle(cornerRadius: 10))

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

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isNowPlaying ? "speaker.wave.2.fill" : "play.circle")
                .foregroundStyle(isNowPlaying ? Color.monocleGold : Color.secondary)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(episode.title)
                    .font(.subheadline)
                    .fontWeight(isNowPlaying ? .semibold : .regular)
                if !episode.number.isEmpty || !episode.date.isEmpty {
                    HStack(spacing: 8) {
                        if !episode.number.isEmpty { Text(episode.number) }
                        if !episode.date.isEmpty { Text(episode.date) }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Plays this episode")
    }
}

// MARK: - Live Detail

struct LiveDetailView: View {
    @Bindable var viewModel: RadioViewModel
    let show: Show

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LiveBadge()

            Text(show.name)
                .font(.largeTitle.bold())

            Text(show.description)
                .foregroundStyle(.secondary)

            if !viewModel.streamTitle.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ON AIR")
                        .font(.caption2.weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(.tertiary)
                    Text(viewModel.streamTitle)
                        .font(.headline)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .navigationTitle("Monocle 24")
        .navigationBarTitleDisplayMode(.inline)
    }
}
