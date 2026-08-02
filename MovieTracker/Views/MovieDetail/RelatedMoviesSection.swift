//
//  RelatedMoviesSection.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// A poster strip below the description whose title flips between the movie's
/// franchise ("Related") and TMDB "Recommendations". Shown when either has
/// content; the title becomes a menu only when both do.
struct RelatedMoviesSection: View {
    let collection: [Movie]
    let recommendations: [Movie]
    let lists: [MovieList]
    let context: ModelContext
    let tint: Color

    /// The user's pick from the title menu; nil follows the default (franchise first).
    @State private var selection: Mode?

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

    private func movies(for mode: Mode) -> [Movie] {
        mode == .related ? collection : Array(recommendations.prefix(20))
    }

    var body: some View {
        if let mode = currentMode {
            VStack(alignment: .leading, spacing: 0) {
                header(mode: mode)
                PosterStrip(movies: movies(for: mode), lists: lists, context: context,
                            showsYear: true)
                    // New identity per mode so switching crossfades the whole strip.
                    .id(mode)
                    .transition(.opacity)
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
        } else {
            SectionHeader(title: mode.title)
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            RelatedMoviesSection(collection: Movie.previewList, recommendations: Movie.previewList,
                                 lists: [], context: previewModelContainer.mainContext, tint: .appAccent)
        }
        .movieTrackerDestinations()
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
