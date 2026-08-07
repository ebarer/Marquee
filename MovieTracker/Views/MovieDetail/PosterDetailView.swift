//
//  PosterDetailView.swift
//  MovieTracker
//
//  Full-screen poster with pinch/double-tap zoom and edge-locked pan.
//  NOTE: must NOT be wrapped in a NavigationStack — that falls back to a slide-up
//  and the zoom transition is lost.
//

import SwiftUI

struct PosterDetailView: View {
    let imageURL: URL?
    var aspectRatio: CGFloat = 2.0 / 3.0
    var tint: Color = .appAccent
    let zoomSourceID: Int
    let zoomNamespace: Namespace.ID

    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    /// The padded, scaled element's unscaled size (used for double-tap centering).
    @State private var posterSize: CGSize = .zero
    /// The full-screen container the poster is centered in (used to lock pan edges).
    @State private var containerSize: CGSize = .zero

    private let maxScale: CGFloat = 4
    private let doubleTapScale: CGFloat = 2.5
    /// Margin around the poster at rest; the actual image lives inside this inset.
    private let posterPadding: CGFloat = 16

    var body: some View {
        // The reader sits inside the safe area so it can report the real insets. From
        // those we build the full physical-screen size and center the poster on it (so
        // pans reach the device's top/bottom edges), while placing the close button back
        // at the safe-area top-trailing corner where a nav bar's close button would sit.
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let fullSize = CGSize(
                width: proxy.size.width + insets.leading + insets.trailing,
                height: proxy.size.height + insets.top + insets.bottom
            )
            poster
                // Applied to the poster so the zoom target is the poster's frame, not the screen.
                .navigationTransition(.zoom(sourceID: zoomSourceID, in: zoomNamespace))
                // Center the poster on the full physical screen.
                .frame(width: fullSize.width, height: fullSize.height)
                .overlay(alignment: .topTrailing) {
                    // The frame's top-trailing corner is the physical corner; inset back
                    // into the safe area to reach the nav-bar line.
                    closeButton
                        .padding(.top, insets.top + 8)
                        .padding(.trailing, insets.trailing + 20)
                }
                // Shift the full-screen frame from the safe-area origin to the physical origin.
                .offset(x: -insets.leading, y: -insets.top)
                // The pan clamp locks the image's edges to this full-screen container.
                .onChange(of: fullSize, initial: true) { _, size in
                    containerSize = size
                }
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

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
        .environment(\.colorScheme, .dark)
    }

    /// 0 at rest, ramping to 1 once zoomed in a little; drives the rounded corners
    /// and border away so, when the image is locked to the screen edges, it reads as
    /// the bare image rather than a framed card.
    private var zoomProgress: CGFloat {
        min(1, max(0, (scale - 1) / 0.15))
    }

    private var poster: some View {
        let cornerRadius = 12 * (1 - zoomProgress)
        return PosterImage(url: imageURL)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.white.opacity(0.2 * (1 - zoomProgress)), lineWidth: 0.5)
            }
            .padding(posterPadding)
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

    /// Clamps a pan offset so the scaled image's edges lock to the container:
    /// panning is allowed only by the amount the image overflows the screen in
    /// each axis (0 when it's smaller than the screen, keeping it centered), so
    /// an edge can never be pulled inward from the screen edge.
    private func clampedOffset(_ proposed: CGSize) -> CGSize {
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

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}

#Preview {
    @Previewable @Namespace var namespace
    PosterDetailView(imageURL: Movie.preview.posterURL(.orig), zoomSourceID: 1, zoomNamespace: namespace)
        .preferredColorScheme(.dark)
}
