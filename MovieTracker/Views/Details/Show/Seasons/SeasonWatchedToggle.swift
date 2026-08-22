//
//  SeasonWatchedToggle.swift
//  MovieTracker
//

import SwiftUI

/// A glass checkmark for a whole season. Marking covers only aired episodes, so an airing season reads as caught up.
struct SeasonWatchedToggle: View {
    let allWatched: Bool
    var allAiredWatched: Bool = false
    var hasProgress: Bool = false
    let canToggle: Bool
    let tint: Color
    let onToggle: (Bool) -> Void

    @State private var confirmingUnwatch = false

    private static let size: CGFloat = 44
    private static let pointSize: CGFloat = 16

    private var isCaughtUp: Bool { allAiredWatched && !allWatched }

    private var isFilled: Bool { allWatched || isCaughtUp }

    // The same symbol the season swipe action marks with.
    private var symbol: String {
        isCaughtUp ? "circle.tophalf.filled" : "checkmark.rectangle.stack.fill"
    }

    // With no episodes loaded there is nothing to clear either.
    private var canClearProgress: Bool { canToggle && (hasProgress || isCaughtUp) }

    var body: some View {
        control
            .disabled(!canToggle)
            .accessibilityLabel(accessibilityLabel)
            .confirmationDialog("Mark season as unwatched?", isPresented: $confirmingUnwatch,
                                titleVisibility: .visible) {
                Button("Mark Unwatched", role: .destructive) { onToggle(false) }
                Button("Cancel", role: .cancel) { }
            }
    }

    @ViewBuilder
    private var control: some View {
        if allWatched || !canClearProgress {
            // Marking watched is a tap to undo, so it needs no confirmation. Clearing a season
            // throws away every episode's watched date, so that still asks.
            button { if allWatched { confirmingUnwatch = true } else { onToggle(true) } }
        } else if isCaughtUp {
            // Caught up has nothing left to mark, but the tap still has to consume the gesture:
            // without a primary action it would open the menu, putting unwatch one tap away.
            unwatchMenu(primaryAction: {})
        } else {
            unwatchMenu(primaryAction: { onToggle(true) })
        }
    }

    private func button(_ action: @escaping () -> Void) -> some View {
        GlassActionButton(systemName: symbol, isOn: isFilled,
                          width: Self.size, height: Self.size, pointSize: Self.pointSize,
                          shape: Circle(), tint: tint, action: action)
    }

    private func unwatchMenu(primaryAction: @escaping () -> Void) -> some View {
        GlassActionMenu(systemName: symbol, isOn: isFilled,
                        width: Self.size, height: Self.size, pointSize: Self.pointSize,
                        shape: Circle(), tint: tint, primaryAction: primaryAction) {
            Button("Mark Unwatched", systemImage: "arrow.uturn.backward", role: .destructive) {
                confirmingUnwatch = true
            }
        }
    }

    private var accessibilityLabel: String {
        if isCaughtUp { return "Caught up on season" }
        return allWatched ? "Mark season unwatched" : "Mark season watched"
    }
}

#Preview {
    HStack(spacing: 24) {
        SeasonWatchedToggle(allWatched: true, canToggle: true, tint: .appAccent, onToggle: { _ in })
        SeasonWatchedToggle(allWatched: false, allAiredWatched: true, hasProgress: true,
                            canToggle: true, tint: .appAccent, onToggle: { _ in })
        SeasonWatchedToggle(allWatched: false, hasProgress: true, canToggle: true,
                            tint: .appAccent, onToggle: { _ in })
        SeasonWatchedToggle(allWatched: false, canToggle: true, tint: .appAccent, onToggle: { _ in })
        SeasonWatchedToggle(allWatched: false, canToggle: false, tint: .appAccent, onToggle: { _ in })
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
