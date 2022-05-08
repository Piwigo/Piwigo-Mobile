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
        // Look for an instance of AlbumImagesViewController
        guard
          let navigationController = window?.rootViewController as? UINavigationController,
          let _ = navigationController.viewControllers.first as? AlbumImagesViewController
        else {
          return nil
        }
        
        // Create a user activity for displaying the album
        let stateActivity = ActivityType.album.userActivity()

        // Create array of album and sub-album IDs
        let viewControllers = navigationController.viewControllers
        var catIDs = viewControllers
            .compactMap({$0 as? AlbumImagesViewController}).map({$0.categoryId})
        
        // Discover album presented?
        if let discoverVC = viewControllers.last as? DiscoverImagesViewController {
            catIDs.append(discoverVC.categoryId)
        }
        
        // Album of tagged images presented?
        var tagID = 0, tagName = ""
        if let taggedVC = viewControllers.last as? TaggedImagesViewController {
            catIDs.append(kPiwigoTagsCategoryId)
            tagID = taggedVC.tagId
            tagName = taggedVC.tagName
        }
        
        // Favorite album presented?
        if let _ = viewControllers.last as? FavoritesImagesViewController {
            catIDs.append(kPiwigoFavoritesCategoryId)
        }
        
        // Create user info
        let info: [String: Any] = ["catIDs"     : catIDs,
                                   "tagID"      : tagID, "tagName" : tagName]
        stateActivity.addUserInfoEntries(from: info)

        return stateActivity
    }
    
    func scene(_ scene: UIScene, restoreInteractionStateWith stateRestorationActivity: NSUserActivity) {
        // Look for the instance of AlbumImagesViewController
        guard
          let navigationController = window?.rootViewController as? UINavigationController,
          let albumVC = navigationController.viewControllers.first as? AlbumImagesViewController,
          let userInfo = stateRestorationActivity.userInfo
        else {
          return
        }

        // Restore default album
        let catIDs = (userInfo["catIDs"] as? [Int]) ?? [AlbumVars.shared.defaultCategory]
        albumVC.categoryId = catIDs[0]
        
        // Restore sub-albums
        var subAlbumVC: UIViewController?
        if catIDs.count > 1 {
            for catID in catIDs[1...] {
                switch catID {
                case 1...Int.max:                   // Standard album
                    subAlbumVC = AlbumImagesViewController(albumId: catID)
                    
                case kPiwigoVisitsCategoryId,       // Most visited photos
                    kPiwigoBestCategoryId,          // Best rated photos
                    kPiwigoRecentCategoryId:        // Recent photos
                    subAlbumVC = DiscoverImagesViewController(categoryId: catID)
                
                case kPiwigoTagsCategoryId:         // Tagged photos
                    if let tagID = userInfo["tagID"] as? Int,
                       let tagName = userInfo["tagName"] as? String {
                        subAlbumVC = TaggedImagesViewController(tagId: tagID, andTagName: tagName)
                    }
                    
                case kPiwigoFavoritesCategoryId:    // Favorite photos
                    subAlbumVC = FavoritesImagesViewController()
                
                default:
                    debugPrint("••> SUB-ALBUM CANNOT BE RESTORED")
                }
                if subAlbumVC != nil {
                    navigationController.pushViewController(subAlbumVC!, animated: false)
                }
            }
        }
    }
}
