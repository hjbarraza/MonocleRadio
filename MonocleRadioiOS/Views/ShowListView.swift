// ShowListView.swift — sidebar/root list of the live stream and on-demand shows
// Monocle Radio — iOS player for Monocle 24

import SwiftUI
import MonocleRadioKit

struct ShowListView: View {
    @Bindable var viewModel: RadioViewModel

    var body: some View {
        List(selection: $viewModel.selectedShow) {
            Section("Live") {
                ForEach(viewModel.shows.filter(\.isLive)) { show in
                    row(for: show)
                }
            }
            Section("On Demand") {
                ForEach(viewModel.shows.filter { !$0.isLive }) { show in
                    row(for: show)
                }
            }
        }
        .navigationTitle("Monocle Radio")
    }

    private func row(for show: Show) -> some View {
        ShowRow(
            show: show,
            isNowPlaying: viewModel.currentShow == show && viewModel.isPlaying
        )
        .tag(show)
    }
}

private struct ShowRow: View {
    let show: Show
    let isNowPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            CoverArt(url: show.coverURL, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(show.name)
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
                    .foregroundStyle(show.isLive ? Color.red : Color.monocleGold)
                    .accessibilityLabel("Now playing")
            } else if show.isLive {
                Circle().fill(.red).frame(width: 7, height: 7)
            }
        }
        .padding(.vertical, 2)
    }
}
