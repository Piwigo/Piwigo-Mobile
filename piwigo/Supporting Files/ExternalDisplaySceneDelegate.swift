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
        
        // Enable management of external displays
        AppVars.shared.inSingleDisplayMode = false
        
        // Get foreground active scenes of the main display
        let existingScenes = UIApplication.shared.connectedScenes
            .filter({$0.session.role == .windowApplication})
        
        // Get the root view controller of the first scene
        guard let mainScene = existingScenes.first as? UIWindowScene,
              let rootVC = mainScene.rootViewController() else {
            return
        }
        
        // Look for an instance of AlbumViewController embeded in a navigation controller
        guard let navController = rootVC as? UINavigationController,
              let _ = navController.viewControllers.first as? AlbumViewController else {
            // Did not find an album ► Display the ExternalLaunchScreen
            initExternalDisplay(for: session.persistentIdentifier, with: window)
            return
        }
        
        // Create external image view
        let imageSB = UIStoryboard(name: "ExternalDisplayViewController", bundle: nil)
        guard let imageVC = imageSB.instantiateViewController(withIdentifier: "ExternalDisplayViewController") as? ExternalDisplayViewController else {
            fatalError("!!! No ExternalDisplayViewController !!!")
        }
        window.rootViewController = imageVC

        // Determine if an image is presented fullscreen on the device
        for viewController in navController.viewControllers {
            if let vc = viewController as? ImageViewController {
                // Store image data in external image view controller
                imageVC.imageData = vc.imageData
                // Return to the Album/Images collection view
                vc.navigationController?.popViewController(animated: true)
                break
            }
        }
        
        // Hold and present image in window
        windows[session.persistentIdentifier] = window
        window.makeKeyAndVisible()
        UIView.transition(with: window, duration: 0.5,
                          options: .transitionCrossDissolve) { }
        completion: { _ in }

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
        windows[sessionID] = window
        window.makeKeyAndVisible()
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
}
