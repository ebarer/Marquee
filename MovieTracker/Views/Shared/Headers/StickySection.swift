//
//  StickySection.swift
//  MovieTracker
//

import SwiftUI

/// A section whose header pins at `pinLine`, for scroll views that can't use `pinnedViews`.
struct StickySection<Header: View, Content: View>: View {
    let space: String
    var pinLine: CGFloat = 0
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    @State private var travel: CGFloat = 0

    var body: some View {
        // `visualEffect`'s closure is `@Sendable`, so read the main-actor values up front.
        let name = space, line = pinLine, limit = travel

        VStack(spacing: 0) {
            header()
                .stickyHeaderBackground(space: name, pinLine: line, scrolled: true)
                // Pin via render-time geometry: a GeometryReader-driven offset reads scroll a
                // frame late and the pinned header vibrates against the page.
                .visualEffect { view, proxy in
                    let minY = proxy.frame(in: .named(name)).minY
                    return view.offset(y: min(max(0, line - minY), limit))
                }
                .zIndex(1)
            content()
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { travel = $0 }
        }
    }
}

// Mirrors a detail screen: a glass bar owns the top inset, and the section pins beneath it.
#Preview {
    let pinLine: CGFloat = 120
    ZStack(alignment: .top) {
        ScrollView {
            VStack(spacing: 0) {
                Color.clear.frame(height: pinLine)
                ForEach(1...3, id: \.self) { season in
                    StickySection(space: "preview", pinLine: pinLine) {
                        SectionHeader(title: "Season \(season)", color: .appAccent)
                    } content: {
                        ForEach(1...8, id: \.self) { episode in
                            Text("Episode \(episode)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                        }
                    }
                }
            }
        }
        .coordinateSpace(name: "preview")

        Color.clear
            .frame(height: pinLine)
            .glassEffect(.regular.tint(.black.opacity(0.35)), in: .rect)
    }
    .ignoresSafeArea(edges: .top)
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
