//
//  ShowEpisodeCreditsView.swift
//  MovieTracker
//

import SwiftUI

/// A person's episodes within one show — where every TV credit of theirs goes, since the
/// show alone never says which episodes they were in.
struct ShowEpisodeCredits: Hashable {
    let show: Show
    /// Nil where the caller hasn't resolved it (Known For, or a row tapped mid-fetch), and
    /// the screen resolves it from the show's credit ids instead.
    var credit: EpisodeCredit? = nil
    /// Set where the screen was reached from the show rather than from the person, so they head
    /// the list instead of the show already being read.
    var person: Person? = nil

    /// A hit in a show's cast search: their own roles carry the credit ids the episodes resolve
    /// from, and the show is stripped to what this screen reads.
    init(person: Person, in show: Show) {
        var subject = Show(id: show.id, name: show.name)
        subject.poster = show.poster
        subject.creditIDs = person.creditIDs ?? []
        subject.creditRole = person.role
        self.show = subject
        self.person = person
    }

    init(show: Show, credit: EpisodeCredit? = nil) {
        self.show = show
        self.credit = credit
    }
}

/// Where a filmography row goes. One value type, so the row's link keeps its identity when
/// the credit resolves under it — swapping the link itself would drop a tap in flight.
enum ShowCreditDestination: Hashable {
    case show(Show)
    case episodes(ShowEpisodeCredits)
}

struct ShowEpisodeCreditsView: View {
    let credit: ShowEpisodeCredits

    @State private var model = ShowEpisodeCreditsModel()
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    private static let subjectPoster = CGSize(width: EpisodeRow.stillWidth,
                                             height: EpisodeRow.stillWidth * 3 / 2)

    init(credit: ShowEpisodeCredits) {
        self.credit = credit
    }

    /// Previews only: inject a pre-seeded model so the screen renders populated state offline.
    init(preview credit: ShowEpisodeCredits, model: ShowEpisodeCreditsModel) {
        self.credit = credit
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                subjectRow

                if !model.hasLoaded {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                } else if model.groups.isEmpty {
                    Text("No episodes listed for this credit.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                } else {
                    ForEach(model.groups) { group in
                        SectionHeader(title: group.season.name, color: .appAccent)
                        SeasonEpisodeList(episodes: group.episodes,
                                          watchedNumbers: watchedNumbers(in: group.season),
                                          role: credit.show.creditRole,
                                          onToggle: { toggle($0, in: group.season) })
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationTitle("\(credit.show.name) Episodes")
        .toolbarTitleDisplayMode(.inline)
        .task { await model.load(credit) }
    }

    /// The episodes' subject at the top, and a way into their page, which is otherwise a screen
    /// back: the person when the show sent them here, else the show itself.
    @ViewBuilder
    private var subjectRow: some View {
        if let person = credit.person {
            CastPersonRow(person: person, showsEpisodeCount: person.episodeCount != nil,
                          imageSize: EpisodeRow.stillWidth)
        } else {
            showRow
        }
    }

    /// The show as search presents it, its poster as wide as the stills below so every line of
    /// text on the screen starts at the same edge.
    private var showRow: some View {
        NavigationLink(value: credit.show) {
            HStack(spacing: 8) {
                ShowRow(show: credit.show, derivesStatus: true, posterSize: Self.subjectPoster)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.rowPress)
    }

    private func watchedNumbers(in season: Season) -> Set<Int> {
        guard let store else { return [] }
        _ = store.revision
        return store.watchedEpisodeNumbers(showID: credit.show.id, season: season.seasonNumber)
    }

    private func toggle(_ episode: Episode, in season: Season) {
        // The credit stub carries no seasons, and membership reconciliation reads them.
        guard let store, let show = model.show else { return }
        store.toggleEpisodeWatched(show: show, season: season,
                                   episodeNumber: episode.episodeNumber)
    }
}

#Preview {
    let seasons = Season.previewSeasons
    let episodes = Episode.previewEpisodes
    var guestSpot = episodes[1]
    guestSpot.seasonNumber = 2
    var show = Show.preview
    show.creditRole = "Alex Kelly"
    let credit = ShowEpisodeCredits(
        show: show,
        credit: EpisodeCredit(seasons: [
            .init(season: seasons[0], episodeNumbers: [1, 3]),
            .init(season: seasons[1], episodeNumbers: [2]),
        ])
    )

    return NavigationStack {
        ShowEpisodeCreditsView(
            preview: credit,
            model: .preview(show: show, groups: [
                .init(season: seasons[1], episodes: [guestSpot]),
                .init(season: seasons[0], episodes: [episodes[2], episodes[0]]),
            ])
        )
        .detailDestinations()
    }
    .modelContainer(detailPreviewContainer)
    .environment(PersistenceCoordinator(detailPreviewContainer.mainContext))
    .preferredColorScheme(.dark)
}

// Reached from a show's cast search, where the person heads the list instead of the show.
#Preview("Person") {
    let seasons = Season.previewSeasons
    let episodes = Episode.previewEpisodes
    var person = Person.preview
    person.role = "Alex Kelly"
    person.episodeCount = 2
    var show = Show.preview
    show.creditRole = person.role

    return NavigationStack {
        ShowEpisodeCreditsView(
            preview: ShowEpisodeCredits(person: person, in: show),
            model: .preview(show: show, groups: [
                .init(season: seasons[0], episodes: [episodes[2], episodes[0]]),
            ])
        )
        .detailDestinations()
    }
    .modelContainer(detailPreviewContainer)
    .environment(PersistenceCoordinator(detailPreviewContainer.mainContext))
    .preferredColorScheme(.dark)
}

#Preview("Loading") {
    NavigationStack {
        ShowEpisodeCreditsView(
            preview: ShowEpisodeCredits(show: .preview, credit: EpisodeCredit(seasons: [])),
            model: ShowEpisodeCreditsModel()
        )
    }
    .modelContainer(detailPreviewContainer)
    .environment(PersistenceCoordinator(detailPreviewContainer.mainContext))
    .preferredColorScheme(.dark)
}
