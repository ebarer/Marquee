//
//  TrailerPlayerView.swift
//  MovieTracker
//
//  Plays a movie trailer in-app.
//
//  Most studio trailers have embedding disabled by the video owner, so YouTube
//  refuses to play them in any third-party embed ("This video is unavailable").
//  Rather than fight that, this loads YouTube's watch page directly in a web view
//  with inline playback disabled: starting the video hands it to iOS's native
//  fullscreen player — a clean, chrome-free experience — without leaving the app.
//
//  The app is otherwise portrait-only, so while the trailer is on screen it
//  permits landscape (see `AppDelegate.isPlayingTrailer`), letting the user rotate
//  the device to watch fullscreen in landscape. Nothing is forced — the rest of
//  the app stays portrait, and the scene returns to portrait automatically once
//  the player is dismissed.
//

import SwiftUI
import WebKit

struct TrailerPlayerView: UIViewControllerRepresentable {
    let trailer: MovieTrailer
    /// Called when the video finishes or the player is closed, so the presenter
    /// can dismiss the cover.
    var onFinish: () -> Void

    func makeUIViewController(context: Context) -> TrailerPlayerViewController {
        let controller = TrailerPlayerViewController(trailer: trailer)
        controller.onFinish = onFinish
        return controller
    }

    func updateUIViewController(_ controller: TrailerPlayerViewController, context: Context) {}
}

final class TrailerPlayerViewController: UIViewController {
    private let trailer: MovieTrailer
    private var webView: WKWebView!
    private var fullscreenObservation: NSKeyValueObservation?
    /// Tracks whether playback ever reached fullscreen, so we only treat a
    /// *return* from fullscreen (video ended or dismissed) as "finished".
    private var didEnterFullscreen = false
    private var isFinished = false

    var onFinish: (() -> Void)?

    init(trailer: MovieTrailer) {
        self.trailer = trailer
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        AppDelegate.isPlayingTrailer = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let configuration = WKWebViewConfiguration()
        // Disabling inline playback forces the video into iOS's native fullscreen
        // player when it starts, giving a clean experience without page chrome.
        configuration.allowsInlineMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.backgroundColor = .black
        webView.isOpaque = false
        view.addSubview(webView)
        self.webView = webView

        // Tear down once the video exits fullscreen (finished or closed).
        fullscreenObservation = webView.observe(\.fullscreenState) { [weak self] webView, _ in
            guard let self else { return }
            switch webView.fullscreenState {
            case .inFullscreen:
                self.didEnterFullscreen = true
            case .notInFullscreen where self.didEnterFullscreen:
                self.finish()
            default:
                break
            }
        }

        if let url = trailer.watchURL {
            webView.load(URLRequest(url: url))
        }
    }

    // Allow the user to rotate the trailer freely; the rest of the app is
    // portrait-only (enforced at the app level via `AppDelegate.isPlayingTrailer`).
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .allButUpsideDown }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppDelegate.isPlayingTrailer = true
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        // Restore the app's portrait-only lock; the scene rotates back on its own
        // when the cover is dismissed.
        AppDelegate.isPlayingTrailer = false
        onFinish?()
    }
}

#Preview {
    TrailerPlayerView(
        trailer: MovieTrailer(
            id: "1",
            title: "Official Trailer",
            key: "dQw4w9WgXcQ",
            type: "Trailer",
            site: "YouTube",
            official: true,
            publishedAt: "2026-07-21T16:00:31.000Z"
        ),
        onFinish: {}
    )
    .ignoresSafeArea()
}
