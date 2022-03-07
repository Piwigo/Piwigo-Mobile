//
//  ClearCache.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/02/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

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
            if #available(iOS 13.0, *) {
                guard let window = (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.window else {
                    return
                }

                let loginVC: LoginViewController
                if UIDevice.current.userInterfaceIdiom == .phone {
                    loginVC = LoginViewController_iPhone()
                } else {
                    loginVC = LoginViewController_iPad()
                }
                let nav = LoginNavigationController(rootViewController: loginVC)
                nav.isNavigationBarHidden = true
                window.rootViewController = nav
                UIView.transition(with: window, duration: 0.5,
                                  options: .transitionCrossDissolve,
                                  animations: nil, completion: { _ in completion() })
            } else {
                // Fallback on earlier versions
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                appDelegate?.loadLoginView()
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
