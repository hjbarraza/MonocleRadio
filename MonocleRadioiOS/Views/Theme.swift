// Theme.swift — Monocle editorial design layer: palette, type, shared views
// Monocle Radio — iOS player for Monocle 24
//
// Tokens documented in DESIGN.md. Warm-tinted neutrals (never pure black or
// white), serif display type, red reserved for LIVE, gold for playback.

import SwiftUI

// MARK: - Palette

extension Color {
    /// Monocle gold accent (#C8A55A) — playback accents only
    static let monocleGold = Color(red: 0.784, green: 0.647, blue: 0.353)

    /// Editorial red (#CD1D1D) — LIVE means red, red means live
    static let monocleRed = Color(red: 0.804, green: 0.114, blue: 0.114)

    /// App background: warm paper in light, warm near-black in dark
    static let paper = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.078, green: 0.071, blue: 0.063, alpha: 1)   // #141210
            : UIColor(red: 0.980, green: 0.969, blue: 0.945, alpha: 1)   // #FAF7F1
    })

    /// Masthead ink — constant across modes, like a magazine cover
    static let ink = Color(red: 0.090, green: 0.082, blue: 0.070)

    /// Text on ink surfaces
    static let paperWhite = Color(red: 0.980, green: 0.969, blue: 0.945)
}

// MARK: - Type

extension Font {
    /// Serif display for the front-page masthead
    static let masthead = Font.system(size: 34, weight: .bold, design: .serif)

    /// Serif show names in heroes and detail headers
    static let showTitle = Font.system(.title2, design: .serif).weight(.semibold)

    /// Serif episode/list titles
    static let entryTitle = Font.system(.subheadline, design: .serif).weight(.semibold)
}

/// Tracked-uppercase caption — the "ON AIR" gesture, used app-wide for
/// section headers, desk names, and status labels.
struct Kicker: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

// MARK: - Cover Art (4:3, honoring Monocle's 822×616 tiles)

struct CoverArt: View {
    static let aspect: CGFloat = 822.0 / 616.0

    let url: URL?
    let width: CGFloat
    var cornerRadius: CGFloat = 6

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .failure:
                Image(systemName: "radio")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.1))
            default:
                Color.secondary.opacity(0.1)
            }
        }
        .frame(width: width, height: width / Self.aspect)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Haptics

/// One place for the app's touch vocabulary. Radio used to be physical;
/// small, consistent ticks keep it that way.
enum Haptics {
    /// Play/pause — the main transport action
    static func play() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    /// Skips, expanding/collapsing the player
    static func tick() { UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7) }
    /// Scrubber crossing a minute mark
    static func detent() { UISelectionFeedbackGenerator().selectionChanged() }
    /// Sleep timer armed
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

// MARK: - Live Badge

/// Red dot + tracked "LIVE" caption. The dot breathes slowly while on air —
/// the app's one ambient motion (still under Reduce Motion).
struct LiveBadge: View {
    /// Dot falls back to secondary when the stream is loaded but paused.
    var active: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? Color.monocleRed : Color.secondary)
                .frame(width: 8, height: 8)
                .opacity(active && breathing ? 0.4 : 1)
                .scaleEffect(active && breathing ? 0.8 : 1)
                .animation(
                    active && !reduceMotion
                        ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true)
                        : .default,
                    value: breathing
                )
            Kicker(text: "Live", color: active ? .monocleRed : .secondary)
        }
        .onAppear { if !reduceMotion { breathing = true } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Live")
    }
}

// MARK: - Blurred Artwork Ambiance

/// Full-bleed blurred cover art with a legibility scrim — the Now Playing
/// and ambient-mode background.
struct ArtworkAmbiance: View {
    let url: URL?
    var scrim: Double = 0.45

    var body: some View {
        GeometryReader { geo in
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: 60, opaque: true)
                        .overlay(Color.ink.opacity(scrim))
                } else {
                    Color.ink
                }
            }
        }
        .ignoresSafeArea()
    }
}
