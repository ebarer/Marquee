//
//  SeasonWatchedDateButton.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The season's watched date beside the checkmark, tappable to open a graphical date picker —
/// the per-season analogue of `WatchedDateButton`, editing `WatchedSeason.watchedAt`. Shown in
/// the episodes header once a season is complete, with the season's star rating stacked below.
struct SeasonWatchedDateButton: View {
    let showID: Int
    let seasonNumber: Int
    let lastEpisodeDate: Date?
    let tint: Color

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @State private var date: Date
    @State private var showPicker = false

    init(showID: Int, seasonNumber: Int, watchedDate: Date?, lastEpisodeDate: Date?, tint: Color) {
        self.showID = showID
        self.seasonNumber = seasonNumber
        self.lastEpisodeDate = lastEpisodeDate
        self.tint = tint
        _date = State(initialValue: watchedDate ?? Calendar.current.startOfDay(for: Date()))
    }

    var body: some View {
        Button {
            showPicker = true
        } label: {
            Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                .font(.subheadline)
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
                        ToolbarItemGroup(placement: .topBarLeading) {
                            Button("Today") { date = Date() }
                            if let lastEpisodeDate, lastEpisodeDate <= Date() {
                                Button("Last Episode Date") { date = lastEpisodeDate }
                            }
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
    SeasonWatchedDateButton(showID: 1, seasonNumber: 1, watchedDate: Date(),
                            lastEpisodeDate: Date(), tint: .appAccent)
        .padding()
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
}
