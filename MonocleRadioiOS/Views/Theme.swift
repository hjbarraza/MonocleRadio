// Theme.swift — shared colors and small reusable views
// Monocle Radio — iOS player for Monocle 24

import SwiftUI

extension Color {
    /// Monocle gold accent (#C8A55A) — matches the Mac app and AccentColor asset
    static let monocleGold = Color(red: 0.784, green: 0.647, blue: 0.353)
}

/// Square cover art thumbnail with loading and failure placeholders.
struct CoverArt: View {
    let url: URL?
    let size: CGFloat
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
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// Red dot + "LIVE" caption used in the live pane and Now Playing screen.
struct LiveBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(.red).frame(width: 8, height: 8)
            Text("LIVE")
                .font(.caption.bold())
                .tracking(1)
                .foregroundStyle(.red)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Live")
    }
}
