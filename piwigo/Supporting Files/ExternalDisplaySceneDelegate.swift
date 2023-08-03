//
//  ExternalDisplaySceneDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/05/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

@available(iOS 13.0, *)
class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var windows = [String : UIWindow]()
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
        print("••> \(session.persistentIdentifier): Scene will connect to session.")
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        
        // Enable management of external displays
        AppVars.shared.inSingleDisplayMode = false
        
        // Add image view to external screen
        let imageSB = UIStoryboard(name: "ExternalDisplayViewController", bundle: nil)
        guard let imageVC = imageSB.instantiateViewController(withIdentifier: "ExternalDisplayViewController") as? ExternalDisplayViewController else {
            fatalError("!!! No ExternalDisplayViewController !!!")
        }
        window.rootViewController = imageVC
        
        // Get foreground active scenes of the main display
        let existingScenes = UIApplication.shared.connectedScenes
            .filter({$0.session.role == .windowApplication})
        
        // Get the root view controller of the first scene
        // and look for an instance of AlbumViewController embeded in a navigation controller
        guard let mainScene = existingScenes.first as? UIWindowScene,
              let rootVC = mainScene.rootViewController(),
              let navController = rootVC as? UINavigationController,
              let _ = navController.viewControllers.first as? AlbumViewController else {
                  // Did not find an album ► Display the ExternalLaunchScreen
                  initExternalDisplay(for: session.persistentIdentifier, with: window)
            return
        }
        
        // Determine if an image is presented fullscreen on the device
        if let vc = navController.visibleViewController as? ImageViewController {
            // Store image data in external image view controller
            imageVC.imageData = vc.imageData
            // Return to the Album/Images collection view
            vc.navigationController?.dismiss(animated: true)
        }
        
        // Initialise the external display
        initExternalDisplay(for: session.persistentIdentifier, with: window)
        
        // Manages screen resolution changes
        NotificationCenter.default.addObserver(forName: UIScreen.modeDidChangeNotification,
                                               object: nil, queue: nil) { (modeNotice) in
            for (_, window) in self.windows {
                if let extScreen = modeNotice.object as? UIScreen, extScreen == window.screen,
                   let rootVC = window.rootViewController {
                    rootVC.view.setNeedsLayout()
                    rootVC.view.layoutSubviews()
                }
            }
        }
    }
    
    private func initExternalDisplay(for sessionID: String, with window: UIWindow) {
        // Blur views if the App is locked
        if AppVars.shared.isAppUnlocked == false {
            // Protect presented login view
            addPrivacyProtection(to: window)
        }
        
        // Hold and present image in window
        windows[sessionID] = window
        window.makeKeyAndVisible()

        // Apply transition
        UIView.transition(with: window, duration: 0.5,
                          options: .transitionCrossDissolve) { }
    completion: { _ in }
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        print("••> \(scene.session.persistentIdentifier): Scene did disconnect.")
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
        
        // Disable management of external displays
        AppVars.shared.inSingleDisplayMode = true
    }
    
    func tearDownWindow(for sessionID: String) {
        guard let window = windows[sessionID] else { return }
        window.isHidden = true
        windows[sessionID] = nil
        
        // Disable management of external displays
        AppVars.shared.inSingleDisplayMode = true
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
