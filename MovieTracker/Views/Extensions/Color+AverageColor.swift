//
//  Color+AverageColor.swift
//  MovieTracker
//

import SwiftUI
import UIKit
import CoreImage

extension Color {
    static func averageColor(from data: Data) -> Color {
        guard let uiImage = UIImage(data: data),
              let inputImage = CIImage(image: uiImage),
              let filter = CIFilter(name: "CIAreaAverage", parameters: [
                  kCIInputImageKey: inputImage,
                  kCIInputExtentKey: CIVector(cgRect: inputImage.extent)
              ]),
              let outputImage = filter.outputImage
        else {
            return .appAccent
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage,
                       toBitmap: &bitmap,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: nil)

        let rgbColor = UIColor(red: CGFloat(bitmap[0]) / 255,
                               green: CGFloat(bitmap[1]) / 255,
                               blue: CGFloat(bitmap[2]) / 255,
                               alpha: 1)

        var hue: CGFloat = 0, sat: CGFloat = 0
        rgbColor.getHue(&hue, saturation: &sat, brightness: nil, alpha: nil)

        // Grayscale poster → fall back to the app accent.
        if hue == 0 && sat == 0 {
            return .appAccent
        }

        return Color(hue: hue, saturation: max(0.5, sat), brightness: 1)
    }
}
