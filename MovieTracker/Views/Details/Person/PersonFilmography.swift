//
//  PersonFilmography.swift
//  MovieTracker
//

import SwiftUI

/// The person's movie + TV credits grouped into per-year sections (``FilmographyRows``),
/// with upcoming work in a collapsible ``UpcomingSection``.
struct PersonFilmography: View {
    let credits: [MediaRef]
    let lists: [MediaList]
    @Binding var hideExtraneous: Bool
    var navBarBottom: CGFloat = 0
    var onFilterHiddenChange: (Bool) -> Void = { _ in }

    var body: some View {
        if !visibleCredits.isEmpty {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                header
                if !upcomingCredits.isEmpty {
                    UpcomingSection(credits: upcomingCredits, lists: lists)
                }
                ForEach(releasedByYear, id: \.year) { group in
                    Section {
                        FilmographyRows(credits: group.credits, lists: lists)
                    } header: {
                        SectionHeader(title: String(group.year), color: .appAccent)
                            .background(Color.appBackground)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Credits")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer(minLength: 8)
            if hasExtraneousCredits {
                Button {
                    withAnimation(.easeInOut) { hideExtraneous.toggle() }
                } label: {
                    Image(systemName: hideExtraneous
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                        .font(.title3)
                }
                .tint(.appAccent)
                .accessibilityLabel(hideExtraneous ? "Show all credits" : "Hide Self and Thanks credits")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 4)
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.frame(in: .global).maxY <= navBarBottom
        } action: { onFilterHiddenChange($0) }
    }

    private var hasExtraneousCredits: Bool {
        credits.contains { $0.isExtraneousCredit }
    }

    private var visibleCredits: [MediaRef] {
        hideExtraneous ? credits.filter { !$0.isExtraneousCredit } : credits
    }

    /// Credits with a date still in the future. Undated credits are omitted entirely.
    private var upcomingCredits: [MediaRef] {
        let now = Date()
        return visibleCredits.filter { ($0.date.map { $0 > now }) ?? false }
    }

    /// Released credits grouped into descending per-year sections. Credits arrive
    /// sorted newest-first, so grouping in order preserves that ordering.
    private var releasedByYear: [(year: Int, credits: [MediaRef])] {
        let now = Date()
        var groups: [(year: Int, credits: [MediaRef])] = []
        for ref in visibleCredits {
            guard let date = ref.date, date <= now else { continue }
            let year = Calendar.current.component(.year, from: date)
            if let index = groups.indices.last, groups[index].year == year {
                groups[index].credits.append(ref)
            } else {
                groups.append((year: year, credits: [ref]))
            }
        }
        return groups
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            LazyVStack(spacing: 0) {
                PersonFilmography(credits: Person.preview.allCredits, lists: [],
                                  hideExtraneous: .constant(true))
            }
        }
        .detailDestinations()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
