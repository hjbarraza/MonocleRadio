// ArtworkPalette.swift — per-show accent color pulled from cover art
// Monocle Radio — iOS player for Monocle 24
//
// The Urbanist reads green, The Menu reads red: playback accents take on
// each show's tile. Falls back to Monocle gold until (or unless) a usable
// color lands.

import SwiftUI
import CoreImage

@MainActor
@Observable
final class ArtworkPalette {
    static let shared = ArtworkPalette()

    private(set) var colors: [URL: Color] = [:]
    @ObservationIgnored private var inFlight: Set<URL> = []

    /// Current accent for a cover URL — gold until extraction completes.
    func accent(for url: URL?) -> Color {
        guard let url else { return .monocleGold }
        if let color = colors[url] { return color }
        extract(url)
        return .monocleGold
    }

    private func extract(_ url: URL) {
        guard !inFlight.contains(url) else { return }
        inFlight.insert(url)
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data),
                  let average = image.averageColor else { return }

            var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
            average.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)

            // Near-grayscale tiles (the live logo) keep the gold accent
            guard sat > 0.12 else { return }

            // Clamp into a range that reads on both paper and ink
            let color = Color(
                hue: hue,
                saturation: min(max(sat, 0.35), 0.75),
                brightness: min(max(bri, 0.55), 0.82)
            )
            colors[url] = color
        }
    }
}

private extension UIImage {
    /// CIAreaAverage over the full image — one pixel out, cheap and stable.
    var averageColor: UIColor? {
        guard let input = CIImage(image: self) else { return nil }
        let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [kCIInputImageKey: input, kCIInputExtentKey: CIVector(cgRect: input.extent)]
        )
        guard let output = filter?.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        context.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        return UIColor(
            red: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255,
            alpha: 1
        )
    }
}
