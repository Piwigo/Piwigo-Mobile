//
//  SceneDelegate+StateRestoration.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 23/04/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import UIKit

@available(iOS 13.0, *)
extension SceneDelegate {

    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        // Look for an instance of AlbumViewController as first controller
        guard let navController = window?.rootViewController as? UINavigationController,
              let defaultAlbum = navController.viewControllers.first as? AlbumViewController else {
          return nil
        }
        
        // Create a user activity for displaying albums
        let stateActivity = ActivityType.album.userActivity()

        // Create array of sub-album IDs
        var catIDs = Set<Int32>()
        var imageIndex = Int.min
        for viewController in navController.viewControllers {
            if let vc = viewController as? AlbumViewController {
                // Bypass the default album
                if vc.categoryId == defaultAlbum.categoryId { continue }
                // Store sub-album ID
                catIDs.insert(vc.categoryId)
            }
        }
                
        // Determine if an image is presented fullscreen on the device
        if let vc = navController.visibleViewController as? ImageViewController {
            // Store image index
            imageIndex = vc.imageIndex
        }

        // Create user info
        let info: [String: Any] = ["catIDs"  : catIDs,
                                   "imageID" : imageIndex]
        stateActivity.addUserInfoEntries(from: info)

        return stateActivity
    }
    
    func scene(_ scene: UIScene, restoreInteractionStateWith stateRestorationActivity: NSUserActivity) {
        // Look for the instance of AlbumViewController
        guard
          let navController = window?.rootViewController as? UINavigationController,
          let _ = navController.viewControllers.first as? AlbumViewController,
          let userInfo = stateRestorationActivity.userInfo
        else {
          return
        }

        // Restore sub-albums
        var catIDs = (userInfo["catIDs"] as? Set<Int32>) ?? [AlbumVars.shared.defaultCategory]
        let albumSB = UIStoryboard(name: "AlbumViewController", bundle: nil)
        while catIDs.isEmpty == false {
            let catID = catIDs.removeFirst()
            guard let subAlbumVC = albumSB.instantiateViewController(withIdentifier: "AlbumViewController") as? AlbumViewController 
            else { preconditionFailure("Could not load AlbumViewController") }
            subAlbumVC.categoryId = catID
            // It may take time to load album/image view controllers
            // so we delegate the restoration task to the last sub-album view controller
//            if catIDs.isEmpty, let imageIndex = (userInfo["imageID"] as? Int), imageIndex != Int.min {
//                subAlbumVC.indexOfImageToRestore = imageIndex
//            }
            navController.pushViewController(subAlbumVC, animated: false)
        }
    }
}
