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
    let context: ModelContext
    let tint: Color

    @Environment(MediaStore.self) private var store: MediaStore?
    /// Defaults to today for items that predate watched-date tracking (only
    /// persisted once the user picks a date).
    @State private var date: Date
    @State private var showPicker = false

    init(movie: Movie, context: ModelContext, tint: Color) {
        self.movie = movie
        self.context = context
        self.tint = tint
        // Stored value is canonical UTC-midnight; map back to the same local day.
        let stored = MediaItem.dateWatched(for: movie, in: context)
        _date = State(initialValue: stored.map(MediaItem.localDay)
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
    // previewList[1] is seeded watched (today) in the preview container.
    WatchedDateButton(movie: Movie.previewList[1],
                      context: previewModelContainer.mainContext, tint: .appAccent)
        .padding()
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .preferredColorScheme(.dark)
}

#Preview("Unset — defaults to today") {
    WatchedDateButton(movie: .preview,
                      context: previewModelContainer.mainContext, tint: .yellow)
        .padding()
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .preferredColorScheme(.dark)
}
