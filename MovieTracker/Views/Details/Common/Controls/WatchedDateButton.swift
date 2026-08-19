//
//  WatchedDateButton.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// A watched date for a title, season, or episode, tappable to open ``WatchedDatePicker``.
/// `Target` routes the edited day to the right `PersistenceCoordinator` write.
struct WatchedDateButton: View {
    enum Target {
        case movie(MediaKey)
        case season(showID: Int, seasonNumber: Int)
        case episode(showID: Int, seasonNumber: Int, episodeNumber: Int)
    }

    private let target: Target
    private let tint: Color
    private let font: Font?
    private let initialDate: Date
    private let quickSetTitle: String
    private let quickSetDate: Date?

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    /// Release and air dates arrive at UTC midnight, while the picker works in `Calendar.current`:
    /// a quick-set day would land the evening before west of UTC without this.
    private static func localDay(_ date: Date?) -> Date? { date.map(MediaItem.localDay) }

    init(key: MediaKey, watchedDate: Date?, tint: Color, font: Font? = nil) {
        self.target = .movie(key)
        self.tint = tint
        self.font = font
        self.initialDate = watchedDate.map(MediaItem.localDay)
            ?? Calendar.current.startOfDay(for: Date())
        self.quickSetTitle = "Release Date"
        self.quickSetDate = Self.localDay(key.releaseDate)
    }

    init(movie: Movie, watchedDate: Date?, tint: Color, font: Font? = nil) {
        self.init(key: movie.mediaKey, watchedDate: watchedDate, tint: tint, font: font)
    }

    init(showID: Int, seasonNumber: Int, watchedDate: Date?,
         lastEpisodeDate: Date?, tint: Color, font: Font? = .subheadline) {
        self.target = .season(showID: showID, seasonNumber: seasonNumber)
        self.tint = tint
        self.font = font
        self.initialDate = watchedDate ?? Calendar.current.startOfDay(for: Date())
        self.quickSetTitle = "Last Episode Date"
        self.quickSetDate = Self.localDay(lastEpisodeDate)
    }

    init(showID: Int, seasonNumber: Int, episodeNumber: Int, watchedDate: Date?,
         airDate: Date?, tint: Color, font: Font? = .subheadline) {
        self.target = .episode(showID: showID, seasonNumber: seasonNumber, episodeNumber: episodeNumber)
        self.tint = tint
        self.font = font
        self.initialDate = watchedDate ?? Calendar.current.startOfDay(for: Date())
        self.quickSetTitle = "Air Date"
        self.quickSetDate = Self.localDay(airDate)
    }

    var body: some View {
        WatchedDatePicker(initialDate: initialDate, tint: tint, font: font,
                          quickSetTitle: quickSetTitle, quickSetDate: quickSetDate, onChange: commit)
    }

    private func commit(_ newValue: Date) {
        let day = Calendar.current.startOfDay(for: newValue)
        switch target {
        case .movie(let key):
            store?.setDateWatched(MediaItem.floatingDay(from: newValue), forKey: key)
        case .season(let showID, let seasonNumber):
            store?.setSeasonWatchedDate(day, showID: showID, season: seasonNumber)
        case .episode(let showID, let seasonNumber, let episodeNumber):
            store?.setEpisodeWatchedDate(day, showID: showID, season: seasonNumber, episode: episodeNumber)
        }
    }
}

#Preview("Movie — watched") {
    WatchedDateButton(movie: Movie.previewList[1],
                      watchedDate: MediaItem.floatingDay(from: Date()), tint: .appAccent)
        .padding()
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
}

#Preview("Season") {
    WatchedDateButton(showID: 1, seasonNumber: 1, watchedDate: Date(),
                      lastEpisodeDate: Date(), tint: .appAccent)
        .padding()
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
}

#Preview("Episode") {
    WatchedDateButton(showID: 1, seasonNumber: 1, episodeNumber: 1, watchedDate: Date(),
                      airDate: Date(), tint: .appAccent)
        .padding()
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
}
