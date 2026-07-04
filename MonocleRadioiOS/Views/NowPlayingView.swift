// NowPlayingView.swift — full player sheet: adaptive layout, blurred-artwork
// ambiance, seek, skip, sleep timer, AirPlay, ambient mode (iPad)
// Monocle Radio — iOS player for Monocle 24

import SwiftUI
import AVKit
import MonocleRadioKit

struct NowPlayingView: View {
    @Bindable var viewModel: RadioViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var isScrubbing = false
    @State private var scrubProgress: Double = 0
    @State private var showAmbient = false

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height

            Group {
                if wide {
                    HStack(spacing: 40) {
                        artwork(in: geo, wide: true)
                        VStack(spacing: 24) {
                            titleBlock
                            statusOrScrubber
                            transportControls
                            utilityRow
                        }
                        .frame(maxWidth: 420)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 26) {
                        Spacer(minLength: 8)
                        artwork(in: geo, wide: false)
                        titleBlock
                        statusOrScrubber
                        transportControls
                        utilityRow
                        Spacer(minLength: 8)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(ArtworkAmbiance(url: viewModel.currentCoverURL))
        .environment(\.colorScheme, .dark)
        .presentationDragIndicator(.visible)
        .fullScreenCover(isPresented: $showAmbient) {
            AmbientView(viewModel: viewModel)
        }
    }

    // MARK: - Artwork

    private func artwork(in geo: GeometryProxy, wide: Bool) -> some View {
        let width = wide
            ? min(geo.size.width * 0.45, 460)
            : min(geo.size.width - 72, geo.size.height * 0.55 * CoverArt.aspect, 460)
        return CoverArt(url: viewModel.currentCoverURL, width: width, cornerRadius: 12)
            .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
            .overlay {
                if viewModel.isBuffering {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.ink.opacity(0.4))
                    ProgressView()
                        .tint(Color.paperWhite)
                }
            }
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text(viewModel.currentShow?.name ?? "Monocle 24")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .multilineTextAlignment(.center)
            Text(viewModel.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var statusOrScrubber: some View {
        if viewModel.isLive {
            LiveBadge(active: viewModel.isPlaying)
        } else {
            scrubber
        }
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
        .foregroundStyle(Color.paperWhite)
    }

    // MARK: - Sleep timer / AirPlay / Ambient

    private var utilityRow: some View {
        HStack(spacing: 36) {
            sleepTimerMenu

            AirPlayButton()
                .frame(width: 44, height: 44)

            if sizeClass == .regular {
                Button { showAmbient = true } label: {
                    Image(systemName: "moon.stars")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Ambient mode")
            }
        }
    }

    private var sleepTimerMenu: some View {
        Menu {
            if viewModel.sleepTimerEnd != nil {
                Button("Cancel timer", role: .destructive) { viewModel.cancelSleepTimer() }
            }
            ForEach([15, 30, 45, 60], id: \.self) { minutes in
                Button("\(minutes) minutes") { viewModel.startSleepTimer(minutes: minutes) }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "moon.zzz")
                    .font(.title3)
                if let end = viewModel.sleepTimerEnd {
                    Text(end, style: .timer)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
            }
            .frame(height: 44)
            .foregroundStyle(viewModel.sleepTimerEnd != nil ? Color.monocleGold : .secondary)
        }
        .accessibilityLabel(viewModel.sleepTimerEnd != nil ? "Sleep timer active" : "Sleep timer")
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
