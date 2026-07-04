// NowPlayingView.swift — full player sheet: artwork, seek, skip, AirPlay
// Monocle Radio — iOS player for Monocle 24

import SwiftUI
import AVKit
import MonocleRadioKit

struct NowPlayingView: View {
    @Bindable var viewModel: RadioViewModel
    @State private var isScrubbing = false
    @State private var scrubProgress: Double = 0

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            CoverArt(url: viewModel.currentCoverURL, size: 280, cornerRadius: 12)
                .shadow(color: .black.opacity(0.25), radius: 14, y: 8)

            VStack(spacing: 6) {
                Text(viewModel.currentShow?.name ?? "Monocle 24")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(viewModel.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 24)

            if viewModel.isLive {
                LiveBadge()
            } else {
                scrubber
            }

            transportControls

            AirPlayButton()
                .frame(width: 44, height: 44)

            Spacer(minLength: 12)
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Scrubber (on-demand)

    private var scrubber: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubProgress : viewModel.progress },
                    set: { scrubProgress = $0 }
                ),
                in: 0...1
            ) { editing in
                if editing {
                    scrubProgress = viewModel.progress
                } else {
                    viewModel.seek(to: scrubProgress * viewModel.engine.duration)
                }
                isScrubbing = editing
            }
            .tint(Color.monocleGold)
            .accessibilityLabel("Playback position")

            HStack {
                Text(viewModel.elapsedString)
                Spacer()
                Text(viewModel.durationString)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Transport

    private var transportControls: some View {
        HStack(spacing: 44) {
            if !viewModel.isLive {
                Button { viewModel.skip(by: -15) } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title)
                        .frame(width: 52, height: 52)
                }
                .accessibilityLabel("Skip back 15 seconds")
            }

            Button { viewModel.togglePlayPause() } label: {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 68))
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")

            if !viewModel.isLive {
                Button { viewModel.skip(by: 15) } label: {
                    Image(systemName: "goforward.15")
                        .font(.title)
                        .frame(width: 52, height: 52)
                }
                .accessibilityLabel("Skip forward 15 seconds")
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}

// MARK: - AirPlay

private struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = .secondaryLabel
        view.activeTintColor = UIColor(named: "AccentColor") ?? .tintColor
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
