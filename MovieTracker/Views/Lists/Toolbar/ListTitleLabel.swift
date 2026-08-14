//
//  ListTitleLabel.swift
//  MovieTracker
//

import SwiftUI

/// The Lists navigation title: list name, tinted, over its title count — the label for
/// the `ListTitleMenu` switcher.
struct ListTitleLabel: View {
    let name: String
    let color: Color
    let count: Int

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 5) {
                chevron.hidden()
                Text(name)
                    .font(.headline)
                    .foregroundStyle(color)
                chevron
            }
            // Neutral "Title" since lists now mix movies, shows, and seasons.
            Text("^[\(count) Title](inflect: true)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(5)
            .background(Color(.tertiarySystemFill), in: Circle())
            .offset(y: 1)
    }
}

#Preview("Title label") {
    VStack(spacing: 20) {
        ListTitleLabel(name: "Watch List", color: .appAccent, count: 12)
        ListTitleLabel(name: "Watched", color: ListDestination.watchedColor, count: 1)
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
