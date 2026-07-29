//
//  RemoteImages.swift
//  MovieTracker
//
//  Reusable async image views backed by TMDB image URLs. On iOS 27
//  AsyncImage applies HTTP caching automatically, so posters are not
//  re-downloaded when scrolling back.
//

import SwiftUI

/// A movie poster / backdrop image that fills its frame, with a placeholder.
struct PosterImage: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ZStack {
                Color.appSeparator
                Image(systemName: "film")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A circular person profile image with a placeholder.
struct ProfileImage: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ZStack {
                Color.appSeparator
                Image(systemName: "person.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(Circle())
    }
}
