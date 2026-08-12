//
//  PosterDetailView.swift
//  MovieTracker
//
//  Full-screen poster with pinch/double-tap zoom and edge-locked pan (gestures in
//  PosterDetailView+Zoom). NOTE: must NOT be wrapped in a NavigationStack — that falls
//  back to a slide-up and the zoom transition is lost.
//

import SwiftUI

struct PosterDetailView: View {
    let imageURL: URL?
    var aspectRatio: CGFloat = 2.0 / 3.0
    var tint: Color = .appAccent
    let zoomSourceID: Int
    let zoomNamespace: Namespace.ID

    @Environment(\.dismiss) private var dismiss

    @State var scale: CGFloat = 1
    @State var lastScale: CGFloat = 1
    @State var offset: CGSize = .zero
    @State var lastOffset: CGSize = .zero
    /// The padded, scaled element's unscaled size (used for double-tap centering).
    @State var posterSize: CGSize = .zero
    /// The full-screen container the poster is centered in (used to lock pan edges).
    @State var containerSize: CGSize = .zero

    let maxScale: CGFloat = 4
    let doubleTapScale: CGFloat = 2.5
    /// Margin around the poster at rest; the actual image lives inside this inset.
    let posterPadding: CGFloat = 16

    var body: some View {
        // The reader sits inside the safe area to report the real insets; from those we
        // build the full screen size so pans reach the device's top/bottom edges.
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

    /// 0 at rest, ramping to 1 once zoomed a little; drives the corners and border away so an
    /// edge-locked image reads as bare artwork rather than a framed card.
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
}

#Preview {
    @Previewable @Namespace var namespace
    PosterDetailView(imageURL: Movie.preview.posterURL(.orig), zoomSourceID: 1, zoomNamespace: namespace)
        .preferredColorScheme(.dark)
}
