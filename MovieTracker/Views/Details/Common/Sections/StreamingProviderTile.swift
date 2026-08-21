//
//  StreamingProviderTile.swift
//  MovieTracker
//

import SwiftUI

/// A streaming-provider logo tile opening the provider's page, or the JustWatch fallback link.
struct StreamingProviderTile: View {
    let group: ProviderGroup
    let fallback: URL?
    var size: CGFloat = 56

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = group.appURL ?? fallback {
                openURL(url)
            }
        } label: {
            RemoteImage(url: group.logoURL(size: "w154")) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.appSeparator)
                    .overlay {
                        Text(group.name.prefix(1))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            // A dark logo on a dark page needs the poster's edge to read as a tile at all.
            .posterBorder(cornerRadius: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(group.name)
    }
}

#Preview {
    let groups = ProviderCatalog.grouped(Movie.preview.watchByRegion?.values.first?.providers ?? [])
    return HStack(spacing: 12) {
        ForEach(groups.prefix(3)) { group in
            StreamingProviderTile(group: group, fallback: nil)
        }
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
