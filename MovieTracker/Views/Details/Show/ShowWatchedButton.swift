//
//  ShowWatchedButton.swift
//  MovieTracker
//

import SwiftUI

/// The show's Watched checkmark, confirm-first. Marking covers only aired episodes, so an airing show reads as caught up.
struct ShowWatchedButton: View {
    let isSeen: Bool
    var isCaughtUp: Bool = false
    var hasProgress: Bool = false
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

    // Watching stops at the aired episodes, so a partly-watched show has progress to clear even
    // though a tap would mark it watched.
    private var canClearProgress: Bool { hasProgress || isCaughtUp }

    private var title: String {
        if pendingWatched != true { return "Mark all seasons as unwatched?" }
        return isOngoing ? "Mark all aired episodes as watched?" : "Mark all seasons as watched?"
    }

    private var accessibilityLabel: String {
        if isSeen { return "Mark show unwatched" }
        return isCaughtUp ? "Caught up" : "Mark show watched"
    }

    var body: some View {
        control
            .accessibilityLabel(accessibilityLabel)
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

    @ViewBuilder
    private var control: some View {
        if isSeen || !canClearProgress {
            // A tap already covers the only action available in these states.
            GlassActionButton(systemName: symbol, isOn: isFilled, width: width,
                              shape: Capsule(), tint: tint) {
                pendingWatched = !isSeen
            }
        } else if isCaughtUp {
            // Caught up has nothing left to mark, but the tap still has to consume the gesture:
            // without a primary action it would open the menu, putting unwatch one tap away.
            unwatchMenu(primaryAction: {})
        } else {
            unwatchMenu(primaryAction: { pendingWatched = true })
        }
    }

    private func unwatchMenu(primaryAction: (() -> Void)?) -> some View {
        GlassActionMenu(systemName: symbol, isOn: isFilled, width: width,
                        shape: Capsule(), tint: tint, primaryAction: primaryAction) {
            Button("Mark Unwatched", systemImage: "arrow.uturn.backward", role: .destructive) {
                pendingWatched = false
            }
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
        ShowWatchedButton(isSeen: false, hasProgress: true, tint: .appAccent,
                          glassNamespace: namespace) { _ in }
        ShowWatchedButton(isSeen: false, isCaughtUp: true, hasProgress: true, tint: .appAccent,
                          glassNamespace: namespace) { _ in }
        ShowWatchedButton(isSeen: true, hasProgress: true, tint: .appAccent,
                          glassNamespace: namespace) { _ in }
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
