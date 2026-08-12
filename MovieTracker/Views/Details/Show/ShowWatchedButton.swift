//
//  ShowWatchedButton.swift
//  MovieTracker
//

import SwiftUI

/// The show's Watched checkmark with a confirm-first dialog (marking a show watched or
/// unwatched touches every season). Shares the action bar's glass namespace so it can
/// absorb the bookmark into a pill via matched geometry.
///
/// Marking only ever covers *aired* episodes, so a show still on air lands in a third
/// state: caught up. That reads as a filled, non-tappable half-circle — confirmation that
/// the mark took, without claiming the show is finished. It reverts to a live checkmark
/// once an episode is un-watched or a new one airs.
struct ShowWatchedButton: View {
    let isSeen: Bool
    /// Every aired episode watched, but unaired ones remain.
    var isCaughtUp: Bool = false
    /// A show still on air only gets its aired episodes marked, so the prompt says so.
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
