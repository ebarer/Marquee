//
//  UpcomingSection.swift
//  MovieTracker
//

import SwiftUI

/// The collapsible "Upcoming" group of a filmography (credits dated in the future).
struct UpcomingSection: View {
    let entries: [FilmographyEntry]
    let lists: [MediaList]

    private var count: Int { entries.count }

    @State private var expanded = false

    var body: some View {
        Button {
            withAnimation(.easeInOut) { expanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text("Upcoming")
                    .font(.headline)
                    .foregroundStyle(Color.appAccent)
                Text("(\(count))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Upcoming, \(count) titles")
        .accessibilityHint(expanded ? "Collapses the section" : "Expands the section")

        if expanded {
            FilmographyRows(entries: entries, lists: lists)
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            LazyVStack(spacing: 0) {
                UpcomingSection(entries: FilmographyEntry.entries(for: Person.preview.allCredits,
                                                                  episodeCredits: [:]),
                                lists: [])
            }
        }
        .detailDestinations()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
