//
//  SeasonWatchedToggle.swift
//  MovieTracker
//

import SwiftUI

/// A glass checkmark toggling a whole season's watched state, confirmed first (mirrors the
/// show-level checkmark). Calls `onToggle` with the target state after confirmation.
struct SeasonWatchedToggle: View {
    let allWatched: Bool
    let canToggle: Bool
    let tint: Color
    let onToggle: (Bool) -> Void

    @State private var pending: Bool?

    var body: some View {
        Button {
            pending = !allWatched
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(allWatched ? .appBackground : tint)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(allWatched ? .regular.tint(tint).interactive() : .regular.interactive(),
                     in: Circle())
        .disabled(!canToggle)
        .accessibilityLabel(allWatched ? "Mark season unwatched" : "Mark season watched")
        .confirmationDialog(
            pending == true ? "Mark season as watched?" : "Mark season as unwatched?",
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

    private func apply(_ watched: Bool) {
        pending = nil
        onToggle(watched)
    }
}

#Preview {
    HStack(spacing: 24) {
        SeasonWatchedToggle(allWatched: true, canToggle: true, tint: .appAccent, onToggle: { _ in })
        SeasonWatchedToggle(allWatched: false, canToggle: true, tint: .appAccent, onToggle: { _ in })
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
