//
//  MovieRow.swift
//  MovieTracker
//

import SwiftUI

struct MovieRow: View {
    let movie: Movie
    var subtitle: String? = nil
    var role: String? = nil
    /// Non-acting jobs on the title, on a line of their own so the character keeps one.
    var jobs: String? = nil
    var showsSubtitle: Bool = true
    var duration: String? = nil
    var rating: Double? = nil
    var ratingTint: Color = .appAccent
    var status: PosterStatus? = nil
    var derivesStatus: Bool = false

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: movie.posterURL(.w185))
                .frame(width: 51, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .posterBorder(cornerRadius: 6)
                .overlay { badge }
                .padding(.vertical, 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.body)
                    .lineLimit(2)

                if showsSubtitle, let displayedSubtitle {
                    Text(displayedSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let role, !role.isEmpty {
                    Text(role)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let jobs, !jobs.isEmpty {
                    // Unbounded: a person credited several ways on one title lists every job,
                    // and on a short they did themselves that runs to a few lines.
                    Text(jobs)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let duration, !duration.isEmpty {
                    Text(duration)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let rating, rating > 0 {
                    StarRating(display: rating, tint: ratingTint)
                        .padding(.top, 1)
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var badge: some View {
        if let effectiveStatus {
            PosterStatusBadge(status: effectiveStatus, cornerRadius: 6, scale: 0.72)
                .transition(.opacity)
        }
    }

    private var effectiveStatus: PosterStatus? {
        if let status { return status }
        guard derivesStatus, let store else { return nil }
        return .derive(movieID: movie.id, from: store.badges)
    }

    private var displayedSubtitle: String? {
        subtitle ?? movie.releaseDate?.toString()
    }
}

#Preview {
    List {
        MovieRow(movie: .preview, status: .watched)
        MovieRow(movie: .preview, status: .watchList)
        MovieRow(movie: .preview)
    }
    .listStyle(.plain)
    .preferredColorScheme(.dark)
}
