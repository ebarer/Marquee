//
//  CreditFilterMenu.swift
//  MovieTracker
//

import SwiftUI

/// The filmography's filter: a tap turns filtering on or off, a long press opens a checklist of kinds.
struct CreditFilterMenu<Label: View>: View {
    let kinds: [CreditKind]
    @Binding var filter: CreditFilter
    @ViewBuilder let label: () -> Label

    var body: some View {
        Menu {
            Section {
                Button(filter.isOn ? "Disable Credits Filter" : "Enable Credits Filter") {
                    filter.isOn.toggle()
                }
            }
            // Always the stored selection, never the outcome: turning the filter off doesn't
            // pretend every kind is wanted.
            Section {
                ForEach(kinds) { kind in
                    Toggle(kind.title, isOn: binding(for: kind))
                }
            }
        } label: {
            label()
        } primaryAction: {
            filter.isOn.toggle()
        }
        .accessibilityLabel(isFiltering ? "Show all credits" : "Filter credits")
        .accessibilityHint("Touch and hold to choose which credits to hide")
    }

    var isFiltering: Bool { kinds.contains(where: filter.hides) }

    // Reads `hidden`, not `hides`, so the checklist shows the stored preference even while the
    // filter is off. `@AppStorage` publishes outside a `withAnimation`; the list animates itself.
    private func binding(for kind: CreditKind) -> Binding<Bool> {
        Binding(
            get: { !filter.hidden.contains(kind) },
            set: { shown in filter.setHidden(!shown, for: kind) }
        )
    }
}

extension View {
    func filterOnBadge(_ isOn: Bool, size: CGSize, color: Color = .appAccent) -> some View {
        background {
            if isOn {
                Capsule()
                    .fill(color)
                    .frame(width: size.width, height: size.height)
            }
        }
    }
}

#Preview {
    @Previewable @State var filter = CreditFilter()

    VStack(spacing: 24) {
        CreditFilterMenu(kinds: [.directing, .acting, .producing, .appearance], filter: $filter) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.title3)
                .foregroundStyle(filter.isOn ? Color.black : .white)
                .filterOnBadge(filter.isOn, size: DetailSearchBar.barItemFill)
        }

        HStack(spacing: 24) {
            Image(systemName: "line.3.horizontal.decrease")
                .foregroundStyle(.white)
                .filterOnBadge(false, size: DetailSearchBar.barItemFill)
            Image(systemName: "line.3.horizontal.decrease")
                .foregroundStyle(Color.black)
                .filterOnBadge(true, size: DetailSearchBar.barItemFill)
        }
        .font(.title3)

        Text(filter.isOn ? "Hiding \(filter.hidden.count)" : "Filter off")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
    .padding(40)
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
