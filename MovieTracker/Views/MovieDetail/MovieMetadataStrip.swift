//
//  MovieMetadataStrip.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// A horizontal strip of metadata cells (rating, credit clips, TMDB score, genre)
/// on the movie detail screen. Watched movies lead with the user's own rating and
/// watched date.
struct MovieMetadataStrip: View {
    let movie: Movie
    var watchedList: MovieList? = nil
    var context: ModelContext? = nil
    var tint: Color = .appAccent
    /// Whether the movie is on the Watched list; passed in (not derived) so the
    /// MY RATING cell animates when the status changes.
    var isWatched: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            hairline
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    if let watchedList, let context, isWatched {
                        HStack(alignment: .top, spacing: 0) {
                            cell(header: "MY RATING") {
                                StarRating(movieID: movie.id, list: watchedList, context: context, tint: tint)
                            }
                            divider
                            cell(header: "WATCHED", minWidth: 80) {
                                WatchedDate(movieID: movie.id, list: watchedList, context: context, tint: tint)
                            }
                            divider
                        }
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                    cell(header: "RATING", minWidth: 60) {
                        if let cert = movie.certification, let image = UIImage(named: "Cert-\(cert)") {
                            // Definite frame so the resizable badge can't expand to its
                            // native width; scaledToFit letterboxes narrow certs.
                            Image(uiImage: image)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 24)
                                .foregroundStyle(.white)
                        } else {
                            valueText("N/A")
                        }
                    }
                    divider
                    cell(header: "CREDIT CLIPS") { valueText(movie.bonusString) }
                    divider
                    cell(header: "TMDB.org") { tmdbScore.multilineTextAlignment(.center) }
                    divider
                    cell(header: "GENRE", minWidth: 90) { valueText(movie.genresString) }
                }
                .animation(.snappy, value: isWatched)
            }
            .scrollBounceBehavior(.always, axes: .horizontal)
            hairline
        }
    }

    /// The TMDB score over "/ 5", with the number emphasized. Whole scores drop the
    /// decimal (4.0 → "4").
    private var tmdbScore: Text {
        guard let rating = movie.rating, rating > 0 else {
            return Text("N/A")
        }
        let score = (rating / 2 * 10).rounded() / 10
        let formatted = score == score.rounded()
            ? String(format: "%.0f", score)
            : String(format: "%.1f", score)
        return Text("\(formatted)\(Text(" / 5").foregroundColor(.secondary))")
    }

    private func cell<Content: View>(header: String, minWidth: CGFloat = 44,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) {
            Text(header)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .fixedSize()
        .frame(minWidth: minWidth, alignment: .top)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func valueText(_ text: String) -> some View {
        Text(text).multilineTextAlignment(.center)
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.appSeparator)
            .frame(height: 0.5)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.appSeparator)
            .frame(width: 0.5)
            .frame(maxHeight: .infinity)
            .padding(.vertical, 14)
    }
}

#Preview {
    MovieMetadataStrip(movie: .preview)
        .background(Color.appBackground)
}
