//
//  SeasonWatchedDateButton.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The date a season was watched, tappable to open a graphical date picker — the per-season
/// analogue of `WatchedDateButton`, editing the season's `WatchedSeason.watchedAt`. Shown in
/// the episodes header once a season is complete.
struct SeasonWatchedDateButton: View {
    let showID: Int
    let seasonNumber: Int
    let tint: Color

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @State private var date: Date
    @State private var showPicker = false

    init(showID: Int, seasonNumber: Int, watchedDate: Date?, tint: Color) {
        self.showID = showID
        self.seasonNumber = seasonNumber
        self.tint = tint
        _date = State(initialValue: watchedDate ?? Calendar.current.startOfDay(for: Date()))
    }

    var body: some View {
        Button {
            showPicker = true
        } label: {
            Text("Watched \(date.formatted(.dateTime.month(.abbreviated).day().year()))")
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
                            Button(role: .confirm) { showPicker = false }
                        }
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Today") { date = Date() }
                        }
                    }
                    .onChange(of: date) { _, newValue in
                        store?.setSeasonWatchedDate(Calendar.current.startOfDay(for: newValue),
                                                    showID: showID, season: seasonNumber)
                    }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    SeasonWatchedDateButton(showID: 1, seasonNumber: 1, watchedDate: Date(), tint: .appAccent)
        .padding()
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
}
