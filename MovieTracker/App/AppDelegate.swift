//
//  AppDelegate.swift
//  MovieTracker
//
//  Created by Elliot Barer on 5/31/18.
//  Copyright © 2018 ebarer. All rights reserved.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    /// Permits landscape while set, so a trailer can play fullscreen; else portrait-only on iPhone.
    static var isPlayingTrailer = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        URLCache.shared = URLCache(memoryCapacity: 50 * 1024 * 1024,
                                   diskCapacity: 500 * 1024 * 1024)
        if UITestHooks.resetsCaches {
            URLCache.shared.removeAllCachedResponses()
            RemoteImageCache.shared.removeAll()
            Task { @MainActor in
                MediaMemoryCache.removeAll()
                await MediaCacheStore.shared.clear()
            }
        }
        return true
    }

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if AppDelegate.isPlayingTrailer {
            return .allButUpsideDown
        }
        return UIDevice.current.userInterfaceIdiom == .pad ? .all : .portrait
    }

    // MARK: - UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

}
