//
//  SeasonWatchedToggle.swift
//  MovieTracker
//

import SwiftUI

/// A glass checkmark toggling a whole season's watched state, confirmed first. Marking covers
/// only *aired* episodes, so a season still airing lands in a third state: caught up.
struct SeasonWatchedToggle: View {
    let allWatched: Bool
    /// Every aired episode watched. With unaired ones left this is "caught up", not complete:
    /// the toggle fills as a half-circle and stops responding.
    var allAiredWatched: Bool = false
    /// The season still has episodes dated in the future.
    var hasUnaired: Bool = false
    let canToggle: Bool
    let tint: Color
    let onToggle: (Bool) -> Void

    @State private var pending: Bool?

    private var isCaughtUp: Bool { allAiredWatched && !allWatched }

    private var title: String {
        if pending != true { return "Mark season as unwatched?" }
        return hasUnaired ? "Mark aired episodes as watched?" : "Mark season as watched?"
    }

    var body: some View {
        Button {
            pending = !allWatched
        } label: {
            Image(systemName: isCaughtUp ? "circle.tophalf.filled" : "checkmark")
                .font(.system(size: 18, weight: .semibold))
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
        .confirmationDialog(
            title,
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible) {
            if pending == true {
                Button("Mark Watched") { apply(true) }
            } else {
                Button("Mark Unwatched", role: .destructive) { apply(false) }
            }
            Button("Cancel", role: .cancel) { pending = nil }
        }
    }

    private var accessibilityLabel: String {
        if isCaughtUp { return "Caught up on season" }
        return allWatched ? "Mark season unwatched" : "Mark season watched"
    }

    private func apply(_ watched: Bool) {
        pending = nil
        onToggle(watched)
    }
}

#Preview {
    HStack(spacing: 24) {
        SeasonWatchedToggle(allWatched: true, canToggle: true, tint: .appAccent, onToggle: { _ in })
        SeasonWatchedToggle(allWatched: false, allAiredWatched: true, hasUnaired: true,
                            canToggle: true, tint: .appAccent, onToggle: { _ in })
        SeasonWatchedToggle(allWatched: false, canToggle: true, tint: .appAccent, onToggle: { _ in })
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
