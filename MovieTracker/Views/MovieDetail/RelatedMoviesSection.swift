//
//  RelatedMoviesSection.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// A poster strip below the description whose title flips between the movie's
/// franchise ("Related") and TMDB "Recommendations". Shown when either has
/// content; the title becomes a menu only when both do. When only
/// recommendations exist the strip starts collapsed behind a tappable header.
struct RelatedMoviesSection: View {
    let collection: [Movie]
    let recommendations: [Movie]
    let lists: [MediaList]
    let tint: Color

    /// The user's pick from the title menu; nil follows the default (franchise first).
    @State private var selection: Mode?
    /// User's expand/collapse override; nil follows the default. Recommendations-only
    /// sections start collapsed since they aren't tied to what the user is viewing.
    @State private var userExpanded: Bool?

    private enum Mode: CaseIterable {
        case related, recommendations
        var title: String { self == .related ? "Related" : "Recommendations" }
    }

    private var availableModes: [Mode] {
        var modes: [Mode] = []
        if !collection.isEmpty { modes.append(.related) }
        if !recommendations.isEmpty { modes.append(.recommendations) }
        return modes
    }

    private var currentMode: Mode? {
        if let selection, availableModes.contains(selection) { return selection }
        return availableModes.first
    }

    /// Collapse only applies when recommendations are all we have; a franchise
    /// stays expanded so the strip is visible without an extra tap.
    private var isCollapsible: Bool { collection.isEmpty }

    private var isExpanded: Bool { userExpanded ?? !isCollapsible }

    private func movies(for mode: Mode) -> [Movie] {
        mode == .related ? collection : Array(recommendations.prefix(20))
    }

    var body: some View {
        if let mode = currentMode {
            VStack(alignment: .leading, spacing: 0) {
                header(mode: mode)
                if isExpanded {
                    PosterStrip(movies: movies(for: mode), lists: lists, showsYear: true)
                        // New identity per mode so switching crossfades the whole strip.
                        .id(mode)
                        .transition(.opacity)
                }
            }
        }
    }

    @ViewBuilder
    private func header(mode: Mode) -> some View {
        let modes = availableModes
        if modes.count > 1 {
            Menu {
                ForEach(modes, id: \.self) { option in
                    Button {
                        withAnimation(.easeInOut) { selection = option }
                    } label: {
                        if option == mode {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(mode.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else if isCollapsible {
            collapsibleHeader(mode: mode)
        } else {
            SectionHeader(title: mode.title)
        }
    }

    /// A tappable header that expands or collapses the strip, with a chevron
    /// that rotates to reflect the current state.
    private func collapsibleHeader(mode: Mode) -> some View {
        Button {
            withAnimation(.easeInOut) { userExpanded = !isExpanded }
        } label: {
            HStack(spacing: 4) {
                Text(mode.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
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

#Preview("Related & Recommendations") {
    NavigationStack {
        ScrollView {
            RelatedMoviesSection(collection: Movie.previewList, recommendations: Movie.previewList,
                                 lists: [], tint: .appAccent)
        }
        .detailDestinations()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

#Preview("Recommendations only (collapsed)") {
    NavigationStack {
        ScrollView {
            RelatedMoviesSection(collection: [], recommendations: Movie.previewList,
                                 lists: [], tint: .appAccent)
        }
        .detailDestinations()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
