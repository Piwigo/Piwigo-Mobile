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
            Model.sharedInstance().isSystemDarkModeActive = loginVC.traitCollection.userInterfaceStyle == .dark
//            print("•••> iOS mode: \(Model.sharedInstance().isSystemDarkModeActive ? "Dark" : "Light"), app mode: \(Model.sharedInstance().isDarkPaletteModeActive ? "Dark" : "Light"), Brightness: \(lroundf(Float(UIScreen.main.brightness) * 100.0))/\(Model.sharedInstance().switchPaletteThreshold), app: \(Model.sharedInstance().isDarkPaletteActive ? "Dark" : "Light")")

            // Apply color palette
            (UIApplication.shared.delegate as! AppDelegate).screenBrightnessChanged()

            // Present login window
            self.window = window
            window.makeKeyAndVisible()

            // Look for credentials if server address provided
            var user: String = ""
            var password: String = ""
            let server = Model.sharedInstance()?.serverPath ?? ""
            SAMKeychain.setAccessibilityType(kSecAttrAccessibleAfterFirstUnlock)
            if server.count > 0 {
                // Known acounts for that server?
                if let accounts = SAMKeychain.accounts(forService: server), accounts.count > 0 {
                    // Credentials available
                    user = Model.sharedInstance().username ?? ""
                    if user.count > 0 {
                        password = SAMKeychain.password(forService: server, account: user) ?? ""
                    }
                } else {
                    // No credentials available for that server. And with the old methods?
                    user = KeychainAccess.getLoginUser() ?? ""
                    password = KeychainAccess.getLoginPassword() ?? ""

                    // Store credentials with new method if found
                    if user.count > 0 {
                        Model.sharedInstance().username = user
                        Model.sharedInstance().saveToDisk()
                        SAMKeychain.setPassword(password, forService: server, account: user)
                    }
                }
            }

            // Login?
            if server.count > 0 || (user.count > 0 && password.count > 0) {
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
        if let rootVC = self.window?.rootViewController,
           let _ = rootVC.children.first as? AlbumImagesViewController {
            // Determine for how long the session is opened
            let timeSinceLastLogin = Model.sharedInstance()?.dateOfLastLogin.timeIntervalSinceNow ?? TimeInterval(-3600.0)
            if timeSinceLastLogin < TimeInterval(-900) { // i.e. 15 minutes (Piwigo 11 session duration defaults to an hour)
                /// - Perform relogin
                /// - Resume upload operations in background queue
                ///   and update badge, upload button of album navigator
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                appDelegate?.reloginAndRetry {
                    // Refresh Album/Images view
                    let uploadInfo: [String : Any] = ["fromCache" : "NO",
                                                      "albumId" : String(0)]
                    let name = NSNotification.Name(rawValue: kPiwigoNotificationGetCategoryData)
                    NotificationCenter.default.post(name: name, object: nil, userInfo: uploadInfo)
                }
            } else {
                /// - Resume upload operations in background queue
                ///   and update badge, upload button of album navigator
                UploadManager.shared.resumeAll()
            }
        }
    }

    @available(iOS 13.0, *)
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).

        // Save cached data
        DataController.saveContext()
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
        if Model.sharedInstance()?.usesUploadAsync ?? false {
            (UIApplication.shared.delegate as! AppDelegate).scheduleNextUpload()
        }

        // Clean up /tmp directory
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.cleanUpTemporaryDirectoryImmediately(false)
    }
}
