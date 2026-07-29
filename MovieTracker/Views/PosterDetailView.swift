//
//  PosterDetailView.swift
//  MovieTracker
//
//  Full-screen movie poster over a blurred dark background, presented from
//  MovieDetailView with a zoom transition. Supports pinch-to-zoom, pan when
//  zoomed (clamped so the poster can't be dragged offscreen), and double-tap
//  to zoom about the tapped point; when not zoomed, the zoom transition's
//  interactive drag dismisses it (from anywhere, incl. the poster).
//  Replaces the storyboard PosterDetailViewController.
//
//  The zoom transition is applied to the poster *itself* (not the full-screen
//  container), so the source poster morphs into the enlarged poster's frame
//  rather than into the whole view. The blurred backdrop lives in the
//  presentation background so it cross-fades instead of participating.
//  NOTE: this must NOT be wrapped in a NavigationStack — doing so makes the
//  presentation fall back to a slide-up (the present no longer zooms).
//

import SwiftUI

struct PosterDetailView: View {
    let movie: Movie
    var tint: Color = .appAccent
    let zoomSourceID: Int
    let zoomNamespace: Namespace.ID

    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var posterSize: CGSize = .zero

    private let maxScale: CGFloat = 4
    private let doubleTapScale: CGFloat = 2.5
    /// How far (as a fraction of the poster's size) an edge may be panned inward
    /// from the container edge — prevents dragging the poster offscreen.
    private let panInsetLimit: CGFloat = 0.1

    var body: some View {
        poster
            // Applied to the poster so the zoom target is the poster's frame, not the screen.
            .navigationTransition(.zoom(sourceID: zoomSourceID, in: zoomNamespace))
            // Center the poster on screen; this container is not the zoom target.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                Button(role: .close) { dismiss() }
                    .padding()
            }
            // While zoomed in, a pinch-out must adjust our scale — not trigger the zoom
            // transition's interactive (pinch/drag) dismissal.
            .interactiveDismissDisabled(scale > 1)
            .presentationBackground {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .ignoresSafeArea()
            }
    }

    private var poster: some View {
        PosterImage(url: movie.posterURL(.orig))
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            }
            .padding()
            // Capture the unscaled bounds; gesture locations and the pan clamp use this space.
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                posterSize = size
            }
            .scaleEffect(scale)
            .offset(offset)
            .contentShape(Rectangle())
            .gesture(magnifyGesture)
            // Only recognize the pan once zoomed in; at rest the drag falls through to the
            // zoom transition's interactive dismiss (works anywhere, including on the poster).
            .simultaneousGesture(panGesture, including: scale > 1 ? .all : .subviews)
            .onTapGesture(count: 2) { location in
                toggleZoom(at: location)
            }
    }

    // MARK: - Gestures

    private var magnifyGesture: some Gesture {
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

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = clampedOffset(CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                ))
            }
            .onEnded { _ in
                guard scale > 1 else { return }
                lastOffset = offset
            }
    }

    /// Zooms in about the tapped point (in the poster's unscaled local space),
    /// or resets if already zoomed.
    private func toggleZoom(at location: CGPoint) {
        withAnimation(.spring(duration: 0.3)) {
            if scale > 1 {
                resetZoom()
            } else {
                scale = doubleTapScale
                lastScale = doubleTapScale
                // Offset so the tapped point stays fixed while the content scales around it:
                // a point at distance d from center renders at d*s + offset, so keeping it
                // stationary requires offset = d * (1 - s).
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

    /// Clamps a pan offset so the scaled poster's edges can be inset at most
    /// `panInsetLimit` of the poster's size from the container edges — i.e. the
    /// poster can't be dragged (entirely) offscreen.
    private func clampedOffset(_ proposed: CGSize) -> CGSize {
        guard posterSize != .zero else { return proposed }
        let maxX = max(0, (scale - 1) * posterSize.width / 2) + panInsetLimit * posterSize.width
        let maxY = max(0, (scale - 1) * posterSize.height / 2) + panInsetLimit * posterSize.height
        return CGSize(
            width: min(maxX, max(-maxX, proposed.width)),
            height: min(maxY, max(-maxY, proposed.height))
        )
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}
