// MonocleRadioWidgets.swift — Live Activity: lock screen banner + Dynamic Island
// Monocle Radio — iOS player for Monocle 24
//
// Editorial treatment per DESIGN.md: ink surface, serif titles, red = live,
// gold for playback marks. No animation — Live Activities render static trees.

import WidgetKit
import SwiftUI
import ActivityKit
import MonocleRadioKit

@main
struct MonocleRadioWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NowPlayingLiveActivity()
        OnAirWidget()
    }
}

// MARK: - Palette (extension targets don't share the app's Theme.swift)

private let ink = Color(red: 0.090, green: 0.082, blue: 0.070)
private let paperWhite = Color(red: 0.980, green: 0.969, blue: 0.945)
private let monocleGold = Color(red: 0.784, green: 0.647, blue: 0.353)
private let monocleRed = Color(red: 0.804, green: 0.114, blue: 0.114)

private struct StatusMark: View {
    let state: NowPlayingActivityAttributes.ContentState

    var body: some View {
        if state.isLive {
            Circle()
                .fill(state.isPlaying ? monocleRed : .secondary)
                .frame(width: 8, height: 8)
        } else {
            Image(systemName: state.isPlaying ? "waveform" : "pause.fill")
                .font(.caption2)
                .foregroundStyle(monocleGold)
        }
    }
}

// MARK: - Live Activity

struct NowPlayingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NowPlayingActivityAttributes.self) { context in
            // Lock screen / StandBy banner
            LockScreenView(state: context.state)
                .activityBackgroundTint(ink)
                .activitySystemActionForegroundColor(paperWhite)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    StatusMark(state: context.state)
                        .frame(width: 24, height: 24)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.title)
                            .font(.system(.subheadline, design: .serif).weight(.semibold))
                            .foregroundStyle(paperWhite)
                            .lineLimit(1)
                        if !context.state.subtitle.isEmpty {
                            Text(context.state.subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.isLive
                         ? (context.state.isPlaying ? "ON AIR" : "PAUSED")
                         : (context.state.isPlaying ? "NOW PLAYING" : "PAUSED"))
                        .font(.caption2.weight(.semibold))
                        .tracking(1.5)
                        .foregroundStyle(context.state.isLive && context.state.isPlaying
                                         ? monocleRed : .secondary)
                }
            } compactLeading: {
                StatusMark(state: context.state)
            } compactTrailing: {
                Image(systemName: context.state.isPlaying ? "radio" : "pause.fill")
                    .font(.caption2)
                    .foregroundStyle(paperWhite)
            } minimal: {
                StatusMark(state: context.state)
            }
        }
    }
}

// MARK: - Lock Screen

private struct LockScreenView: View {
    let state: NowPlayingActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    StatusMark(state: state)
                    Text(state.isLive
                         ? (state.isPlaying ? "On Air" : "Paused")
                         : (state.isPlaying ? "Now Playing" : "Paused"))
                        .font(.caption2.weight(.semibold))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(state.isLive && state.isPlaying ? monocleRed : .secondary)
                }
                Text(state.title)
                    .font(.system(.headline, design: .serif).weight(.semibold))
                    .foregroundStyle(paperWhite)
                    .lineLimit(1)
                if !state.subtitle.isEmpty {
                    Text(state.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "radio")
                .font(.title3)
                .foregroundStyle(monocleGold)
        }
        .padding(14)
    }
}
