//
//  ListTitleLabel.swift
//  MovieTracker
//

import SwiftUI

/// The Lists navigation title: list name, tinted, over its title count.
struct ListTitleLabel: View {
    let name: String
    let color: Color
    let count: Int
    var visible: Int?

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
            countText
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var countText: Text {
        guard let visible, visible != count else {
            return Text("^[\(count) Title](inflect: true)")
        }
        return Text("\(visible) of ^[\(count) Title](inflect: true)")
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
        ListTitleLabel(name: "Watch List", color: .appAccent, count: 30, visible: 3)
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
