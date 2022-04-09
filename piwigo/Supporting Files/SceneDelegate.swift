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
import LocalAuthentication
import piwigoKit

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var privacyView: UIView?
    private var isAllowedToAccessApp = true
    private var isAuthenticatingWithBiometrics = false

    // MARK: - Connecting and Disconnecting scenes
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        debugPrint("••> Scene will connect to session \(session.persistentIdentifier).")
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        
        // TO DO when all data will be cached in Core Data database: Scene management 
//        if let userActivity = connectionOptions.userActivities.first {
//            debugPrint(userActivity)
//        }

        guard let windowScene = (scene as? UIWindowScene) else { return }
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        
        // Create login view
        let window = UIWindow(windowScene: windowScene)
        let nav = LoginNavigationController(rootViewController: appDelegate.loginVC)
        nav.isNavigationBarHidden = true
        window.rootViewController = nav

        // Next line fixes #259 view not displayed with iOS 8 and 9 on iPad
        window.rootViewController?.view.setNeedsUpdateConstraints()

        // Color palette depends on system settings
        AppVars.shared.isSystemDarkModeActive = appDelegate.loginVC.traitCollection.userInterfaceStyle == .dark
        debugPrint("••> iOS mode: \(AppVars.shared.isSystemDarkModeActive ? "Dark" : "Light"), App mode: \(AppVars.shared.isDarkPaletteModeActive ? "Dark" : "Light"), Brightness: \(lroundf(Float(UIScreen.main.brightness) * 100.0))/\(AppVars.shared.switchPaletteThreshold), app: \(AppVars.shared.isDarkPaletteActive ? "Dark" : "Light")")

        // Apply color palette
        appDelegate.screenBrightnessChanged()

        // Hold and present login window
        self.window = window
        window.makeKeyAndVisible()

        // Blur views if the App Lock is enabled
        /// The passcode window is not presented  so that the app
        /// does not request the passcode until it is put into the background.
        if AppVars.shared.isAppLockActive {
            // User is not allowed to access albums yet
            isAllowedToAccessApp = false
            // Protect presented login view
            showPrivacyProtectionWindow()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        debugPrint("••> Scene \(scene.session.persistentIdentifier) did disconnect.")
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    
    // MARK: - Transitioning to the Foreground
    func sceneWillEnterForeground(_ scene: UIScene) {
        debugPrint("••> Scene \(scene.session.persistentIdentifier) will enter foreground.")
        // Called as the scene is about to begin running in the foreground and become visible to the user.
        // Use this method to undo the changes made on entering the background.

        // Enable network activity indicator
        AFNetworkActivityIndicatorManager.shared().isEnabled = true

        // Enable network reachability monitoring
        AFNetworkReachabilityManager.shared().startMonitoring()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        debugPrint("••> Scene \(scene.session.persistentIdentifier) did become active.")
        // Called when the scene has become active and is now responding to user events.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.

        // Relogin and resume upload operations if user can access app
        if isAllowedToAccessApp {
            loginOrReloginAndResumeUploads()
        }
        else {
            // Request passcode for accessing app
            requestPasscode()
        }
    }
    
    private func requestPasscode() {
        if let topViewController = UIApplication.shared.topViewController(),
           !(topViewController is AppLockViewController) {
            // Show passcode view controller if needed
            let appLockSB = UIStoryboard(name: "AppLockViewController", bundle: nil)
            guard let appLockVC = appLockSB.instantiateViewController(withIdentifier: "AppLockViewController") as? AppLockViewController else { return }
            appLockVC.config(forAction: .unlockApp)
            appLockVC.modalPresentationStyle = .overFullScreen
            appLockVC.modalTransitionStyle = .crossDissolve
            let topViewController = UIApplication.shared.topViewController()
            topViewController?.present(appLockVC, animated: false, completion: {
                // Hide privacy view
                self.privacyView?.isHidden = true

                // Does user enabled biometrics?
                if !AppVars.shared.isBiometricsEnabled { return }
                
                // Get a fresh context
                let context = LAContext()
                context.localizedReason = NSLocalizedString("settings_appLockEnter", comment: "Enter Passcode")
                context.localizedFallbackTitle = NSLocalizedString("settings_appLockFallback", comment: "Use Passcode")

                // First check if we have the needed hardware support
                var error: NSError?
                if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                    // Exploit TouchID or FaceID
                    self.isAuthenticatingWithBiometrics = true
                    let reason = NSLocalizedString("settings_biometricsReason", comment: "Access your Piwigo albums")
                    context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason ) { success, error in
                        if success {
                            // User allowed to access app
                            self.isAllowedToAccessApp = true
                            // Biometric authentication completed
                            self.isAuthenticatingWithBiometrics = false
                            // Return to main thread
                            DispatchQueue.main.async {
                                // Dismiss passcode view and activate scene
                                appLockVC.dismiss(animated: true)
                            }
                        }
                        else {
                            // Fall back to a asking for passcode
                            print(error?.localizedDescription ?? "Failed to authenticate")
                        }
                    }
                }
            })
        }
    }
    
    func loginOrReloginAndResumeUploads() {
        // Remove passcode window and protection view
        if let topViewController = UIApplication.shared.topViewController(),
           topViewController is AppLockViewController {
            topViewController.dismiss(animated: true) {
                self.privacyView = nil
            }
        } else {
            privacyView = nil
        }

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

        // Should we log in?
        if let rootVC = self.window?.rootViewController,
            let child = rootVC.children.first, child is LoginViewController {
            // Look for credentials if server address provided
            let username = NetworkVars.username
            let service = NetworkVars.serverPath
            var password = ""

            // Look for paswword in Keychain if server address and username are provided
            if service.count > 0, username.count > 0 {
                password = KeychainUtilities.password(forService: service, account: username)
            }

            // Login?
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
               service.count > 0 || (username.count > 0 && password.count > 0) {
                appDelegate.loginVC.launchLogin()
            }
            return
        }
            
        // Determine for how long the session is opened
        /// Piwigo 11 session duration defaults to an hour.
        let timeSinceLastLogin = NetworkVars.dateOfLastLogin.timeIntervalSinceNow
        if timeSinceLastLogin < TimeInterval(-300) {    // i.e. 5 minutes
            /// - Perform relogin
            /// - Resume upload operations in background queue
            ///   and update badge, upload button of album navigator
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            appDelegate?.reloginAndRetry {
                // Reload category data from server in background mode
                appDelegate?.loginVC.reloadCatagoryDataInBckgMode()
            }
        } else {
            /// - Resume upload operations in background queue
            ///   and update badge, upload button of album navigator
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.resumeAll()
            }
        }
    }
    

    // MARK: - Transitioning to the Background
    func sceneWillResignActive(_ scene: UIScene) {
        debugPrint("••> Scene \(scene.session.persistentIdentifier) will resign active.")
        // Called when the scene is about to resign the active state and stop responding to user events.
        // This may occur due to temporary interruptions (ex. an incoming phone call).

        // Called during biometric authentication?
        if isAuthenticatingWithBiometrics { return }

        // Blur views if the App Lock is enabled
        /// The passcode window is not presented  so that the app
        /// does not request the passcode until it is put into the background.
        if AppVars.shared.isAppLockActive {
            // Remember to ask for passcode
            isAllowedToAccessApp = false
            // Remove passcode view controller if presented
            if let topViewController = UIApplication.shared.topViewController(),
               topViewController is AppLockViewController {
                // Protect presented views
                self.privacyView?.isHidden = false
                // Dismiss passcode view
                topViewController.dismiss(animated: true)
            } else {
                // Protect presented views
                showPrivacyProtectionWindow()
            }
        }

        // Inform Upload Manager to pause activities
        UploadManager.shared.isPaused = true
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        debugPrint("••> Scene \(scene.session.persistentIdentifier) did enter background.")
        // Called when the scene is running in the background and is no longer onscreen.
        // Use this method to save data, release shared resources, and store enough scene-specific state information to restore the scene back to its current state.

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

    private func showPrivacyProtectionWindow() {
        // Blur views if the App Lock is enabled
        /// The passcode window is not presented now so that the app
        /// does not request the passcode until it is put into the background.
        if privacyView == nil,
           let keyWindow = UIApplication.shared.windows.filter({$0.isKeyWindow}).first {
            if UIAccessibility.isReduceTransparencyEnabled {
                // Settings ▸ Accessibility ▸ Display & Text Size ▸ Reduce Transparency is enabled
                let storyboard = UIStoryboard(name: "LaunchScreen", bundle: nil)
                let initialViewController = storyboard.instantiateInitialViewController()
                privacyView = initialViewController?.view
            } else {
                // Settings ▸ Accessibility ▸ Display & Text Size ▸ Reduce Transparency is disabled
                let blurEffect = UIBlurEffect(style: .dark)
                privacyView = UIVisualEffectView(effect: blurEffect)
                privacyView?.frame = keyWindow.frame
            }
            keyWindow.addSubview(privacyView!)
        }
        privacyView?.isHidden = false
    }
}
