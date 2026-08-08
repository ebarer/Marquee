//
//  PersonFilmography.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The person's movie + TV credits grouped into per-year sections, with upcoming work
/// in a collapsible section.
struct PersonFilmography: View {
    let credits: [MediaRef]
    let lists: [MediaList]
    @Binding var hideExtraneous: Bool
    var navBarBottom: CGFloat = 0
    var onFilterHiddenChange: (Bool) -> Void = { _ in }

    @State private var upcomingExpanded = false

    var body: some View {
        if !visibleCredits.isEmpty {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                header
                if !upcomingCredits.isEmpty {
                    upcomingSection
                }
                ForEach(releasedByYear, id: \.year) { group in
                    Section {
                        rows(group.credits)
                    } header: {
                        SectionHeader(title: String(group.year), color: .appAccent)
                            .background(Color.appBackground)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rows(_ items: [MediaRef]) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, ref in
            row(ref)
            if index < items.count - 1 {
                Rectangle()
                    .fill(Color.appSeparator)
                    .frame(height: 0.5)
                    .padding(.leading, 79)
            }
        }
    }

    @ViewBuilder
    private func row(_ ref: MediaRef) -> some View {
        switch ref {
        case .movie(let movie): movieRow(movie)
        case .show(let show): showRow(show)
        }
    }

    private func movieRow(_ movie: Movie) -> some View {
        NavigationLink(value: movie) {
            HStack(spacing: 8) {
                MovieRow(movie: movie, role: movie.creditRole, derivesStatus: true)
                chevron
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            WatchedSwipeButton(movie: movie)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            WatchListSwipeButton(movie: movie)
        }
        .movieContextMenu(for: movie, lists: lists)
    }

    private func showRow(_ show: Show) -> some View {
        NavigationLink(value: show) {
            HStack(spacing: 8) {
                ShowRow(show: show, role: show.creditRole, showsSeasonCount: false,
                        episodeCount: show.episodeCount)
                chevron
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
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

    @ViewBuilder
    private var upcomingSection: some View {
        Button {
            withAnimation(.easeInOut) { upcomingExpanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text("Upcoming")
                    .font(.headline)
                    .foregroundStyle(Color.appAccent)
                Text("(\(upcomingCredits.count))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(upcomingExpanded ? 90 : 0))
                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Upcoming, \(upcomingCredits.count) titles")
        .accessibilityHint(upcomingExpanded ? "Collapses the section" : "Expands the section")

        if upcomingExpanded {
            rows(upcomingCredits)
        }
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
