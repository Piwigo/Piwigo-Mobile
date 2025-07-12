//
//  SceneDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/09/2020.
//  Copyright © 2020 Piwigo. All rights reserved.
//

import AVFoundation
import CoreData
import LocalAuthentication
import UIKit

#if canImport(BackgroundTasks)
import BackgroundTasks        // Requires iOS 13
#endif

import piwigoKit
import uploadKit

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    private var privacyView: UIView?
    
    // List of known shortcut actions.
    enum ActionType: String {
        case showFavoritesAction = "ShowFavoritesAction"
    }
    var savedShortCutItem: UIApplicationShortcutItem!

    
    // MARK: - Core Data Object Contexts
    private lazy var mainContext: NSManagedObjectContext = {
        return DataController.shared.mainContext
    }()
    
    
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
        
        // Process the quick action if the user selected one to launch the app.
        if let shortcutItem = connectionOptions.shortcutItem {
            // Save shortcut for later when app becomes active
            savedShortCutItem = shortcutItem
        }
        
        debugPrint("••> \(session.persistentIdentifier): Scene will connect to session.")
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        
        // Get other existing scenes of the main screen
        let otherScenes = UIApplication.shared.connectedScenes
            .filter({($0.session.role == .windowApplication) &&
                ($0.session.persistentIdentifier != session.persistentIdentifier)})
        
        // Determine the user activity from a new connection or from a session's state restoration.
        guard let userActivity = connectionOptions.userActivities.first ?? session.stateRestorationActivity else {
            // No scene to restore
            // Check whether this is the first created scene
            if otherScenes.isEmpty {
                // Check if a migration is necessary
                let migrator = DataMigrator()
#if DEBUG
                // For debugging purposes | Force a migration
                // Restore the database from the files available in the AppGroup Piwigo folder
//                let SQLfileName = "DataModel.sqlite"
//                let storeURL = DataDirectories.shared.appGroupDirectory
//                    .appendingPathComponent(SQLfileName)
//                migrator.restoreStore(storeURL: storeURL)
#endif
                if migrator.requiresMigration() {
                    // Tell user to wait until migration is completed and launch the migration
                    appDelegate.loadMigrationView(in: window, startMigrationWith: migrator)
                }
                else {
                    // Create login view
                    appDelegate.loadLoginView(in: window)
                    
                    // Blur views if the App Lock is enabled
                    addPrivacyProtection(toFirstScene: true)
                }
            } else {
                // Create additional scene ► default album unless a migration is running
                if otherScenes.filter({($0 as? UIWindowScene)?.topMostViewController() is DataMigrationViewController}).isEmpty,
                   AppVars.shared.isMigrationRunning == false {
                    // Create additional scene ► default album
                    appDelegate.loadNavigation(in: window)
                    
                    // Blur views if the App is locked
                    addPrivacyProtection(toFirstScene: false)
                } else {
                    // Tell user to wait until migration is completed
                    appDelegate.loadMigrationView(in: window)
                }
            }
            
            // Hold and present login window
            self.window = window
            window.makeKeyAndVisible()
            return
        }
        
        // Check whether this is the first scene to restore
        if otherScenes.isEmpty {
            // Check if a migration is necessary
            let migrator = DataMigrator()
            if migrator.requiresMigration() {
                // Tell user to wait until migration is completed and launch the migration
                appDelegate.loadMigrationView(in: window, startMigrationWith: migrator)
            }
            else {
                // Restore scene
                if configure(window: window, session: session, with: userActivity) {
                    // Remember this activity for later when this app quits or suspends.
                    scene.userActivity = userActivity
                    // Set the title for this scene to allow the system to differentiate multiple scenes for the user.
                    scene.title = userActivity.title
                    // Blur views if the App Lock is enabled
                    addPrivacyProtection(toFirstScene: true)
                } else {
                    debugPrint("Failed to restore scene from \(userActivity)")
                }
            }
        } else {
            // Restore additional scene ► default album / login view OR wait for migration?
            if otherScenes.filter({($0 as? UIWindowScene)?.topMostViewController() is DataMigrationViewController}).isEmpty,
               AppVars.shared.isMigrationRunning == false {
                // Restore scene
                if configure(window: window, session: session, with: userActivity) {
                    // Remember this activity for later when this app quits or suspends.
                    scene.userActivity = userActivity
                    // Set the title for this scene to allow the system to differentiate multiple scenes for the user.
                    scene.title = userActivity.title
                    // Blur views if the App is locked
                    addPrivacyProtection(toFirstScene: false)
                } else {
                    debugPrint("Failed to restore scene from \(userActivity)")
                }
            } else {
                // Tell user to wait until migration is completed
                appDelegate.loadMigrationView(in: window)
            }
        }
        
        // Hold and present login window
        self.window = window
        window.makeKeyAndVisible()
    }
    
    func addPrivacyProtection(toFirstScene isFirstScene: Bool) {
        // Check whether this is the first restored scene
        if isFirstScene {
            // First created/restored scene ► Blur views if the App Lock is enabled
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
        } else {
            // Additional created/restored scene —> Blur views if the App is locked
            if AppVars.shared.isAppUnlocked == false {
                // Protect presented login view
                addPrivacyProtection()
            }
        }
    }
    
    func configure(window: UIWindow?, session: UISceneSession, with activity: NSUserActivity) -> Bool {
        // Check the user activity type to know which part of the app to restore.
        if activity.activityType == ActivityType.album.rawValue {
            // The activity type is for restoring AlbumViewController.
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                  let window = window
            else { return false }
            appDelegate.loadNavigation(in: window)
            return true
        }
        
        // The incoming userActivity is not recognizable here.
        return false
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        debugPrint("••> \(scene.session.persistentIdentifier): Scene did disconnect.")
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }
    
    
    // MARK: - Transitioning to the Foreground
    func sceneWillEnterForeground(_ scene: UIScene) {
        debugPrint("••> \(scene.session.persistentIdentifier): Scene will enter foreground.")
        // Called as the scene is about to begin running in the foreground and become visible to the user.
        // Use this method to undo the changes made on entering the background.
        
        // Flag used to prevent background tasks from running when the app is active
        AppVars.shared.applicationIsActive = true
        
        // Flag used to force relogin at start
        NetworkVars.shared.applicationShouldRelogin = true
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        debugPrint("••> \(scene.session.persistentIdentifier): Scene did become active.")
        // Called when the scene has become active and is now responding to user events.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.

        // did the user open the app with a Home menu quick action?
        if savedShortCutItem != nil {
             _ = handleShortCutItem(shortcutItem: savedShortCutItem)
        }
        
        // Called during biometric authentication or data migration?
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let isMigratingData = (scene as? UIWindowScene)?.topMostViewController() is DataMigrationViewController
        if appDelegate.isAuthenticatingWithBiometrics || isMigratingData || AppVars.shared.isMigrationRunning { return }
        
        // Request passcode if necessary
        if AppVars.shared.isAppUnlocked == false {
            // Loop over all scenes
            let connectedScenes = UIApplication.shared.connectedScenes
            for scene in connectedScenes {
                // If passcode view controller presented ▶ NOP
                if (scene as? UIWindowScene)?.topMostViewController() is AppLockViewController { return }
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
        debugPrint("••> \(scene.session.persistentIdentifier): Scene will resign active.")
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
                if let sceneDelegate = scene.delegate as? SceneDelegate {
                    // Remove passcode view controller if presented
                    if let topViewController = (scene as? UIWindowScene)?.topMostViewController(),
                       topViewController is AppLockViewController {
                        // Protect presented views
                        sceneDelegate.addPrivacyProtection()
                        // Reset biometry flag
                        appDelegate.didCancelBiometricsAuthentication = false
                        // Dismiss passcode view
                        topViewController.dismiss(animated: true)
                    } else {
                        // Protect presented views
                        sceneDelegate.addPrivacyProtection()
                    }
                } else if let sceneDelegate = scene.delegate as? ExternalDisplaySceneDelegate,
                          let window = sceneDelegate.window {
                    sceneDelegate.addPrivacyProtection(to: window)
                }
            }
        } else {
            // Remember to not ask for passcode
            AppVars.shared.isAppUnlocked = true
        }
        
        // Prepare Home screen quick actions
        let application = UIApplication.shared
        application.shortcutItems = [
            UIApplicationShortcutItem(type: ActionType.showFavoritesAction.rawValue,
                                      localizedTitle: NSLocalizedString("categoryDiscoverFavorites_title", comment: "My Favorites"),
                                      localizedSubtitle: nil,
                                      icon: UIApplicationShortcutIcon(systemImageName: "heart"))
        ]
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        debugPrint("••> \(scene.session.persistentIdentifier): Scene did enter background.")
        // Called when the scene is running in the background and is no longer onscreen.
        // Use this method to save data, release shared resources, and store enough scene-specific state information to restore the scene back to its current state.
        
        // NOP if at least another scene is active in the foreground
        let connectedScenes = UIApplication.shared.connectedScenes
        if connectedScenes.filter({$0.activationState == .foregroundActive}).count > 0 { return }
        
        // Remember to ask for passcode or not
        AppVars.shared.isAppUnlocked = !AppVars.shared.isAppLockActive
        
        // Should we save changes in cache and schedule background tasks?
        if AppVars.shared.isMigrationRunning == false {
            // Save changes in the app's managed object context
            mainContext.saveIfNeeded()
        }
        
        // Schedule background tasks after cancelling pending onces
        BGTaskScheduler.shared.cancelAllTaskRequests()
        if NetworkVars.shared.usesUploadAsync {
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            appDelegate?.scheduleNextUpload()
        }
        
        // Clean up /tmp directory
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.cleanUpTemporaryDirectory(immediately: false)
        
        // Flag used to prevent background tasks from running when the app is active
        AppVars.shared.applicationIsActive = false
    }
    
    
    // MARK: - Privacy & Passcode
    func addPrivacyProtection() {
        debugPrint("••> \(window?.windowScene?.session.persistentIdentifier ?? "UNKNOWN"): Scene shows privacy protection window.")
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
    
    
    // MARK: - Application Shortcut Support
    /** Called when the user activates the application by selecting a shortcut on the Home Screen,
        and the window scene is already connected.
     */
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        let handled = handleShortCutItem(shortcutItem: shortcutItem)
        completionHandler(handled)
    }
    
    func handleShortCutItem(shortcutItem: UIApplicationShortcutItem) -> Bool {
        if let actionTypeValue = ActionType(rawValue: shortcutItem.type) {
            switch actionTypeValue {
            case .showFavoritesAction:
                // Dismiss image or settings view controllers if needed
                dismissNonAlbumViewControllers()

                // The root view controller should be the AlbumNavigationController
                if let navController = window?.rootViewController as? AlbumNavigationController {
                    // Return to root view controller
                    navController.popToRootViewController(animated: false)
                    debugPrint("#func handleShortCutItem(): did pop to root view controller")
                    
                    // Check that an album of favorites exists in cache (create it if necessary)
                    guard let albumVC = navController.viewControllers.first as? AlbumViewController,
                          let _ = albumVC.albumProvider.getAlbum(ofUser: albumVC.user, withId: pwgSmartAlbum.favorites.rawValue)
                    else { return false }
                    
                    // Present favorite images
                    let storyboard = UIStoryboard(name: "AlbumViewController", bundle: nil)
                    guard let favoritesVC = storyboard.instantiateViewController(withIdentifier: "AlbumViewController") as? AlbumViewController
                    else { preconditionFailure("Could not load AlbumViewController") }
                    favoritesVC.categoryId = pwgSmartAlbum.favorites.rawValue
                    navController.pushViewController(favoritesVC, animated: false)
                }
            }
        }
        return true
    }
    
    private func dismissNonAlbumViewControllers() {
        if let topMostVC = window?.windowScene?.topMostViewController(),
           (topMostVC is AlbumViewController) == false {
            topMostVC.dismiss(animated: false) {
                self.dismissNonAlbumViewControllers()
            }
        }
    }
}


// MARK: - AppLockDelegate Methods
@available(iOS 13.0, *)
extension SceneDelegate: AppLockDelegate {
    func loginOrReloginAndResumeUploads() {
        debugPrint("••> \(window?.windowScene?.session.persistentIdentifier ?? "UNKNOWN"): Scene presents the login view or resume uploads.")
        // Remove privacy view
        privacyView?.removeFromSuperview()
        
        // Any other scene in the foreground to unlock?
        let otherScenes = UIApplication.shared.connectedScenes
            .filter({$0.session.persistentIdentifier != window?.windowScene?.session.persistentIdentifier})
            .compactMap({$0})
        for scene in otherScenes {
            if let sceneDelegate = scene.delegate as? SceneDelegate {
                // Remove passcode view controller if presented
                if let topViewController = (scene as? UIWindowScene)?.topMostViewController(),
                   topViewController is AppLockViewController {
                    // Remove protection view
                    sceneDelegate.privacyView?.removeFromSuperview()
                    // Dismiss passcode view
                    topViewController.dismiss(animated: true)
                } else {
                    // Remove protection view
                    sceneDelegate.privacyView?.removeFromSuperview()
                }
            } else if let sceneDelegate = scene.delegate as? ExternalDisplaySceneDelegate {
                sceneDelegate.privacyView?.removeFromSuperview()
            }
        }
        
        // Piwigo will play audio even if the Silent switch set to silent or when the screen locks.
        // Furthermore, it will interrupt any other current audio sessions (no mixing)
        let audioSession = AVAudioSession.sharedInstance()
        let availableCategories = audioSession.availableCategories
        if availableCategories.contains(AVAudioSession.Category.playback) {
            try? audioSession.setCategory(.playback)
        }

        // Should we log in?
        if let rootVC = window?.rootViewController,
           let child = rootVC.children.first, child is LoginViewController {
            return
        }
        
        // Resume upload operations in background queue
        // and update badge and upload button of album navigator
        UploadManager.shared.backgroundQueue.async {
            UploadManager.shared.resumeAll()
        }
    }
}
