//
//  WatchStatsView.swift
//  MovieTracker
//

import SwiftUI
import Charts

/// Year in Review: what was finished, when, and how it was rated.
struct WatchStatsView: View {
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @State private var model: WatchStatsModel

    init() {
        _model = State(initialValue: WatchStatsModel())
    }

    init(preview: WatchStats) {
        _model = State(initialValue: WatchStatsModel.preview(preview))
    }

    private var stats: WatchStats { model.stats }

    var body: some View {
        List {
            if !stats.availableYears.isEmpty {
                Section { scopePicker }
            }

            if model.isLoading {
                Section { ProgressView().frame(maxWidth: .infinity) }
            } else if stats.isEmpty {
                Section {
                    ContentUnavailableView("Nothing Watched Yet",
                                           systemImage: "chart.bar",
                                           description: Text("Mark a title watched and it shows up here."))
                }
            } else {
                summarySection
                if stats.months.contains(where: { $0.movies > 0 }) {
                    activitySection("Movies by Month", unit: "Movies",
                                    value: \.movies, color: .appAccent)
                }
                if stats.months.contains(where: { $0.episodes > 0 }) {
                    activitySection("Episodes by Month", unit: "Episodes",
                                    value: \.episodes, color: ListDestination.watchedColor)
                }
                if !stats.topShows.isEmpty { topShowsSection }
                if stats.ratedCount > 0 { ratingsSection }
                highlightsSection
            }
        }
        .navigationTitle("Year in Review")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: model.scope) { await model.load(store: store) }
    }

    // MARK: - Sections

    private var scopePicker: some View {
        Picker("Period", selection: $model.scope) {
            Text(WatchStats.Scope.allTime.title).tag(WatchStats.Scope.allTime)
            ForEach(stats.availableYears, id: \.self) { year in
                Text(String(year)).tag(WatchStats.Scope.year(year))
            }
        }
    }

    private var summarySection: some View {
        Section("Summary") {
            LabeledContent("Titles Finished", value: "\(stats.titlesFinished)")
            if stats.moviesWatched > 0 {
                LabeledContent("Movies", value: "\(stats.moviesWatched)")
            }
            if stats.seasonsCompleted > 0 {
                LabeledContent("Seasons", value: "\(stats.seasonsCompleted)")
            }
            if stats.episodesWatched > 0 {
                LabeledContent("Episodes", value: "\(stats.episodesWatched)")
            }
            if stats.showsWatched > 0 {
                LabeledContent("Shows", value: "\(stats.showsWatched)")
            }
        }
    }

    // Movies and episodes are counted separately: stacked, the bar height had no single unit and the
    // movie band vanished against thousands of episodes.
    private func activitySection(_ title: String, unit: String,
                                 value: KeyPath<WatchStats.MonthBucket, Int>,
                                 color: Color) -> some View {
        Section {
            Chart(stats.months) { bucket in
                BarMark(x: .value("Month", monthLabel(bucket.month)),
                        y: .value(unit, bucket[keyPath: value]))
                    .foregroundStyle(color)
            }
            .chartLegend(.hidden)
            // Categorical axes sort alphabetically without an explicit domain.
            .chartXScale(domain: (1...12).map(monthLabel))
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 160)
            .padding(.vertical, 8)
        } header: {
            Text(title)
        } footer: {
            Text(unit + " watched each month.")
        }
    }

    private var topShowsSection: some View {
        Section("Most Watched Shows") {
            ForEach(stats.topShows) { show in
                LabeledContent(show.name, value: episodeCount(show.episodes))
            }
        }
    }

    private var ratingsSection: some View {
        Section {
            ForEach(ratingRows, id: \.stars) { row in
                LabeledContent {
                    Text("\(row.count)")
                } label: {
                    StarRating(display: row.stars, size: 15,
                               tint: ListDestination.watchedColor)
                        // Without this the separator starts at the stars' trailing edge.
                        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
                }
            }
        } header: {
            Text("Your Ratings")
        } footer: {
            if let average = stats.averageRating {
                Text("Average \(average, format: .number.precision(.fractionLength(1))) across \(stats.ratedCount) rated \(stats.ratedCount == 1 ? "title" : "titles").")
            }
        }
    }

    private var highlightsSection: some View {
        Section {
            if let duration = RuntimeLabel.duration(minutes: stats.totalMinutes) {
                LabeledContent("Time Watched", value: duration)
            }
            if let duration = RuntimeLabel.duration(minutes: stats.movieMinutes),
               stats.episodeMinutes > 0 {
                LabeledContent("Movies", value: duration)
            }
            if let duration = RuntimeLabel.duration(minutes: stats.episodeMinutes),
               stats.movieMinutes > 0 {
                LabeledContent("TV", value: duration)
            }
            if let busiest = stats.busiestMonth {
                LabeledContent("Busiest Month",
                               value: "\(monthName(busiest.month)) · \(busiest.total)")
            }
            if stats.longestStreakDays > 1 {
                LabeledContent("Longest Streak", value: "\(stats.longestStreakDays) days")
            }
        } header: {
            Text("Highlights")
        } footer: {
            if let caveat = runtimeCaveat { Text(caveat) }
        }
    }

    // MARK: - Formatting

    private var runtimeCaveat: String? {
        var parts: [String] = []
        if stats.moviesMissingRuntime > 0 {
            let movies = stats.moviesMissingRuntime == 1 ? "movie" : "movies"
            parts.append("\(stats.moviesMissingRuntime) \(movies)")
        }
        if stats.episodesMissingRuntime > 0 {
            let episodes = stats.episodesMissingRuntime == 1 ? "episode" : "episodes"
            parts.append("\(stats.episodesMissingRuntime) \(episodes)")
        }
        guard !parts.isEmpty else { return nil }
        return "Excludes \(parts.joined(separator: " and ")) with no known length."
    }

    private var ratingRows: [(stars: Double, count: Int)] {
        stats.ratings
            .filter { $0.value > 0 }
            .map { (stars: Double($0.key) / 2, count: $0.value) }
            .sorted { $0.stars > $1.stars }
    }

    private func episodeCount(_ count: Int) -> String {
        "\(count) \(count == 1 ? "episode" : "episodes")"
    }

    // Short names, not initials: J/M/A each repeat, and Charts would merge those months into one bar.
    private static let shortMonths = DateFormatter().shortMonthSymbols ?? []
    private static let months = DateFormatter().monthSymbols ?? []

    private func monthLabel(_ month: Int) -> String {
        Self.shortMonths[safe: month - 1] ?? "\(month)"
    }

    private func monthName(_ month: Int) -> String {
        Self.months[safe: month - 1] ?? "\(month)"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview("Populated") {
    NavigationStack {
        WatchStatsView(preview: .preview)
    }
    .preferredColorScheme(.dark)
}

#Preview("Ratings & Highlights") {
    NavigationStack {
        WatchStatsView(preview: .previewMoviesOnly)
    }
    .preferredColorScheme(.dark)
}

#Preview("Empty") {
    NavigationStack {
        WatchStatsView(preview: WatchStats(availableYears: []))
    }
    .preferredColorScheme(.dark)
}

extension WatchStats {
    static var preview: WatchStats {
        var stats = WatchStats()
        stats.scope = .year(2026)
        stats.availableYears = [2026, 2025, 2024]
        stats.moviesWatched = 42
        stats.movieMinutes = 5_412
        stats.moviesMissingRuntime = 3
        stats.episodesWatched = 186
        stats.episodeMinutes = 8_130
        stats.episodesMissingRuntime = 4
        stats.seasonsCompleted = 14
        stats.showsWatched = 9
        stats.months = [
            .init(month: 1, movies: 5, episodes: 22), .init(month: 2, movies: 3, episodes: 14),
            .init(month: 3, movies: 6, episodes: 9), .init(month: 4, movies: 2, episodes: 31),
            .init(month: 5, movies: 4, episodes: 18), .init(month: 6, movies: 7, episodes: 12),
            .init(month: 7, movies: 1, episodes: 26), .init(month: 8, movies: 5, episodes: 20),
            .init(month: 9, movies: 3, episodes: 8), .init(month: 10, movies: 4, episodes: 6),
            .init(month: 11, movies: 2, episodes: 11), .init(month: 12, movies: 0, episodes: 9)
        ]
        stats.topShows = [
            .init(showTmdbID: 1, name: "Severance", episodes: 38),
            .init(showTmdbID: 2, name: "The Bear", episodes: 28),
            .init(showTmdbID: 3, name: "Slow Horses", episodes: 24),
            .init(showTmdbID: 4, name: "Andor", episodes: 22),
            .init(showTmdbID: 5, name: "Shrinking", episodes: 16)
        ]
        stats.ratings = [10: 8, 9: 11, 8: 14, 7: 6, 6: 3, 5: 2]
        stats.ratedCount = 44
        stats.averageRating = 4.1
        stats.longestStreakDays = 12
        stats.busiestMonth = .init(month: 4, movies: 2, episodes: 31)
        return stats
    }

    static var previewMoviesOnly: WatchStats {
        var stats = WatchStats()
        stats.scope = .allTime
        stats.availableYears = [2026, 2025]
        stats.moviesWatched = 12
        stats.movieMinutes = 1_487
        stats.moviesMissingRuntime = 2
        stats.ratings = [10: 3, 9: 4, 7: 2, 4: 1]
        stats.ratedCount = 10
        stats.averageRating = 4.05
        stats.longestStreakDays = 4
        return stats
    }
}
