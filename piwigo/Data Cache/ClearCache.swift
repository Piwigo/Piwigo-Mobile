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

@objc
class ClearCache: NSObject {
    
    @objc
    class func closeSessionAndClearCache(completion: @escaping () -> Void) {
        // Session closed
        NetworkVarsObjc.sessionManager?.invalidateSessionCancelingTasks(true, resetSession: true)
        NetworkVarsObjc.imagesSessionManager?.invalidateSessionCancelingTasks(true, resetSession: true)
        NetworkVarsObjc.imageCache?.removeAllCachedResponses()

        // Back to default values
        AlbumVars.shared.defaultCategory = 0
        AlbumVars.shared.recentCategories = "0"
        NetworkVars.usesCommunityPluginV29 = false
        NetworkVars.hasAdminRights = false
        
        // Disable Auto-Uploading and clear settings
        UploadVars.isAutoUploadActive = false
        UploadVars.autoUploadCategoryId = NSNotFound
        UploadVars.autoUploadAlbumId = ""
        UploadVars.autoUploadTagIds = ""
        UploadVars.autoUploadComments = ""

        // Erase cache
        self.clearAllCache(exceptCategories: false) {
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            if #available(iOS 13.0, *) {
                // Disconnect inactive scenes
                let scenesInBackground = UIApplication.shared.connectedScenes
                    .filter({[.background, .unattached, .foregroundInactive].contains($0.activationState)})
                for scene in scenesInBackground {
                    UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil)
                }
                
                // Present login view in the remaining scene
                guard let window = (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.window else {
                    return
                }
                appDelegate?.loadLoginView(in: window)
                UIView.transition(with: window, duration: 0.5,
                                  options: .transitionCrossDissolve,
                                  animations: nil, completion: { _ in completion() })
            } else {
                // Fallback on earlier versions
                let window = UIApplication.shared.keyWindow
                appDelegate?.loadLoginView(in: window)
            }
        }
    }

    class func clearAllCache(exceptCategories: Bool,
                             completion: @escaping () -> Void) {
        
        // Tags
        TagsProvider().clearTags()

        // Locations with place names
        LocationsProvider().clearLocations()

        // Data
        TagsData.sharedInstance().clearCache()
        if !exceptCategories { CategoriesData.sharedInstance().clearCache() }

        // URL requests
        NetworkVarsObjc.imageCache?.removeAllCachedResponses()
        NetworkVarsObjc.thumbnailCache?.removeAllImages()
        
        // Clean up /tmp directory
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.cleanUpTemporaryDirectory(immediately: true)
        
        // Job done
        completion()
    }
}
