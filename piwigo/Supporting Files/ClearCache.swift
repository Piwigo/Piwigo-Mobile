//
//  ClearCache.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/02/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit
import UIKit

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
                    // Disconnect inactive scenes
                    let scenesInBackground = UIApplication.shared.connectedScenes
                        .filter({[.background, .unattached, .foregroundInactive].contains($0.activationState)})
                    for scene in scenesInBackground {
                        UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil)
                    }
                    
                    // Disconnect supplementary active scenes
                    var connectedScenes = UIApplication.shared.connectedScenes
                    while connectedScenes.count > 1 {
                        if let scene = connectedScenes.first {
                            UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil)
                            connectedScenes.removeFirst()
                        }
                    }
                    
                    // Present login view in the remaining scene
                    if let window = (connectedScenes.first?.delegate as? SceneDelegate)?.window {
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
            // Erase database
            UploadProvider().clearAll()
            LocationProvider.shared.clearAll()
            TagProvider().clearAll()
            ImageProvider().clearAll()
            AlbumProvider().clearAll()
            
            // Clean up /tmp directory
            DispatchQueue.main.async {
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                appDelegate?.cleanUpTemporaryDirectory(immediately: true)
                
                // Job done
                completion()
            }
        }
    }
    
    static func cancelTasks(completion: @escaping () -> Void) {
        PwgSession.shared.dataSession.getAllTasks { tasks in
            tasks.forEach({$0.cancel()})
            ImageSession.shared.dataSession.getAllTasks { tasks in
                tasks.forEach({$0.cancel()})
                completion()
            }
        }
    }
}
