//
//  SeasonWatchedToggle.swift
//  MovieTracker
//

import SwiftUI

/// A glass checkmark toggling a whole season's watched state. Marking covers only *aired*
/// episodes, so a season still airing lands in a third state: caught up.
struct SeasonWatchedToggle: View {
    let allWatched: Bool
    /// Every aired episode watched. With unaired ones left this is "caught up", not complete:
    /// the toggle fills as a half-circle and stops responding.
    var allAiredWatched: Bool = false
    let canToggle: Bool
    let tint: Color
    let onToggle: (Bool) -> Void

    @State private var confirmingUnwatch = false

    private var isCaughtUp: Bool { allAiredWatched && !allWatched }

    var body: some View {
        Button {
            // Marking watched is a tap to undo, so it just happens. Clearing a season throws
            // away every episode's watched date, so that still asks.
            if allWatched { confirmingUnwatch = true } else { onToggle(true) }
        } label: {
            // The same symbol the season swipe action marks with.
            Image(systemName: isCaughtUp ? "circle.tophalf.filled" : "checkmark.rectangle.stack.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(allWatched || isCaughtUp ? .appBackground : tint)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(allWatched || isCaughtUp ? .regular.tint(tint).interactive()
                                              : .regular.interactive(),
                     in: Circle())
        .disabled(!canToggle || isCaughtUp)
        .accessibilityLabel(accessibilityLabel)
        .confirmationDialog("Mark season as unwatched?", isPresented: $confirmingUnwatch,
                            titleVisibility: .visible) {
            Button("Mark Unwatched", role: .destructive) { onToggle(false) }
            Button("Cancel", role: .cancel) { }
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
        SeasonWatchedToggle(allWatched: false, allAiredWatched: true,
                            canToggle: true, tint: .appAccent, onToggle: { _ in })
        SeasonWatchedToggle(allWatched: false, canToggle: true, tint: .appAccent, onToggle: { _ in })
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
