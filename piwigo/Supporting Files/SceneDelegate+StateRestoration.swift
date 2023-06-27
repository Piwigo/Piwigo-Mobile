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
            else if let vc = viewController as? ImageViewController {
                // Store image index
                imageIndex = vc.imageIndex
            }
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
        let catIDs = (userInfo["catIDs"] as? Set<Int32>) ?? [AlbumVars.shared.defaultCategory]
        var subAlbumVC: AlbumViewController!
        for catID in catIDs {
            subAlbumVC = AlbumViewController(albumId: catID)
            navController.pushViewController(subAlbumVC, animated: false)
        }
        
        // Restore image preview if performFetch() has been called and an image is available
        if subAlbumVC != nil,
           let imageIndex = (userInfo["imageID"] as? Int), imageIndex != Int.min,
           let images = subAlbumVC.images.fetchedObjects, images.count > 1 {
            // Prepare image detail view
            let imageDetailSB = UIStoryboard(name: "ImageViewController", bundle: nil)
            guard let imageDetailVC = imageDetailSB.instantiateViewController(withIdentifier: "ImageViewController") as? ImageViewController else { return }
            imageDetailVC.imageIndex = min(imageIndex, images.count - 1)
            imageDetailVC.categoryId = subAlbumVC.categoryId
            imageDetailVC.images = subAlbumVC.images
            imageDetailVC.user = subAlbumVC.user
            imageDetailVC.imgDetailDelegate = subAlbumVC.self
            imageDetailVC.hidesBottomBarWhenPushed = true
            imageDetailVC.modalPresentationCapturesStatusBarAppearance = true
            
            // Present image in full screen
            subAlbumVC.imageDetailView = imageDetailVC
            navController.pushViewController(imageDetailVC, animated: false)
        }
    }
}
