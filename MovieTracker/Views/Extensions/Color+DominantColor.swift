//
//  Color+DominantColor.swift
//  MovieTracker
//

import SwiftUI
import UIKit

extension Color {
    static func dominantColor(from data: Data) -> Color {
        guard let uiImage = UIImage(data: data) else { return .appAccent }
        return dominantColor(from: uiImage)
    }

    /// The artwork's most prominent vivid colour, used to tint a detail screen. Vividness counts
    /// for more than area, so a small saturated block (a title, a logo) beats a muted sky.
    static func dominantColor(from uiImage: UIImage) -> Color {
        guard let found = DominantHue.find(in: uiImage) else { return .appAccent }
        return Color(hue: found.hue, saturation: max(0.5, found.saturation), brightness: 1)
    }
}

/// Picks the winning hue from a weighted histogram of a downscaled copy of the image.
private enum DominantHue {
    /// 10° buckets: wide enough that a gradient lands in one bucket, narrow enough to keep red
    /// from merging into orange.
    private static let binCount = 36
    /// Averaging the artwork down to this width is the blur step — it merges neighbouring pixels
    /// into blocks of colour while leaving hues intact.
    private static let sampleWidth = 128
    /// Below these, a pixel is a grey or a shadow and carries no usable hue.
    private static let minSaturation = 0.2
    private static let minBrightness = 0.2

    static func find(in image: UIImage) -> (hue: Double, saturation: Double)? {
        guard let sample = pixels(of: image) else { return nil }

        var weights = [Double](repeating: 0, count: binCount)
        // Hues are angles, so they're summed as vectors: a mean of 350° and 10° must land on 0°.
        var hueX = [Double](repeating: 0, count: binCount)
        var hueY = [Double](repeating: 0, count: binCount)
        var saturations = [Double](repeating: 0, count: binCount)

        for index in stride(from: 0, to: sample.count, by: 4) {
            let pixel = hsb(red: Double(sample[index]) / 255,
                            green: Double(sample[index + 1]) / 255,
                            blue: Double(sample[index + 2]) / 255)
            guard pixel.saturation >= minSaturation, pixel.brightness >= minBrightness else { continue }

            // Cubed saturation is what lets a vivid minority beat a muted majority; brightness
            // squared then discounts the same hue where it sits in shadow.
            let weight = pow(pixel.saturation, 3) * pow(pixel.brightness, 2)
            let bin = min(binCount - 1, Int(pixel.hue * Double(binCount)))
            let angle = pixel.hue * 2 * .pi
            weights[bin] += weight
            hueX[bin] += weight * cos(angle)
            hueY[bin] += weight * sin(angle)
            saturations[bin] += weight * pixel.saturation
        }

        // Score each bin with its neighbours, so one colour straddling a bin edge isn't split
        // into two losing halves.
        var scores = [Double](repeating: 0, count: binCount)
        for bin in 0..<binCount {
            scores[bin] = weights[bin] + 0.5 * (weights[before(bin)] + weights[after(bin)])
        }
        guard let winner = scores.indices.max(by: { scores[$0] < scores[$1] }), scores[winner] > 0 else {
            return nil   // Greyscale artwork: no hue to report.
        }

        var x = 0.0, y = 0.0, saturation = 0.0, total = 0.0
        for bin in [before(winner), winner, after(winner)] {
            x += hueX[bin]
            y += hueY[bin]
            saturation += saturations[bin]
            total += weights[bin]
        }
        var hue = atan2(y, x) / (2 * .pi)
        if hue < 0 { hue += 1 }
        return (hue, saturation / total)
    }

    private static func before(_ bin: Int) -> Int { (bin + binCount - 1) % binCount }
    private static func after(_ bin: Int) -> Int { (bin + 1) % binCount }

    private static func pixels(of image: UIImage) -> [UInt8]? {
        guard let cgImage = image.cgImage else { return nil }
        let width = min(sampleWidth, cgImage.width)
        let height = max(1, Int((Double(width) * Double(cgImage.height) / Double(cgImage.width)).rounded()))
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &bytes,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }

    private static func hsb(red: Double, green: Double, blue: Double) -> (hue: Double, saturation: Double, brightness: Double) {
        let high = max(red, green, blue), low = min(red, green, blue)
        let range = high - low
        guard range > 0 else { return (0, 0, high) }

        var hue: Double
        if high == red {
            hue = ((green - blue) / range).truncatingRemainder(dividingBy: 6)
        } else if high == green {
            hue = (blue - red) / range + 2
        } else {
            hue = (red - green) / range + 4
        }
        hue /= 6
        if hue < 0 { hue += 1 }
        return (hue, range / high, high)
    }
}

#Preview("Tints from sample artwork") {
    let artwork = ["preview-poster", "preview-poster-alt", "preview-backdrop", "preview-still", "preview-profile"]

    ScrollView {
        VStack(spacing: 16) {
            ForEach(artwork, id: \.self) { name in
                if let image = UIImage(named: name) {
                    let tint = Color.dominantColor(from: image)
                    HStack(spacing: 16) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 8) {
                            Text(name).font(.caption).foregroundStyle(.secondary)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(tint)
                                .frame(height: 40)
                            Button("Watched", systemImage: "checkmark.circle.fill") {}
                                .buttonStyle(.borderedProminent)
                                .tint(tint)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical)
    }
    .preferredColorScheme(.dark)
}
