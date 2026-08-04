//
//  WhereToWatchSection.swift
//  MovieTracker
//

import SwiftUI

struct WhereToWatchSection: View {
    let availabilityByRegion: [String: WatchAvailability]?
    var releaseDate: Date?
    var tint: Color = .appAccent

    @Environment(\.openURL) private var openURL
    private let store = StreamingServicesStore.shared
    @State private var expanded = false
    @State private var showingServices = false

    private let logoSize: CGFloat = 56

    private var availability: WatchAvailability? { availabilityByRegion?[store.region] }

    /// Released within the theatrical window — shown instead of "Unavailable".
    private var inTheatres: Bool {
        guard let releaseDate, releaseDate <= .now,
              let cutoff = Calendar.current.date(byAdding: .day, value: -120, to: .now)
        else { return false }
        return releaseDate > cutoff
    }

    /// Grouped services, filtered to the user's picks once they've configured any.
    private var shown: [ProviderGroup] {
        guard let availability else { return [] }
        let groups = ProviderCatalog.grouped(availability.providers)
        guard !store.selected.isEmpty else { return groups }
        return groups.filter { store.selected.isSelected($0) }
    }

    var body: some View {
        let groups = shown
        VStack(spacing: 0) {
            header(available: !groups.isEmpty)
            if expanded, !groups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(groups) { group in
                            providerTile(group, fallback: availability?.justWatchLink)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .sheet(isPresented: $showingServices) {
            NavigationStack {
                StreamingServicesView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(role: .confirm) { showingServices = false }
                        }
                    }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func header(available: Bool) -> some View {
        HStack(spacing: 8) {
            titleView(available: available)
            infoButton
            if available {
                Button(action: toggleExpanded) {
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                        .rotationEffect(.degrees(expanded ? 0 : -90))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func titleView(available: Bool) -> some View {
        if available {
            Button(action: toggleExpanded) {
                Text("Where to Stream")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Text(inTheatres ? "Watch in Theaters" : "Unavailable to Stream")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var infoButton: some View {
        Button {
            showingServices = true
        } label: {
            Image(systemName: "info.circle")
                .font(.subheadline)
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose your services")
    }

    private func toggleExpanded() {
        withAnimation(.easeInOut) { expanded.toggle() }
    }

    private func providerTile(_ group: ProviderGroup, fallback: URL?) -> some View {
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
            .frame(width: logoSize, height: logoSize)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(group.name)
    }
}

#Preview("Available") {
    NavigationStack {
        ScrollView {
            WhereToWatchSection(availabilityByRegion: Movie.preview.watchByRegion)
        }
        .background(Color.appBackground)
    }
    .preferredColorScheme(.dark)
}

#Preview("Unavailable") {
    NavigationStack {
        ScrollView {
            WhereToWatchSection(availabilityByRegion: [:])
        }
        .background(Color.appBackground)
    }
    .preferredColorScheme(.dark)
}

#Preview("In Theatres") {
    NavigationStack {
        ScrollView {
            WhereToWatchSection(availabilityByRegion: [:], releaseDate: .now)
        }
        .background(Color.appBackground)
    }
    .preferredColorScheme(.dark)
}
