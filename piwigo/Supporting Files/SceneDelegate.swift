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

    // MARK: - Connecting and Disconnecting scenes
    /** Apps configure their UIWindow and attach it to the provided UIWindowScene scene.
        The system calls willConnectTo shortly after the app delegate's "configurationForConnecting" function.
        Use this function to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
     
        When using a storyboard file, as specified by the Info.plist key, UISceneStoryboardFile, the system automatically configures
        the window property and attaches it to the windowScene.
 
        Remember to retain the SceneDelegate's UIWindow.
        The recommended approach is for the SceneDelegate to retain the scene's window.
    */
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print("••> \(session.persistentIdentifier): Scene will connect to session.")
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)

        // Get other existing scenes
        let existingScenes = UIApplication.shared.connectedScenes
            .filter({$0.session.persistentIdentifier != session.persistentIdentifier})

        // Determine the user activity from a new connection or from a session's state restoration.
        guard let userActivity = connectionOptions.userActivities.first ?? session.stateRestorationActivity else {
            // No scene to restore —> Present login only if this is the first created scene
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            if existingScenes.isEmpty {
                // Create login view
                appDelegate.loadLoginView(in: window)

                // We will load album data
                NetworkVars.dateOfLastLogin = .distantPast

                // Blur views if the App Lock is enabled
                /// The passcode window is not presented so that the app
                /// does not request the passcode until it is put into the background.
                if AppVars.shared.isAppLockActive {
                    // Protect presented login view
                    addPrivacyProtection()
                }
                else {
                    // User is allowed to access albums
                    AppVars.shared.isAppUnlocked = true
                }
            }
            else {
                // Create additional scene => default album
                appDelegate.loadNavigation(in: window)

                // Blur views if the App is locked
                if AppVars.shared.isAppUnlocked == false {
                    // Protect presented login view
                    addPrivacyProtection()
                }
            }

            // Hold and present login window
            self.window = window
            window.makeKeyAndVisible()
            return
        }
        
        // Restore scene
        if configure(window: window, session: session, with: userActivity) {
            // Remember this activity for later when this app quits or suspends.
            scene.userActivity = userActivity
            // Set the title for this scene to allow the system to differentiate multiple scenes for the user.
            scene.title = userActivity.title
            
            // Mark this scene's session with this userActivity product identifier so you can update the UI later.
//            if let sessionProduct = SceneDelegate.product(for: userActivity) {
//                session.userInfo =
//                    [SceneDelegate.productIdentifierKey: sessionProduct.identifier]
//            }
        } else {
            debugPrint("Failed to restore scene from \(userActivity)")
        }

        // Check whether this is the first restored scene
        if existingScenes.isEmpty {
            // First restored scene —> Blur views if the App Lock is enabled
            if AppVars.shared.isAppLockActive {
                // Protect presented login view
                addPrivacyProtection()
            }
            else {
                // User is allowed to access albums
                AppVars.shared.isAppUnlocked = true
            }
        } else {
            // Additional restored scene —> Blur views if the App is locked
            if AppVars.shared.isAppUnlocked == false {
                // Protect presented login view
                addPrivacyProtection()
            }
        }
    }
    
    func configure(window: UIWindow?, session: UISceneSession, with activity: NSUserActivity) -> Bool {
        var succeeded = false
        
        // Check the user activity type to know which part of the app to restore.
        if activity.activityType == ActivityType.album.rawValue {
            // The activity type is for restoring AlbumViewController.
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return false }
            appDelegate.loadNavigation(in: window)
            
            // Hold and present window
            self.window = window
            window?.makeKeyAndVisible()
    
            succeeded = true
        }
        else {
            // The incoming userActivity is not recognizable here.
        }
        
        return succeeded
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        print("••> \(scene.session.persistentIdentifier): Scene did disconnect.")
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    
    // MARK: - Transitioning to the Foreground
    func sceneWillEnterForeground(_ scene: UIScene) {
        print("••> \(scene.session.persistentIdentifier): Scene will enter foreground.")
        // Called as the scene is about to begin running in the foreground and become visible to the user.
        // Use this method to undo the changes made on entering the background.

        // Enable network activity indicator
        AFNetworkActivityIndicatorManager.shared().isEnabled = true

        // Enable network reachability monitoring
        AFNetworkReachabilityManager.shared().startMonitoring()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        print("••> \(scene.session.persistentIdentifier): Scene did become active.")
        // Called when the scene has become active and is now responding to user events.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.

        // Called during biometric authentication?
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        if appDelegate.isAuthenticatingWithBiometrics { return }

        // Request passcode if necessary
        if AppVars.shared.isAppUnlocked == false {
            // Loop over all scenes
            let connectedScenes = UIApplication.shared.connectedScenes
            for scene in connectedScenes {
                // If passcode view controller already presented ▶ NOP
                if let topViewController = (scene as? UIWindowScene)?.topMostViewController(),
                   topViewController is AppLockViewController { return }
            }
            
            // Request passcode for accessing app
            appDelegate.requestPasscode(onTopOf: window) { appLockVC in
                // Set delegate
                appLockVC.delegate = self
                // Remove privacy view
                self.privacyView?.removeFromSuperview()
                // Did user enable biometrics?
                if AppVars.shared.isBiometricsEnabled,
                   appDelegate.didCancelBiometricsAuthentication == false {
                    // Yes, perform biometrics authentication
                    appDelegate.performBiometricAuthentication() { success in
                        // Authentication successful?
                        if !success { return }
                        // Dismiss passcode view controller
                        appLockVC.dismiss(animated: true) {
                            // Unlock the app
                            self.loginOrReloginAndResumeUploads()
                        }
                    }
                }
            }
            return
        }

        // Login/relogin and resume uploads
        loginOrReloginAndResumeUploads()
    }
    

    // MARK: - Transitioning to the Background
    func sceneWillResignActive(_ scene: UIScene) {
        print("••> \(scene.session.persistentIdentifier): Scene will resign active.")
        // Called when the scene is about to resign the active state and stop responding to user events.
        // This may occur due to temporary interruptions (ex. an incoming phone call).

        // Called during biometric authentication?
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        if appDelegate.isAuthenticatingWithBiometrics { return }
        
        // Blur views if the App Lock is enabled
        /// The passcode window is not presented so that the app
        /// does not request the passcode until it is put into the background.
        if AppVars.shared.isAppLockActive {
            // Loop over all scenes
            let connectedScenes = UIApplication.shared.connectedScenes
            for scene in connectedScenes {
                let sceneDelegate = scene.delegate as? SceneDelegate
                // Remove passcode view controller if presented
                if let topViewController = (scene as? UIWindowScene)?.topMostViewController(),
                   topViewController is AppLockViewController {
                    // Protect presented views
                    sceneDelegate?.addPrivacyProtection()
                    // Reset biometry flag
                    appDelegate.didCancelBiometricsAuthentication = false
                    // Dismiss passcode view
                    topViewController.dismiss(animated: true)
                } else {
                    // Protect presented views
                    sceneDelegate?.addPrivacyProtection()
                }
            }
        } else {
            // Remember to not ask for passcode
            AppVars.shared.isAppUnlocked = true
        }

        // Inform Upload Manager to pause activities
        UploadManager.shared.isPaused = true
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        print("••> \(scene.session.persistentIdentifier): Scene did enter background.")
        // Called when the scene is running in the background and is no longer onscreen.
        // Use this method to save data, release shared resources, and store enough scene-specific state information to restore the scene back to its current state.

        // NOP if at least another scene is active in the foreground
        let connectedScenes = UIApplication.shared.connectedScenes
        if connectedScenes.filter({$0.activationState == .foregroundActive}).count > 0 { return }

        // Remember to ask for passcode or not
        AppVars.shared.isAppUnlocked = !AppVars.shared.isAppLockActive

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


    // MARK: - Privacy & Passcode
    func addPrivacyProtection() {
        print("••> \(window?.windowScene?.session.persistentIdentifier ?? "UNKNOWN"): Scene shows privacy protection window.")
        // Blur views if the App Lock is enabled
        /// The passcode window is not presented now so that the app
        /// does not request the passcode until it is put into the background.
        if privacyView == nil, let frame = window?.frame {
            if UIAccessibility.isReduceTransparencyEnabled {
                // Settings ▸ Accessibility ▸ Display & Text Size ▸ Reduce Transparency is enabled
                let storyboard = UIStoryboard(name: "LaunchScreen", bundle: nil)
                let initialViewController = storyboard.instantiateInitialViewController()
                privacyView = initialViewController?.view
            } else {
                // Settings ▸ Accessibility ▸ Display & Text Size ▸ Reduce Transparency is disabled
                let blurEffect = UIBlurEffect(style: .dark)
                privacyView = UIVisualEffectView(effect: blurEffect)
                privacyView?.frame = frame
            }
        }
        window?.addSubview(privacyView!)
    }
}


// MARK: - AppLockDelegate Methods
@available(iOS 13.0, *)
extension SceneDelegate: AppLockDelegate {
    func loginOrReloginAndResumeUploads() {
        print("••> \(window?.windowScene?.session.persistentIdentifier ?? "UNKNOWN"): Scene will login/relogin if needed and resume uploads.")
        // Remove privacy view
        privacyView?.removeFromSuperview()
        
        // Any other scene in the foreground to unlock?
        let otherScenes = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .filter({$0.session.persistentIdentifier != window?.windowScene?.session.persistentIdentifier})
            .compactMap({$0})
        for scene in otherScenes {
            let sceneDelegate = scene.delegate as? SceneDelegate
            // Remove passcode view controller if presented
            if let topViewController = (scene as? UIWindowScene)?.topMostViewController(),
               topViewController is AppLockViewController {
                // Remove protection view
                sceneDelegate?.privacyView?.removeFromSuperview()
                // Dismiss passcode view
                topViewController.dismiss(animated: true)
            } else {
                // Remove protection view
                sceneDelegate?.privacyView?.removeFromSuperview()
            }
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
        if let rootVC = window?.rootViewController,
            let child = rootVC.children.first, child is LoginViewController {
            // Look for credentials if server address provided
            let username = NetworkVars.username
            let service = NetworkVars.serverPath
            var password = ""

            // Look for paswword in Keychain if server address and username are provided
            if service.isEmpty == false, username.isEmpty == false {
                password = KeychainUtilities.password(forService: service, account: username)
            }

            // Login?
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
               service.isEmpty == false || ((username.isEmpty == false) && (password.isEmpty == false)) {
                appDelegate.loginVC.launchLogin()
            }
            return
        }
    }
}
