//
//  SchemaPrimerSection.swift
//  MovieTracker
//
//  Debug-only CloudKit schema maintenance. Excluded from TestFlight/App Store builds.
//

#if DEBUG
import SwiftUI

/// Runs `SchemaPrimer` from Settings: write the primer records, deploy the schema, remove them.
struct SchemaPrimerSection: View {
    let store: PersistenceCoordinator?

    // A fetch, not an observed property. Touch `revision` to re-read it after a write.
    private var isPrimed: Bool {
        guard let store else { return false }
        _ = store.revision
        return SchemaPrimer.isPrimed(using: store)
    }

    private var canPrime: Bool { store != nil && !isPrimed }
    private var canPurge: Bool { store != nil && isPrimed }

    var body: some View {
        Section {
            Button {
                if let store { SchemaPrimer.prime(using: store) }
            } label: {
                Label("Prime CloudKit Schema", systemImage: "ladybug")
                    // An explicit tint would override the disabled dimming, hiding the order.
                    .foregroundStyle(canPrime ? Color.appAccent : Color.secondary)
            }
            .disabled(!canPrime)

            Button(role: .destructive) {
                if let store { SchemaPrimer.purge(using: store) }
            } label: {
                Label("Remove Primers", systemImage: "trash")
                    .foregroundStyle(canPurge ? Color.red : Color.secondary)
            }
            .disabled(!canPurge)
        } header: {
            Text("CloudKit Schema")
        } footer: {
            Text(isPrimed
                 ? "Primers written. Wait for “export finished … ok” in Console, deploy Development→Production, then remove them."
                 : "Writes one throwaway record of every model with every field set, so Development materializes the full schema before a Production deploy. Adds a temporary row to Watched and Viewed.")
        }
    }
}

#Preview("Not primed") {
    List {
        SchemaPrimerSection(store: PersistenceCoordinator(previewModelContainer.mainContext))
    }
    .preferredColorScheme(.dark)
}

#Preview("Primed") {
    let store = PersistenceCoordinator(previewModelContainer.mainContext)
    SchemaPrimer.prime(using: store)
    return List {
        SchemaPrimerSection(store: store)
    }
    .preferredColorScheme(.dark)
}
#endif
