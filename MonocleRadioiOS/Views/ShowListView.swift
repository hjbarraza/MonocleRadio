// ShowListView.swift — the front page: live masthead, continue listening, desks
// Monocle Radio — iOS player for Monocle 24

import SwiftUI
import MonocleRadioKit

struct ShowListView: View {
    @Bindable var viewModel: RadioViewModel
    @State private var searchText = ""

    private var liveShow: Show? { viewModel.shows.first(where: \.isLive) }

    private var searching: Bool { !searchText.isEmpty }

    private func shows(in desk: Desk) -> [Show] {
        viewModel.shows.filter { !$0.isLive && $0.desk == desk && matches($0) }
    }

    private func matches(_ show: Show) -> Bool {
        guard searching else { return true }
        return show.name.localizedCaseInsensitiveContains(searchText)
            || show.description.localizedCaseInsensitiveContains(searchText)
    }

    var body: some View {
        List(selection: $viewModel.selectedShow) {
            if !searching {
                masthead
                if let live = liveShow {
                    LiveHero(viewModel: viewModel, show: live)
                        .tag(live)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                if let resume = viewModel.continueListening,
                   viewModel.currentEpisode != resume.episode {
                    Section {
                        ContinueListeningRow(viewModel: viewModel, state: resume)
                            .listRowBackground(Color.paper)
                    } header: {
                        Kicker(text: "Continue Listening")
                    }
                }
            }

            ForEach(Desk.allCases, id: \.self) { desk in
                let deskShows = shows(in: desk)
                if !deskShows.isEmpty {
                    Section {
                        ForEach(deskShows) { show in
                            ShowRow(
                                show: show,
                                isNowPlaying: viewModel.currentShow == show && viewModel.isPlaying
                            )
                            .tag(show)
                            .listRowBackground(Color.paper)
                        }
                    } header: {
                        Kicker(text: desk.rawValue)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.paper)
        .searchable(text: $searchText, prompt: "Shows")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
    }

    private var masthead: some View {
        Text("Monocle Radio")
            .font(.masthead)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 2, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.paper)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Live Masthead Hero

/// The front page's cover: ink card, full-width art, explicit play control.
/// Tapping the card navigates to the live destination; only the play button
/// starts audio.
private struct LiveHero: View {
    @Bindable var viewModel: RadioViewModel
    let show: Show

    private var isCurrentAndPlaying: Bool {
        viewModel.currentShow == show && viewModel.isPlaying
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .aspectRatio(CoverArt.aspect, contentMode: .fit)
                .overlay {
                    AsyncImage(url: show.coverURL) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.paperWhite.opacity(0.06)
                        }
                    }
                }
                .clipped()

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    LiveBadge(active: isCurrentAndPlaying)
                    Text("Monocle 24")
                        .font(.showTitle)
                        .foregroundStyle(Color.paperWhite)
                    Text(onAirLine)
                        .font(.caption)
                        .foregroundStyle(Color.paperWhite.opacity(0.65))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
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
                                .font(.title3)
                                .foregroundStyle(Color.ink)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                    .frame(width: 46, height: 46)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isCurrentAndPlaying ? "Pause live radio" : "Play live radio")
            }
            .padding(16)
        }
        .background(Color.ink)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }

    private var onAirLine: String {
        if isCurrentAndPlaying, !viewModel.streamTitle.isEmpty {
            return viewModel.streamTitle
        }
        return show.description
    }
}

// MARK: - Continue Listening

private struct ContinueListeningRow: View {
    @Bindable var viewModel: RadioViewModel
    let state: RadioViewModel.ResumeState

    var body: some View {
        Button {
            viewModel.resumeContinueListening()
        } label: {
            HStack(spacing: 12) {
                CoverArt(url: state.episode.imageURL ?? state.show.coverURL, width: 59)
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.episode.title)
                        .font(.entryTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(state.show.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.monocleGold)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Resumes where you left off")
    }
}

// MARK: - Show Row

private struct ShowRow: View {
    let show: Show
    let isNowPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            CoverArt(url: show.coverURL, width: 59)
            VStack(alignment: .leading, spacing: 2) {
                Text(show.name)
                    .font(.entryTitle)
                    .lineLimit(1)
                Text(show.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if isNowPlaying {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundStyle(Color.monocleGold)
                    .accessibilityLabel("Now playing")
            }
        }
        .padding(.vertical, 3)
    }
}
