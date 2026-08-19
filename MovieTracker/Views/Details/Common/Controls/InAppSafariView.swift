//
//  InAppSafariView.swift
//  MovieTracker
//

import SwiftUI
import SafariServices

/// Opens an outside page without leaving the app.
struct InAppSafariView: UIViewControllerRepresentable {
    let url: URL
    var tint: Color = .appAccent

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        configuration.barCollapsingEnabled = true

        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.preferredControlTintColor = UIColor(tint)
        controller.dismissButtonStyle = .close
        return controller
    }

    // SFSafariViewController loads the URL it was built with and ignores later changes, so
    // the sheet must be keyed on the link for a different site to load a different page.
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

extension View {
    /// Presents `link` in an in-app Safari view. Keyed on the link's identity so switching
    /// sites rebuilds the controller.
    func safariSheet(link: Binding<ExternalLink?>, tint: Color = .appAccent) -> some View {
        sheet(item: link) { link in
            InAppSafariView(url: link.url, tint: tint)
                .ignoresSafeArea()
        }
    }
}

#Preview {
    InAppSafariView(url: URL(string: "https://www.imdb.com/title/tt1375666/")!)
        .ignoresSafeArea()
}
