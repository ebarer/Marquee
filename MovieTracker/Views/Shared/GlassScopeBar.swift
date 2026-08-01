//
//  GlassScopeBar.swift
//  Marquee
//
//  Created by Elliot Barer on 7/31/26.
//  Copyright © 2026 ebarer. All rights reserved.
//

import SwiftUI
import UIKit

struct GlassScopeBar<Option: Hashable>: View {
    static var selectedSegmentTint: UIColor { UIColor.black.withAlphaComponent(0.2) }

    private let options: [Option]
    @Binding private var selection: Option
    private let title: (Option) -> String

    /// Creates a scope bar.
    /// - Parameters:
    ///   - options: The selectable options, in display order.
    ///   - selection: A binding to the currently selected option.
    ///   - title: Maps an option to the text shown in its segment.
    init(_ options: [Option], selection: Binding<Option>, title: @escaping (Option) -> String) {
        self.options = options
        self._selection = selection
        self.title = title
        Self.applyScopeBarAppearance()
    }

    var body: some View {
        Picker("Scope", selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(title(option)).tag(option)
                    .font(Font.body)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(EdgeInsets(top: 1, leading: 1, bottom: 2, trailing: 1))
        .glassEffect(.regular, in: .capsule)
    }

    private static func applyScopeBarAppearance() {
        let appearance = UISegmentedControl.appearance()
        appearance.selectedSegmentTintColor = selectedSegmentTint
        appearance.backgroundColor = .clear

        let lightTitle: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white]
        appearance.setTitleTextAttributes(lightTitle, for: .normal)
        appearance.setTitleTextAttributes(lightTitle, for: .selected)
    }
}

/// Convenience for the common case where each option is its own title.
extension GlassScopeBar where Option == String {
    init(_ options: [String], selection: Binding<String>) {
        self.init(options, selection: selection, title: { $0 })
    }
}

#Preview {
    @Previewable @State var scope = "Movies"

    ZStack {
        LinearGradient(
            colors: [.blue, .purple, .pink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        GlassScopeBar(["Movies", "People"], selection: $scope)
            .padding()
    }
    .colorScheme(.dark)
}
