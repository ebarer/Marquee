//
//  RelatedMoviesSection.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// A poster strip whose title flips between the movie's franchise and TMDB recommendations.
struct RelatedMoviesSection: View {
    let collection: [Movie]
    let recommendations: [Movie]
    let lists: [MediaList]
    let tint: Color

    @State private var selection: Mode?
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
            CollapsibleSectionHeader(title: mode.title, tint: tint, isExpanded: isExpanded) {
                withAnimation(.easeInOut) { userExpanded = !isExpanded }
            }
        } else {
            SectionHeader(title: mode.title)
        }
    }
}

// Both modes (franchise + recommendations) and recommendations-only (collapsed).
#Preview {
    NavigationStack {
        ScrollView {
            RelatedMoviesSection(collection: Movie.previewList, recommendations: Movie.previewList,
                                 lists: [], tint: .appAccent)
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
