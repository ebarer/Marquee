//
//  ShowWatchedButton.swift
//  MovieTracker
//

import SwiftUI

/// The show's Watched checkmark, confirm-first. Marking covers only aired episodes, so an airing show reads as caught up.
struct ShowWatchedButton: View {
    let isSeen: Bool
    var isCaughtUp: Bool = false
    var isOngoing: Bool = false
    let tint: Color
    var glassNamespace: Namespace.ID
    let onApply: (Bool) -> Void

    @State private var pendingWatched: Bool?

    private var symbol: String { isCaughtUp && !isSeen ? "circle.tophalf.filled" : "checkmark" }

    private var isFilled: Bool { isSeen || isCaughtUp }

    private var width: CGFloat {
        isSeen ? ActionBarMetrics.size * 2 + ActionBarMetrics.spacing : ActionBarMetrics.size
    }

    private var title: String {
        if pendingWatched != true { return "Mark all seasons as unwatched?" }
        return isOngoing ? "Mark all aired episodes as watched?" : "Mark all seasons as watched?"
    }

    var body: some View {
        GlassActionButton(systemName: symbol, isOn: isFilled, width: width,
                          shape: Capsule(), tint: tint) {
            pendingWatched = !isSeen
        }
        .disabled(isCaughtUp && !isSeen)
        .accessibilityLabel(isCaughtUp && !isSeen ? "Caught up" : "Mark show watched")
        .glassEffectID("watched", in: glassNamespace)
        .confirmationDialog(
            title,
            isPresented: Binding(get: { pendingWatched != nil },
                                 set: { if !$0 { pendingWatched = nil } }),
            titleVisibility: .visible) {
            if pendingWatched == true {
                Button("Mark Watched") { apply(true) }
            } else {
                Button("Mark Unwatched", role: .destructive) { apply(false) }
            }
            Button("Cancel", role: .cancel) { pendingWatched = nil }
        }
    }

    private func apply(_ watched: Bool) {
        pendingWatched = nil
        onApply(watched)
    }
}

#Preview {
    @Previewable @Namespace var namespace
    return VStack(spacing: 24) {
        ShowWatchedButton(isSeen: false, tint: .appAccent, glassNamespace: namespace) { _ in }
        ShowWatchedButton(isSeen: false, isCaughtUp: true, tint: .appAccent,
                          glassNamespace: namespace) { _ in }
        ShowWatchedButton(isSeen: true, tint: .appAccent, glassNamespace: namespace) { _ in }
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
