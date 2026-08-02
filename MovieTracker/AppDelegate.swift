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

    /// While `true`, the app permits landscape so the user can rotate a trailer
    /// into landscape to watch it fullscreen. Outside of trailer playback the app
    /// stays portrait-only on iPhone, matching Info.plist.
    static var isPlayingTrailer = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
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
