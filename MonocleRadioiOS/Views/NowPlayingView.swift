// NowPlayingView.swift — full player overlay: adaptive layout, blurred-artwork
// ambiance, seek, skip, sleep timer, AirPlay, ambient mode (iPad)
// Expands from the mini bar via matched geometry; drag down to collapse.
// Monocle Radio — iOS player for Monocle 24

import SwiftUI
import AVKit
import MonocleRadioKit

struct NowPlayingView: View {
    @Bindable var viewModel: RadioViewModel
    let namespace: Namespace.ID
    let onCollapse: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var isScrubbing = false
    @State private var scrubProgress: Double = 0
    @State private var lastDetentMinute = -1
    @State private var showAmbient = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            let dragProgress = min(max(dragOffset / geo.size.height, 0), 1)

            VStack(spacing: 0) {
                grabber

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
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .background(ArtworkAmbiance(url: viewModel.currentCoverURL))
            .clipShape(RoundedRectangle(cornerRadius: dragOffset > 0 ? 24 : 0))
            .scaleEffect(1 - dragProgress * 0.06)
            .offset(y: dragOffset)
            .gesture(collapseDrag(height: geo.size.height))
        }
        .environment(\.colorScheme, .dark)
        .ignoresSafeArea(edges: .bottom)
        .fullScreenCover(isPresented: $showAmbient) {
            AmbientView(viewModel: viewModel)
        }
    }

    // MARK: - Collapse gesture

    private var grabber: some View {
        Capsule()
            .fill(Color.paperWhite.opacity(0.35))
            .frame(width: 36, height: 5)
            .padding(.top, 14)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { collapse() }
            .accessibilityLabel("Close player")
            .accessibilityAddTraits(.isButton)
    }

    private func collapseDrag(height: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                let projected = value.predictedEndTranslation.height
                if dragOffset > height * 0.25 || projected > height * 0.6 {
                    collapse()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func collapse() {
        Haptics.tick()
        dragOffset = 0
        onCollapse()
    }

    // MARK: - Artwork

    private func artwork(in geo: GeometryProxy, wide: Bool) -> some View {
        let width = wide
            ? min(geo.size.width * 0.45, 460)
            : min(geo.size.width - 72, geo.size.height * 0.55 * CoverArt.aspect, 460)
        return CoverArt(url: viewModel.currentCoverURL, width: width, cornerRadius: 12)
            .matchedGeometryEffect(id: "player-artwork", in: namespace)
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
                    lastDetentMinute = -1
                } else {
                    viewModel.seek(to: scrubProgress * viewModel.engine.duration)
                }
                isScrubbing = editing
            }
            .tint(ArtworkPalette.shared.accent(for: viewModel.currentCoverURL))
            .accessibilityLabel("Playback position")
            .onChange(of: scrubProgress) { _, progress in
                // Minute-mark detents while scrubbing — the dial clicks
                guard isScrubbing, viewModel.engine.duration > 0 else { return }
                let minute = Int(progress * viewModel.engine.duration / 60)
                if minute != lastDetentMinute {
                    if lastDetentMinute >= 0 { Haptics.detent() }
                    lastDetentMinute = minute
                }
            }

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
                Button {
                    Haptics.tick()
                    viewModel.skip(by: -15)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title)
                        .frame(width: 52, height: 52)
                }
                .accessibilityLabel("Skip back 15 seconds")
            }

            Button {
                Haptics.play()
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 68))
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")

            if !viewModel.isLive {
                Button {
                    Haptics.tick()
                    viewModel.skip(by: 15)
                } label: {
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
                Button("\(minutes) minutes") {
                    Haptics.success()
                    viewModel.startSleepTimer(minutes: minutes)
                }
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
