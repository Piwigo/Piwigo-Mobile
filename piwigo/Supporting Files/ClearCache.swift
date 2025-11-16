//
//  ClearCache.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/02/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit
import uploadKit

class ClearCache: NSObject {
    
    @MainActor
    static func closeSessionWithPwgError(from viewController: UIViewController, error: PwgKitError) {
        var title = "", message = ""
        switch error {
        case .incompatiblePwgVersion:
            title = NSLocalizedString("serverVersionNotCompatible_title", comment: "Server Incompatible")
            message = String.localizedStringWithFormat(PwgKitError.incompatiblePwgVersion.localizedDescription, NetworkVars.shared.pwgVersion, NetworkVars.shared.pwgMinVersion)
        default:
            title = NSLocalizedString("internetErrorGeneral_title", comment: "Connection Error")
        }
        viewController.dismissPiwigoError(withTitle: title, message: message, errorMessage: error.localizedDescription) {
            closeSession()
        }
    }
    
    static func closeSession() {
        // Cancel tasks
        cancelTasks {
            // Back to default album settings
            AlbumVars.shared.defaultCategory = 0
            AlbumVars.shared.recentCategories = "0"
            AlbumVars.shared.isFetchingAlbumData = Set<Int32>()
            
            // Back to default server properties
            NetworkVars.shared.usesCommunityPluginV29 = false
            NetworkVars.shared.usesUploadAsync = false
            NetworkVars.shared.usesCalcOrphans = false
            NetworkVars.shared.usesSetCategory = false
            NetworkVars.shared.usesAPIkeys = false
            
            // Back to default user properties
            NetworkVars.shared.userStatus = pwgUserStatus.guest
            
            // Disable Auto-Uploading and clear settings
            UploadVars.shared.isAutoUploadActive = false
            UploadVars.shared.autoUploadCategoryId = Int32.min
            UploadVars.shared.autoUploadAlbumId = ""
            UploadVars.shared.autoUploadTagIds = ""
            UploadVars.shared.autoUploadComments = ""
            
            // Display login view
            DispatchQueue.main.async {
                // Get all scenes
                var connectedScenes = UIApplication.shared.connectedScenes
                
                // Disconnect inactive scenes
                let scenesInBackground = connectedScenes
                    .filter({[.background, .unattached, .foregroundInactive].contains($0.activationState)})
                for scene in scenesInBackground {
                    UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil)
                    connectedScenes.remove(scene)
                }
                
                // Clear external displays
                var externalScenes = [UIScene]()
                if #available(iOS 16.0, *) {
                    externalScenes = connectedScenes.filter({$0.session.role == .windowExternalDisplayNonInteractive})
                } else {
                    // Fallback to previous versions
                    externalScenes = connectedScenes.filter({$0.session.role == .windowExternalDisplay})
                }
                externalScenes.forEach { scene in
                    if let scene = scene as? UIWindowScene,
                       let imageVC = scene.rootViewController() as? ExternalDisplayViewController {
                        imageVC.imageData = nil
                        imageVC.imageView.image = nil
                        imageVC.video = nil
                    }
                }
                
                // Any scene displaying settings (user pressed logout)?
                let settingsScene = connectedScenes.first { scene in
                    if let window = (scene.delegate as? SceneDelegate)?.window,
                       let topMostVC = window.windowScene?.topMostViewController(),
                       topMostVC is SettingsViewController {
                        return true
                    }
                    return false
                }
                
                // Remove scenes except one
                if settingsScene == nil {
                    while connectedScenes.count > 1 {
                        if let scene = connectedScenes.first {
                            UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil)
                            connectedScenes.removeFirst()
                        }
                    }
                } else {
                    connectedScenes.forEach { scene in
                        if let window = (scene.delegate as? SceneDelegate)?.window,
                           let topMostVC = window.windowScene?.topMostViewController(),
                           topMostVC !== settingsScene {
                            UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil)
                            connectedScenes.remove(scene)
                        }
                    }
                }
                
                // Dismiss current view and present login view in the remaining scene
                if let window = (connectedScenes.first?.delegate as? SceneDelegate)?.window,
                   let topMostVC = window.windowScene?.topMostViewController() {
                    topMostVC.dismiss(animated: true) {
                        let appDelegate = UIApplication.shared.delegate as? AppDelegate
                        appDelegate?.loadLoginView(in: window)
                    }
                }
            }
        }
    }

    static func clearData(completion: @escaping () -> Void) {
        // Cancel tasks
        cancelTasks {
            // Erase data
            UploadProvider.shared.clearAll()
            LocationProvider.shared.clearAll()
            TagProvider.shared.clearAll()
            ImageProvider.shared.clearAll()
            AlbumProvider.shared.clearAll()
            
            // Clean directories (if anything left)
            cleanDirectories {
                // Job done
                completion()
            }
        }
    }

    static func clearUploads(completion: @escaping () -> Void) {
        // Cancel tasks
        cancelTasks {
            // Erase Upload database
            UploadProvider.shared.clearAll()
            
            // Clean directories (if anything left)
            cleanDirectories {
                // Job done
                completion()
            }
        }
    }
    
    static func cancelTasks(completion: @escaping () -> Void) {
        // Stop upload manager
        UploadManager.shared.isPaused = true
        
        // Cancel upload tasks, then other tasks
        UploadManager.shared.bckgSession.getAllTasks { tasks in
            tasks.forEach({$0.cancel()})
            UploadManager.shared.frgdSession.getAllTasks { tasks in
                tasks.forEach({$0.cancel()})
                
                // Update badge and upload queue button
                UploadManager.shared.backgroundQueue.async {
                    UploadManager.shared.findNextImageToUpload()
                }

                // Cancel other tasks
                PwgSession.shared.dataSession.getAllTasks { tasks in
                    tasks.forEach({$0.cancel()})
                    completion()
                }
            }
        }
    }
    
    static func cleanDirectories(completion: @escaping () -> Void) {
        // Clean up Uploads directory (if any left)
        UploadManager.shared.deleteFilesInUploadsDirectory() {
            // Clean up /tmp directory
            DispatchQueue.main.async {
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                appDelegate?.cleanUpTemporaryDirectory(immediately: true)
                
                // Job done
                completion()
            }
        }
    }
}
