//
//  WhereToWatchSection.swift
//  MovieTracker
//

import SwiftUI

/// Streaming availability for the user's region (grouped provider logos), an in-theaters
/// note, and a settings sheet to filter services. Shared by movie and show detail.
struct WhereToWatchSection: View {
    let availabilityByRegion: [String: WatchAvailability]?
    var releaseDate: Date?
    var isShow: Bool = false
    var tint: Color = .appAccent

    private let store = StreamingServicesStore.shared
    @State private var expanded = false
    @State private var showingServices = false

    private var availability: WatchAvailability? { availabilityByRegion?[store.region] }

    private var inTheatres: Bool {
        guard !isShow,
              let releaseDate, releaseDate <= .now,
              let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: .now)
        else { return false }
        return releaseDate > cutoff
    }

    private var shown: [ProviderGroup] {
        guard let availability else { return [] }
        let groups = ProviderCatalog.grouped(availability.providers)
        guard !store.selected.isEmpty else { return groups }
        return groups.filter { store.selected.isSelected($0) }
    }

    var body: some View {
        let groups = shown
        VStack(spacing: 0) {
            WhereToWatchHeader(available: !groups.isEmpty, inTheatres: inTheatres, tint: tint,
                               expanded: $expanded, onInfo: { showingServices = true })
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
