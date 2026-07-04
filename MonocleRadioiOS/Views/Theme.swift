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

// MARK: - Live Badge

/// Red dot + tracked "LIVE" caption.
struct LiveBadge: View {
    /// Dot pulses secondary when the stream is loaded but paused.
    var active: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? Color.monocleRed : Color.secondary)
                .frame(width: 8, height: 8)
            Kicker(text: "Live", color: active ? .monocleRed : .secondary)
        }
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
