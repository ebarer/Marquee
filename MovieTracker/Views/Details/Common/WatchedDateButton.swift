//
//  WatchedDateButton.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The date a title was watched, tappable to open the shared ``WatchedDatePicker``. Maps
/// the stored UTC-midnight value back to the local day and writes the edited day through
/// the `MediaItem` for `key`.
struct WatchedDateButton: View {
    let key: MediaKey
    let tint: Color
    private let initialDate: Date

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    init(key: MediaKey, watchedDate: Date?, tint: Color) {
        self.key = key
        self.tint = tint
        self.initialDate = watchedDate.map(MediaItem.localDay)
            ?? Calendar.current.startOfDay(for: Date())
    }

    init(movie: Movie, watchedDate: Date?, tint: Color) {
        self.init(key: movie.mediaKey, watchedDate: watchedDate, tint: tint)
    }

    var body: some View {
        WatchedDatePicker(initialDate: initialDate, tint: tint,
                          quickSetTitle: "Release Date", quickSetDate: key.releaseDate) { newValue in
            store?.setDateWatched(MediaItem.floatingDay(from: newValue), forKey: key)
        }
    }
}

#Preview("Watched title") {
    WatchedDateButton(movie: Movie.previewList[1],
                      watchedDate: MediaItem.floatingDay(from: Date()), tint: .appAccent)
        .padding()
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
}

#Preview("Unset — defaults to today") {
    WatchedDateButton(movie: .preview, watchedDate: nil, tint: .yellow)
        .padding()
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
}
