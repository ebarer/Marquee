//
//  PosterDetailView+Zoom.swift
//  MovieTracker
//

import SwiftUI

/// The pinch / pan / double-tap gesture logic and edge-lock math for ``PosterDetailView``.
extension PosterDetailView {
    var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(maxScale, max(1, lastScale * value.magnification))
                offset = clampedOffset(offset)
            }
            .onEnded { _ in
                lastScale = scale
                lastOffset = offset
                if scale <= 1 {
                    withAnimation(.spring) { resetZoom() }
                }
            }
    }

    var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = clampedOffset(CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                ))
            }
            .onEnded { value in
                guard scale > 1 else { return }
                // Project where the release velocity would carry the pan, clamp it to
                // the edges, then spring there so the poster decelerates like Photos.
                let projected = clampedOffset(CGSize(
                    width: lastOffset.width + value.predictedEndTranslation.width,
                    height: lastOffset.height + value.predictedEndTranslation.height
                ))
                lastOffset = projected
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    offset = projected
                }
            }
    }

    func toggleZoom(at location: CGPoint) {
        withAnimation(.spring(duration: 0.3)) {
            if scale > 1 {
                resetZoom()
            } else {
                scale = doubleTapScale
                lastScale = doubleTapScale
                // Keep the tapped point fixed while scaling: a point at distance d from
                // center renders at d*s + offset, so it stays put when offset = d * (1 - s).
                let center = CGPoint(x: posterSize.width / 2, y: posterSize.height / 2)
                let proposed = CGSize(
                    width: (location.x - center.x) * (1 - doubleTapScale),
                    height: (location.y - center.y) * (1 - doubleTapScale)
                )
                offset = clampedOffset(proposed)
                lastOffset = offset
            }
        }
    }

    // Panning is allowed only by the amount the scaled image overflows, so an edge can't be pulled inward.
    func clampedOffset(_ proposed: CGSize) -> CGSize {
        guard posterSize != .zero, containerSize != .zero else { return proposed }
        // The image sits inside the padded element, so its scaled extent excludes
        // the padding on both sides.
        let imageWidth = (posterSize.width - 2 * posterPadding) * scale
        let imageHeight = (posterSize.height - 2 * posterPadding) * scale
        let maxX = max(0, (imageWidth - containerSize.width) / 2)
        let maxY = max(0, (imageHeight - containerSize.height) / 2)
        return CGSize(
            width: min(maxX, max(-maxX, proposed.width)),
            height: min(maxY, max(-maxY, proposed.height))
        )
    }

    func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}
