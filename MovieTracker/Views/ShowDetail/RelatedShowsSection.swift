//
//  RelatedShowsSection.swift
//  MovieTracker
//

import SwiftUI

/// A collapsible strip of recommended shows (collapsed by default, matching the
/// movie recommendations section), linking to each show's detail.
struct RelatedShowsSection: View {
    let shows: [Show]
    var tint: Color = .appAccent

    @State private var expanded = false

    var body: some View {
        if !shows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                header
                if expanded {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 12) {
                            ForEach(Array(shows.prefix(20)), id: \.id) { show in
                                NavigationLink(value: show) {
                                    ShowPosterCard(show: show, posterWidth: 90)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    private var header: some View {
        Button {
            withAnimation(.easeInOut) { expanded.toggle() }
        } label: {
            HStack(spacing: 4) {
                Text("Recommendations")
                    .font(.headline)
                    .foregroundStyle(.white)
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .rotationEffect(.degrees(expanded ? 0 : -90))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            RelatedShowsSection(shows: Show.previewList)
        }
        .detailDestinations()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
