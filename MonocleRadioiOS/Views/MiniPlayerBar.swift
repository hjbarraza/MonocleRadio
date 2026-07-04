// MiniPlayerBar.swift — persistent bottom bar: cover, title, play/pause
// Monocle Radio — iOS player for Monocle 24

import SwiftUI
import MonocleRadioKit

struct MiniPlayerBar: View {
    @Bindable var viewModel: RadioViewModel
    let namespace: Namespace.ID
    let onExpand: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Thin progress line (on-demand only)
            if !viewModel.isLive, viewModel.progress > 0 {
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.monocleGold)
                        .frame(width: geo.size.width * min(viewModel.progress, 1))
                }
                .frame(height: 2)
                .background(Color.secondary.opacity(0.2))
            }

            HStack(spacing: 12) {
                CoverArt(url: viewModel.currentCoverURL, width: 53)
                    .matchedGeometryEffect(id: "player-artwork", in: namespace)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        if viewModel.isLive {
                            Circle()
                                .fill(viewModel.isPlaying ? Color.monocleRed : Color.secondary)
                                .frame(width: 6, height: 6)
                        }
                        Text(viewModel.currentShow?.name ?? "Monocle 24")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                    Text(viewModel.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    Haptics.play()
                    viewModel.togglePlayPause()
                } label: {
                    if viewModel.isBuffering {
                        ProgressView()
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 44, height: 44)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial)
        .contentShape(Rectangle())
        .onTapGesture { onExpand() }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the full player")
    }
}
