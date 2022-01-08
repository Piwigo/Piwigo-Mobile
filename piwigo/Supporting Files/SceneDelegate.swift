//
//  SceneDelegate.swift
//  mySwift
//
//  Created by Eddy Lelièvre-Berna on 15/09/2020.
//  Copyright © 2020 Piwigo. All rights reserved.
//

import UIKit
import AVFoundation
import BackgroundTasks
import piwigoKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    let loginVC: LoginViewController = {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return LoginViewController_iPhone()
        } else {
            return LoginViewController_iPad()
        }
    }()

    @available(iOS 13.0, *)
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        
        // TO DO when all data will be cached in Core Data database: Scene management 
//        if let userActivity = connectionOptions.userActivities.first {
//            debugPrint(userActivity)
//        }

        guard let _ = (scene as? UIWindowScene) else { return }
        if let windowScene = scene as? UIWindowScene {
            // Show login view
            let window = UIWindow(windowScene: windowScene)
            let nav = LoginNavigationController(rootViewController: loginVC)
            nav.isNavigationBarHidden = true
            window.rootViewController = nav

            // Next line fixes #259 view not displayed with iOS 8 and 9 on iPad
            window.rootViewController?.view.setNeedsUpdateConstraints()

            // Color palette depends on system settings
            AppVars.isSystemDarkModeActive = loginVC.traitCollection.userInterfaceStyle == .dark
//            print("•••> iOS mode: \(AppVars.isSystemDarkModeActive ? "Dark" : "Light"), app mode: \(AppVars.isDarkPaletteModeActive ? "Dark" : "Light"), Brightness: \(lroundf(Float(UIScreen.main.brightness) * 100.0))/\(AppVars.switchPaletteThreshold), app: \(AppVars.isDarkPaletteActive ? "Dark" : "Light")")

            // Apply color palette
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            appDelegate?.screenBrightnessChanged()

            // Present login window
            self.window = window
            window.makeKeyAndVisible()

            // Look for credentials if server address provided
            let username = NetworkVars.username
            let service = NetworkVars.serverPath
            var password = ""

            // Look for paswword in Keychain if server address and username are provided
            if service.count > 0, username.count > 0 {
                password = KeychainUtilities.password(forService: service, account: username)
            }

            // Login?
            if service.count > 0 || (username.count > 0 && password.count > 0) {
                loginVC.launchLogin()
            }
        }
    }

    @available(iOS 13.0, *)
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    @available(iOS 13.0, *)
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.

        // Piwigo Mobile will play audio even if the Silent switch set to silent or when the screen locks.
        // Furthermore, it will interrupt any other current audio sessions (no mixing)
        let audioSession = AVAudioSession.sharedInstance()
        let availableCategories = audioSession.availableCategories
        if availableCategories.contains(AVAudioSession.Category.playback) {
            do {
                try audioSession.setCategory(.playback)
            } catch {
            }
        }

        // Should we reopen the session and restart uploads?
        if let rootVC = self.window?.rootViewController, let child = rootVC.children.first,
           !(child is LoginViewController_iPhone), !(child is LoginViewController_iPad) {
            // Determine for how long the session is opened
            /// Piwigo 11 session duration defaults to an hour.
            let timeSinceLastLogin = NetworkVars.dateOfLastLogin.timeIntervalSinceNow
            if timeSinceLastLogin < TimeInterval(-3) {    // i.e. 5 minutes
                /// - Perform relogin
                /// - Resume upload operations in background queue
                ///   and update badge, upload button of album navigator
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                appDelegate?.reloginAndRetry {
                    // Reload category data from server in background mode
                    self.loginVC.reloadCatagoryDataInBckgMode()
                }
            } else {
                /// - Resume upload operations in background queue
                ///   and update badge, upload button of album navigator
                UploadManager.shared.backgroundQueue.async {
                    UploadManager.shared.resumeAll()
                }
            }
        }
    }

    @available(iOS 13.0, *)
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).

        // Save cached data (crashes eported by TestFlight and App Store…)
//        DispatchQueue.main.async {
//            DataController.saveContext()
//        }
    }

    @available(iOS 13.0, *)
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.

        // Enable network activity indicator
        AFNetworkActivityIndicatorManager.shared().isEnabled = true

        // Enable network reachability monitoring
        AFNetworkReachabilityManager.shared().startMonitoring()
    }

    @available(iOS 13.0, *)
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.

        // Save changes in the app's managed object context when the app transitions to the background.
        DataController.saveContext()
        
        // Disable network activity indicator
        AFNetworkActivityIndicatorManager.shared().isEnabled = false

        // Disable network reachability monitoring
        AFNetworkReachabilityManager.shared().stopMonitoring()

        // Schedule background tasks after cancelling pending onces
        BGTaskScheduler.shared.cancelAllTaskRequests()
        if NetworkVars.usesUploadAsync {
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            appDelegate?.scheduleNextUpload()
        }

        // Clean up /tmp directory
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.cleanUpTemporaryDirectory(immediately: false)
    }
}
