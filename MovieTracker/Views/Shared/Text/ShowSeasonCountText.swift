//
//  ShowSeasonCountText.swift
//  MovieTracker
//

import SwiftUI

/// Displays "N Seasons" for a show, resolving the count lazily behind an optional placeholder.
struct ShowSeasonCountText: View {
    let show: Show
    var placeholder: String? = nil
    var font: Font = .subheadline

    @State private var resolved: Int?

    private var count: Int? {
        show.seasonCount > 0 ? show.seasonCount : resolved
    }

    var body: some View {
        Group {
            if let count {
                Text(count == 1 ? "1 Season" : "\(count) Seasons")
            } else if let placeholder {
                Text(placeholder)
            }
        }
        .font(font)
        .foregroundStyle(.secondary)
        .task(id: show.id) {
            guard show.seasonCount == 0 else { return }
            resolved = await ShowSeasonCountStore.shared.show(for: show.id)?.seasonCount
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        ShowSeasonCountText(show: .preview)
        // Unresolved: falls back to the placeholder until the count arrives.
        ShowSeasonCountText(show: Show(id: -1, name: "Unknown"), placeholder: "2019")
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
