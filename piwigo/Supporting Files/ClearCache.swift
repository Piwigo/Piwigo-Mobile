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
    
    static func closeSession(completion: @escaping () -> Void) {
        // Cancel tasks
        cancelTasks {
            // Back to default values
            AlbumVars.shared.defaultCategory = 0
            AlbumVars.shared.recentCategories = "0"
            NetworkVars.usesCommunityPluginV29 = false
            NetworkVars.userStatus = pwgUserStatus.guest
            
            // Disable Auto-Uploading and clear settings
            UploadVars.isAutoUploadActive = false
            UploadVars.autoUploadCategoryId = Int32.min
            UploadVars.autoUploadAlbumId = ""
            UploadVars.autoUploadTagIds = ""
            UploadVars.autoUploadComments = ""
            
            // Display login view
            DispatchQueue.main.async {
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                if #available(iOS 13.0, *) {
                    // Get all scenes
                    let connectedScenes = UIApplication.shared.connectedScenes
                    
                    // Disconnect inactive scenes
                    let scenesInBackground = connectedScenes
                        .filter({[.background, .unattached, .foregroundInactive].contains($0.activationState)})
                    for scene in scenesInBackground {
                        UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil)
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
                    
                    // Disconnect supplementary active scenes except external screens
                    var deviceScenes = connectedScenes.filter({$0.session.role == .windowApplication})
                    while deviceScenes.count > 1 {
                        if let scene = connectedScenes.first {
                            UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil)
                            deviceScenes.removeFirst()
                        }
                    }
                    
                    // Present login view in the remaining scene
                    if let window = (deviceScenes.first?.delegate as? SceneDelegate)?.window {
                        AppVars.shared.isLoggingOut = true
                        appDelegate?.loadLoginView(in: window)
                    }
                } else {
                    // Fallback on earlier versions
                    let window = UIApplication.shared.keyWindow
                    appDelegate?.loadLoginView(in: window)
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
                    ImageSession.shared.dataSession.getAllTasks { tasks in
                        tasks.forEach({$0.cancel()})
                        completion()
                    }
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
