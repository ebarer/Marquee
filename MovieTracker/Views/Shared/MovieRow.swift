//
//  MovieRow.swift
//  MovieTracker
//
//  List row: poster beside title + release date. Replaces `MovieTableViewCell`.
//

import SwiftUI

struct MovieRow: View {
    let movie: Movie
    var subtitle: String? = nil
    /// An optional secondary line below the subtitle, e.g. the person's role in
    /// this movie when shown in a filmography.
    var role: String? = nil
    /// When false, the row shows no subtitle line at all — no explicit subtitle
    /// and no release-date fallback.
    var showsSubtitle: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: movie.posterURL(.w185))
                .frame(width: 51, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                // Slightly shorter poster (3pt top/bottom) so rows breathe and
                // the first result clears the scope bar.
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
                        .lineLimit(1)
                }
            }

            Spacer()
        }
    }

    private var displayedSubtitle: String? {
        subtitle ?? movie.releaseDate?.toString()
    }
}

#Preview {
    MovieRow(movie: .preview)
}
