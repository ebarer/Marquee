//
//  WatchedDate.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The date the user watched a title, tappable to open a graphical date picker.
/// Changes write straight through to the `MediaItem`.
struct WatchedDate: View {
    let movie: Movie
    let context: ModelContext
    let tint: Color

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
                        MediaItem.setDateWatched(MediaItem.floatingDay(from: newValue),
                                                 for: movie, in: context)
                    }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}
