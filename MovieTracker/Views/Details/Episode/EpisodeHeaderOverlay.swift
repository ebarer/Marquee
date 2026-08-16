//
//  EpisodeHeaderOverlay.swift
//  MovieTracker
//

import SwiftUI

/// The title, watched checkmark, and code/date/duration/rating line laid over the episode
/// still. Reveals the nav-bar title once the on-page title scrolls behind the bar.
struct EpisodeHeaderOverlay: View {
    let episode: Episode
    let tint: Color
    let navBarBottom: CGFloat
    @Binding var showNavTitle: Bool

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(episode.name)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .onGeometryChange(for: Bool.self) { proxy in
                    proxy.frame(in: .global).maxY <= navBarBottom
                } action: { crossed in
                    withAnimation(.easeInOut(duration: 0.2)) { showNavTitle = crossed }
                }

            HStack(alignment: .center, spacing: 12) {
                watchedButton
                VStack(alignment: .leading, spacing: 2) {
                    Text(codeAndDate)
                        .foregroundStyle(tint)
                    if episode.duration != nil || (episode.rating ?? 0) > 0 {
                        durationRating
                    }
                    if isWatched {
                        watchedDateRow
                            .transition(.opacity)
                    }
                }
                .font(.subheadline)
            }
            // Pin the row to the checkmark's height: the metadata stays vertically centered
            // on the checkmark and grows symmetrically, so the title above never moves.
            .frame(height: Self.checkmarkSize, alignment: .center)
            .animation(.easeInOut(duration: 0.25), value: isWatched)
        }
    }

    private static let checkmarkSize: CGFloat = 52

    /// Inert until the episode airs — there's nothing to have watched yet, and the dimmed
    /// checkmark says so rather than letting a tap record a future viewing.
    private var watchedButton: some View {
        Button { toggleWatched() } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isWatched ? .appBackground : tint)
                .frame(width: Self.checkmarkSize, height: Self.checkmarkSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(isWatched ? .regular.tint(tint).interactive() : .regular.interactive(), in: Circle())
        .opacity(episode.hasAired ? 1 : 0.4)
        .disabled(!episode.hasAired)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isWatched)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if !episode.hasAired { return "Episode hasn't aired yet" }
        return isWatched ? "Mark episode unwatched" : "Mark episode watched"
    }

    private var watchedDateRow: some View {
        HStack(spacing: 4) {
            Text("Watched")
                .foregroundStyle(.white.opacity(0.75))
            WatchedDateButton(
                showID: episode.showTmdbID, seasonNumber: episode.seasonNumber,
                episodeNumber: episode.episodeNumber,
                watchedDate: store?.episodeWatchedDate(showID: episode.showTmdbID,
                                                       season: episode.seasonNumber,
                                                       episode: episode.episodeNumber),
                airDate: episode.airDate, tint: tint)
        }
    }

    private var durationRating: some View {
        HStack(spacing: 5) {
            if let duration = episode.duration {
                Text(duration)
            }
            if let rating = episode.rating, rating > 0 {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                Text(String(format: "%.1f", rating / 2))
            }
        }
        .foregroundStyle(.white.opacity(0.75))
    }

    private var codeAndDate: String {
        var text = "S\(episode.seasonNumber), E\(episode.episodeNumber)"
        if let date = episode.airDate?.toString() { text += "  •  \(date)" }
        return text
    }

    private var isWatched: Bool {
        guard let store else { return false }
        _ = store.revision
        return store.isEpisodeWatched(showID: episode.showTmdbID,
                                      season: episode.seasonNumber, episode: episode.episodeNumber)
    }

    private func toggleWatched() {
        guard let store else { return }
        store.setEpisodeWatched(!isWatched, showID: episode.showTmdbID,
                                season: episode.seasonNumber, episode: episode.episodeNumber)
        // The episode page only knows the show id; reconcile through the shared path so the
        // season snapshot + Watch List membership end up where the season-detail toggle would.
        Task { @MainActor in
            await store.reconcile(showID: episode.showTmdbID, editedSeason: episode.seasonNumber)
        }
    }
}

#Preview {
    @Previewable @State var showNavTitle = false
    EpisodeHeaderOverlay(episode: Episode.previewEpisodes[0], tint: .appAccent,
                         navBarBottom: 100, showNavTitle: $showNavTitle)
        .padding()
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
}

#Preview("Hasn't aired") {
    @Previewable @State var showNavTitle = false
    var upcoming = Episode.previewEpisodes[2]
    upcoming.airDate = Date().addingTimeInterval(60 * 60 * 24 * 14)

    return EpisodeHeaderOverlay(episode: upcoming, tint: .appAccent,
                                navBarBottom: 100, showNavTitle: $showNavTitle)
        .padding()
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
}
