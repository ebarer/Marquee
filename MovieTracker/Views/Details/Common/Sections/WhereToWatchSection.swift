//
//  WhereToWatchSection.swift
//  MovieTracker
//

import SwiftUI

/// Streaming availability for the user's region, an in-theaters note, and a service filter sheet.
struct WhereToWatchSection: View {
    let availabilityByRegion: [String: WatchAvailability]?
    var releaseDate: Date?
    var isShow: Bool = false
    var tint: Color = .appAccent
    var isLoading: Bool = false

    private let store = StreamingServicesStore.shared
    @State private var expanded = false
    @State private var showingServices = false
    // Not remembered: every title opens on the user's own services, and widening is for that look only.
    @State private var scope: StreamingScope = .mine

    private var availability: WatchAvailability? { availabilityByRegion?[store.region] }

    private var inTheatres: Bool {
        guard !isShow,
              let releaseDate, releaseDate <= .now,
              let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: .now)
        else { return false }
        return releaseDate > cutoff
    }

    private var resolution: StreamingResolution {
        StreamingAvailability.resolve(availability, scope: scope, selected: store.selected)
    }

    // An empty map counts as no answer: a stub carries none, and claiming "unavailable" before the
    // payload replies is the one thing this must not do.
    private var pending: Bool { isLoading && (availabilityByRegion?.isEmpty ?? true) }

    var body: some View {
        let resolved = resolution
        let groups = resolved.groups
        VStack(spacing: 0) {
            WhereToWatchHeader(verdict: resolved.verdict, inTheatres: inTheatres, tint: tint,
                               isLoading: pending, expandable: !groups.isEmpty,
                               // An unavailable verdict means no provider in either scope.
                               canChangeScope: resolved.verdict != .unavailable,
                               // Matches the chevron's own animation, whichever route sets the scope.
                               expanded: $expanded, scope: $scope.animation(.easeInOut),
                               onChooseServices: { showingServices = true })
            if expanded, !groups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(groups) { group in
                            StreamingProviderTile(group: group, fallback: availability?.justWatchLink)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .sheet(isPresented: $showingServices) {
            NavigationStack {
                StreamingServicesView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(role: .confirm) { showingServices = false }
                        }
                    }
            }
            .preferredColorScheme(.dark)
        }
    }
}

#Preview("Available") {
    NavigationStack {
        ScrollView {
            WhereToWatchSection(availabilityByRegion: Movie.preview.watchByRegion)
        }
        .background(Color.appBackground)
    }
    .preferredColorScheme(.dark)
}

#Preview("Unavailable") {
    NavigationStack {
        ScrollView {
            WhereToWatchSection(availabilityByRegion: [:])
        }
        .background(Color.appBackground)
    }
    .preferredColorScheme(.dark)
}

#Preview("In Theatres") {
    NavigationStack {
        ScrollView {
            WhereToWatchSection(availabilityByRegion: [:], releaseDate: .now)
        }
        .background(Color.appBackground)
    }
    .preferredColorScheme(.dark)
}
