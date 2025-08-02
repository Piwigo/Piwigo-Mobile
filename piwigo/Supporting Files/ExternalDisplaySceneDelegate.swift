//
//  ExternalDisplaySceneDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/05/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

@available(iOS 13.0, *)
class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    var privacyView: UIView?
    
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
        debugPrint("••> \(session.persistentIdentifier): Scene will connect to session.")
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        
        // Enable management of external displays
        AppVars.shared.inSingleDisplayMode = false
        
        // Get scenes of the main display (active and not yet active)
        let existingScenes = UIApplication.shared.connectedScenes
            .filter({$0.session.role == .windowApplication})
        
        // Get the root view controller of the first scene
        guard let mainScene = existingScenes.first as? UIWindowScene,
              let rootVC = mainScene.rootViewController(),
              let navController = rootVC as? UINavigationController,
              let vc = navController.visibleViewController as? ImageViewController else {
            // Did not find an image view controller ► Basic screen mirroring
            self.window?.windowScene = nil
            return
        }
        
        // Add image view to external screen
        let imageSB = UIStoryboard(name: "ExternalDisplayViewController", bundle: nil)
        guard let imageVC = imageSB.instantiateViewController(withIdentifier: "ExternalDisplayViewController") as? ExternalDisplayViewController else {
            fatalError("!!! No ExternalDisplayViewController !!!")
        }
        imageVC.imageData = vc.imageData
        if let videoVC = vc.pageViewController?.viewControllers?.first as? VideoDetailViewController,
           let video = videoVC.video {
            videoVC.playbackController.remove(contentOfVideo: video)
            videoVC.placeHolderView.layer.opacity = 0.3
            videoVC.placeHolderView.isHidden = false
            videoVC.videoAirplay.isHidden = false
            imageVC.videoDetailDelegate = videoVC
        }
        if let pdfVC = vc.pageViewController?.viewControllers?.first as? PdfDetailViewController {
            imageVC.document = pdfVC.pdfView?.document
            pdfVC.pdfDetailDelegate = imageVC
        }

        // Initialise the external display
        window.rootViewController = imageVC
        initExternalDisplay(with: window)
        
        // Manages screen resolution changes
        NotificationCenter.default.addObserver(forName: UIScreen.modeDidChangeNotification,
                                               object: nil, queue: nil) { (modeNotice) in
            if let extScreen = modeNotice.object as? UIScreen, extScreen == window.screen,
               let rootVC = window.rootViewController {
                rootVC.view.setNeedsLayout()
                rootVC.view.layoutSubviews()
            }
        }
    }
    
    func initExternalDisplay(with window: UIWindow) {
        // Blur views if the App is locked
        if AppVars.shared.isAppUnlocked == false {
            // Protect presented login view
            addPrivacyProtection(to: window)
        }
        
        // Hold image in window
        self.window = window

        // Apply transition
        UIView.transition(with: window, duration: 0.5,
                          options: .transitionCrossDissolve) {
            window.makeKeyAndVisible()
        }
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        debugPrint("••> \(scene.session.persistentIdentifier): Scene did disconnect.")
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).

        // Disable management of external displays
        AppVars.shared.inSingleDisplayMode = true

        // Pause video playback and remove video controls
        guard let windowScene = (scene as? UIWindowScene) else { return }
        if let rootVC = windowScene.rootViewController() as? ExternalDisplayViewController {
            // Remove displayed video player
            if let video = rootVC.video {
                rootVC.playbackController.pause(contentOfVideo: video)
                rootVC.playbackController.remove(contentOfVideo: video)
                
                // Get scenes of the main display (active and not yet active)
                let existingScenes = UIApplication.shared.connectedScenes
                    .filter({$0.session.role == .windowApplication})
                
                // Get the root view controller of the first scene
                if let mainScene = existingScenes.first as? UIWindowScene,
                   let rootVC = mainScene.rootViewController(),
                   let navController = rootVC as? UINavigationController,
                   let vc = navController.visibleViewController as? ImageViewController,
                   let videoVC = vc.pageViewController?.viewControllers?.first as? VideoDetailViewController {
                    // Add
                    videoVC.videoAirplay.isHidden = true
                    videoVC.placeHolderView.layer.opacity = 1
                    videoVC.placeHolderView.isHidden = true
                    videoVC.videoContainerView.isHidden = false
                    videoVC.playbackController.embed(contentOfVideo: video, in: videoVC,
                                                     containerView: videoVC.videoContainerView)
                    videoVC.configVideoViews()
                }
            }
        }
    }
    
    func tearDownWindow(for sessionID: String) {
        guard let window = window,
              window.windowScene?.session.persistentIdentifier == sessionID
        else { return }
        window.isHidden = true
        self.window = nil
        
        // Disable management of external displays
        AppVars.shared.inSingleDisplayMode = true
    }
    
    
    // MARK: - Transitioning to the Foreground
//    func sceneWillEnterForeground(_ scene: UIScene) {
//        debugPrint("••> \(scene.session.persistentIdentifier): Scene will enter foreground.")
//        // Called as the scene is about to begin running in the foreground and become visible to the user.
//        // Use this method to undo the changes made on entering the background.
//    }

//    func sceneDidBecomeActive(_ scene: UIScene) {
//        debugPrint("••> \(scene.session.persistentIdentifier): Scene did become active.")
//        // Called when the scene has become active and is now responding to user events.
//        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
//    }
    
    
    // MARK: - Transitioning to the Background
    func sceneWillResignActive(_ scene: UIScene) {
        debugPrint("••> \(scene.session.persistentIdentifier): Scene will resign active.")
        // Called when the scene is about to resign the active state and stop responding to user events.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        debugPrint("••> \(scene.session.persistentIdentifier): Scene did enter background.")
        // Called when the scene is running in the background and is no longer onscreen.
        // Use this method to save data, release shared resources, and store enough scene-specific state information to restore the scene back to its current state.
    }
    
    
    // MARK: - Privacy & Passcode
    func addPrivacyProtection(to window: UIWindow) {
        // Blur views if the App Lock is enabled
        /// The passcode window is not presented now so that the app
        /// does not request the passcode until it is put into the background.
        if privacyView == nil {
            if UIAccessibility.isReduceTransparencyEnabled {
                // Settings ▸ Accessibility ▸ Display & Text Size ▸ Reduce Transparency is enabled
                let storyboard = UIStoryboard(name: "LaunchScreen", bundle: nil)
                let initialViewController = storyboard.instantiateInitialViewController()
                privacyView = initialViewController?.view
            } else {
                // Settings ▸ Accessibility ▸ Display & Text Size ▸ Reduce Transparency is disabled
                let blurEffect = UIBlurEffect(style: .dark)
                privacyView = UIVisualEffectView(effect: blurEffect)
                privacyView?.frame = window.frame
            }
        }
        window.addSubview(privacyView!)
    }
}
