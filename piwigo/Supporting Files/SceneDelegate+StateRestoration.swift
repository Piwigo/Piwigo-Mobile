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
        // Look for an instance of AlbumViewController
        guard
          let navigationController = window?.rootViewController as? UINavigationController,
          let _ = navigationController.viewControllers.first as? AlbumViewController
        else {
          return nil
        }
        
        // Create a user activity for displaying the album
        let stateActivity = ActivityType.album.userActivity()

        // Create array of album and sub-album IDs
        let viewControllers = navigationController.viewControllers
        let catIDs = viewControllers
            .compactMap({$0 as? AlbumViewController}).map({$0.categoryId})
                
        // Create user info
        let info: [String: Any] = ["catIDs" : catIDs]
        stateActivity.addUserInfoEntries(from: info)

        return stateActivity
    }
    
    func scene(_ scene: UIScene, restoreInteractionStateWith stateRestorationActivity: NSUserActivity) {
        // Look for the instance of AlbumViewController
        guard
          let navigationController = window?.rootViewController as? UINavigationController,
          let albumVC = navigationController.viewControllers.first as? AlbumViewController,
          let userInfo = stateRestorationActivity.userInfo
        else {
          return
        }

        // Restore default album
        let catIDs = (userInfo["catIDs"] as? [Int]) ?? [AlbumVars.shared.defaultCategory]
        albumVC.categoryId = catIDs[0]
        
        // Restore sub-albums
        if catIDs.count > 1 {
            for catID in catIDs[1...] {
                let subAlbumVC = AlbumViewController(albumId: catID)
                navigationController.pushViewController(subAlbumVC, animated: false)
            }
        }
    }
}
