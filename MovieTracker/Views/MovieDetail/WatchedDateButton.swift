//
//  WatchedDateButton.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The date the user watched a title, tappable to open a graphical date picker.
/// Changes write straight through to the `MediaItem`.
struct WatchedDateButton: View {
    let movie: Movie
    let tint: Color

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    /// Defaults to today for items that predate watched-date tracking (only
    /// persisted once the user picks a date).
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
                    .padding()
                    .frame(maxHeight: .infinity, alignment: .top)
                    .navigationTitle("Date Watched")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Today") { date = Date() }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button { showPicker = false } label: {
                                Image(systemName: "checkmark")
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
