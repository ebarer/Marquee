//
//  MovieMetadataStrip.swift
//  MovieTracker
//
//  Horizontal strip of movie metadata cells (rating, credit clips, TMDB score,
//  genre) shown on the movie detail screen.
//

import SwiftUI

struct MovieMetadataStrip: View {
    let movie: Movie

    var body: some View {
        VStack(spacing: 0) {
            hairline
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    cell(header: "RATING") {
                        if let cert = movie.certification, let image = UIImage(named: "Cert-\(cert)") {
                            // Cap width as well as height so wide certs (e.g. "PG-13")
                            // don't tower over compact ones (e.g. "R").
                            Image(uiImage: image)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 44, maxHeight: 24)
                                .foregroundStyle(.white)
                        } else {
                            valueText("N/A")
                        }
                    }
                    divider
                    cell(header: "CREDIT CLIPS") { valueText(movie.bonusString) }
                    divider
                    cell(header: "TMDB.org") { valueText(tmdbScore) }
                    divider
                    cell(header: "GENRE") { valueText(movie.genresString) }
                }
            }
            // Always allow elastic scrolling, even when the cells fit within the width.
            .scrollBounceBehavior(.always, axes: .horizontal)
            hairline
        }
    }

    private var tmdbScore: String {
        if let rating = movie.rating, rating > 0 {
            return String(format: "%.1f / 5", rating / 2)
        }
        return "N/A"
    }

    // Equal-width column: title label at the top, value beneath it.
    private func cell<Content: View>(header: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) {
            Text(header)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .frame(width: 104, alignment: .top)
        .padding(.vertical, 14)
    }

    private func valueText(_ text: String) -> some View {
        Text(text).multilineTextAlignment(.center)
    }

    // Full-width top/bottom rule.
    private var hairline: some View {
        Rectangle()
            .fill(Color.appSeparator)
            .frame(height: 0.5)
    }

    // Vertical rule between columns. Inset top/bottom by the same amount as the cell's vertical
    // text padding so it doesn't touch the top/bottom hairlines.
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
