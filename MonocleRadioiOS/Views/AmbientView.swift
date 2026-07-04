// AmbientView.swift — iPad kitchen-counter mode: full-bleed art, clock, ON AIR
// Monocle Radio — iOS player for Monocle 24

import SwiftUI
import MonocleRadioKit

/// Full-screen ambient surface for a propped-up iPad: blurred artwork wash,
/// serif clock, what's on air, and a single transport control. Tap anywhere
/// to leave. Keeps the screen awake while visible.
struct AmbientView: View {
    @Bindable var viewModel: RadioViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ArtworkAmbiance(url: viewModel.currentCoverURL, scrim: 0.55)

                VStack(spacing: 28) {
                    Spacer()

                    TimelineView(.everyMinute) { context in
                        Text(context.date, format: .dateTime.hour().minute())
                            .font(.system(size: 96, weight: .medium, design: .serif))
                            .foregroundStyle(Color.paperWhite)
                            .monospacedDigit()
                    }

                    CoverArt(
                        url: viewModel.currentCoverURL,
                        width: min(geo.size.width * 0.32, 360),
                        cornerRadius: 12
                    )
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 10)

                    VStack(spacing: 8) {
                        if viewModel.isLive {
                            LiveBadge(active: viewModel.isPlaying)
                        }
                        Kicker(text: viewModel.isLive ? "On Air" : "Now Playing", color: .monocleGold)
                        Text(viewModel.subtitle.isEmpty
                             ? (viewModel.currentShow?.name ?? "Monocle 24")
                             : viewModel.subtitle)
                            .font(.system(.title3, design: .serif).weight(.semibold))
                            .foregroundStyle(Color.paperWhite)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 48)
                    }

                    Button { viewModel.togglePlayPause() } label: {
                        if viewModel.isBuffering {
                            ProgressView()
                                .tint(Color.paperWhite)
                                .frame(width: 56, height: 56)
                        } else {
                            Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(Color.paperWhite)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")

                    Spacer()
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .statusBarHidden()
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .accessibilityAction(.escape) { dismiss() }
    }
}
