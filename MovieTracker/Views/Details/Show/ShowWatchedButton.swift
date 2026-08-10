//
//  ShowWatchedButton.swift
//  MovieTracker
//

import SwiftUI

/// The show's Watched checkmark with a confirm-first dialog (marking a show watched or
/// unwatched touches every season). Shares the action bar's glass namespace so it can
/// absorb the bookmark into a pill via matched geometry.
struct ShowWatchedButton: View {
    let isSeen: Bool
    let tint: Color
    var glassNamespace: Namespace.ID
    let onApply: (Bool) -> Void

    @State private var pendingWatched: Bool?

    var body: some View {
        GlassActionButton(systemName: "checkmark", isOn: isSeen,
                          width: isSeen ? ActionBarMetrics.size * 2 + ActionBarMetrics.spacing : ActionBarMetrics.size,
                          shape: Capsule(), tint: tint) {
            pendingWatched = !isSeen
        }
        .glassEffectID("watched", in: glassNamespace)
        .confirmationDialog(
            pendingWatched == true ? "Mark all seasons as watched?" : "Mark all seasons as unwatched?",
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
        ShowWatchedButton(isSeen: true, tint: .appAccent, glassNamespace: namespace) { _ in }
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
