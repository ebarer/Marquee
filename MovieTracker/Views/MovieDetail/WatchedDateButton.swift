//
//  WatchedDateButton.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The date the user watched a title, tappable to open a graphical date picker.
struct WatchedDateButton: View {
    let movie: Movie
    let tint: Color

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @State private var date: Date
    @State private var showPicker = false

    /// `watchedDate` is the stored canonical UTC-midnight value (nil if unset).
    init(movie: Movie, watchedDate: Date?, tint: Color) {
        self.movie = movie
        self.tint = tint
        // Map the stored UTC-midnight day back to the same local day.
        _date = State(initialValue: watchedDate.map(MediaItem.localDay)
                      ?? Calendar.current.startOfDay(for: Date()))
    }

    var body: some View {
        Button {
            showPicker = true
        } label: {
            // System timezone (not the UTC-pinned detail formatter) so the shown day
            // matches the picker selection.
            Text(date, format: .dateTime.month(.abbreviated).day().year())
                .foregroundStyle(tint)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                DatePicker("Date Watched", selection: $date, in: ...Date(),
                           displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(tint)
                    .padding(.horizontal)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(role: .confirm) {
                                showPicker = false
                            }
                        }
                        ToolbarItemGroup(placement: .topBarLeading) {
                            Button("Today") { date = Date() }
                            if let releaseDate = movie.releaseDate, releaseDate <= Date() {
                                Button("Release Date") {
                                    date = MediaItem.localDay(from: releaseDate)
                                }
                            }
                        }
                    }
                    .onChange(of: date) { _, newValue in
                        store?.setDateWatched(MediaItem.floatingDay(from: newValue), for: movie)
                    }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
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
