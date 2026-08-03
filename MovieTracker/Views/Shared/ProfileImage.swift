//
//  ProfileImage.swift
//  MovieTracker
//
//  A circular person profile image with a placeholder. Loading, caching, and
//  revalidation live in the shared `RemoteImage`.
//

import SwiftUI

struct ProfileImage: View {
    let url: URL?

    var body: some View {
        RemoteImage(url: url) {
            ZStack {
                Color.appSeparator
                Image(systemName: "person.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(Circle())
    }
}

#Preview {
    ProfileImage(url: nil)
        .frame(width: 100, height: 100)
        .padding()
        .background(Color.appBackground)
}
