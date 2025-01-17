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
        var albumIDs = Set<Int32>()
        for viewController in navController.viewControllers {
            if let vc = viewController as? AlbumViewController {
                // Bypass the default album
                if vc.categoryId == defaultAlbum.categoryId { continue }
                // Store sub-album ID
                albumIDs.insert(vc.categoryId)
            }
        }
                
        // Determine if an image is presented fullscreen on the device
        var imagePath = [Int]()
        if let vc = navController.visibleViewController as? ImageViewController {
            // Store image index path (IndexPath type not accepted by userActivity)
            imagePath = [vc.indexPath.item, vc.indexPath.section]
        }

        // Create user info
        let info: [String: Any] = ["catIDs"  : albumIDs,
                                   "imagePath" : imagePath]
        stateActivity.addUserInfoEntries(from: info)
        return stateActivity
    }
    
    func scene(_ scene: UIScene, restoreInteractionStateWith stateRestorationActivity: NSUserActivity) {
        // Look for the instance of AlbumViewController
        guard
            let navController = window?.rootViewController as? UINavigationController,
            let albumVC = navController.viewControllers.first as? AlbumViewController,
            let userInfo = stateRestorationActivity.userInfo
        else {
            return
        }

        // Should we restore sub-albums?
        let catIDs = (userInfo["catIDs"] as? Set<Int32>) ?? Set<Int32>()
        guard catIDs.isEmpty == false
        else {
            // Root album displayed ► Fetch album data in the background
            albumVC.startFetchingAlbumAndImages(withHUD: false)
            return
        }
        
        // Restore sub-albums
        let albumSB = UIStoryboard(name: "AlbumViewController", bundle: nil)
        var subAlbumVC: AlbumViewController!
        for catID in catIDs {
            subAlbumVC = albumSB.instantiateViewController(withIdentifier: "AlbumViewController") as? AlbumViewController
            if subAlbumVC == nil { return }
            subAlbumVC.categoryId = catID
            navController.pushViewController(subAlbumVC, animated: false)
        }
        
        // Should we restore an image preview?
        guard let subAlbumVC = subAlbumVC,
              let imagePath = userInfo["imagePath"] as? [Int]?,
              let item = imagePath?.first, let section = imagePath?.last
        else {
            // Sub-album displayed ► Fetch sub-album data in the background
            subAlbumVC.startFetchingAlbumAndImages(withHUD: false)
            return
        }
        
        // Perform a fetch because the sub-album is not loaded yet
        try? subAlbumVC.images.performFetch()
        let indexPath = IndexPath(item: item, section: section)
        guard let sections = subAlbumVC.images.sections,
              section < sections.count,
              item < sections[section].numberOfObjects
        else { return }
        
        // Scroll collection view to cell position
        subAlbumVC.imageOfInterest = indexPath
        subAlbumVC.collectionView?.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
        
        // Prepare image detail view
        let imageDetailSB = UIStoryboard(name: "ImageViewController", bundle: nil)
        guard let imageDetailVC = imageDetailSB.instantiateViewController(withIdentifier: "ImageViewController") as? ImageViewController else { return }
        imageDetailVC.user = subAlbumVC.user
        imageDetailVC.categoryId = subAlbumVC.categoryId
        imageDetailVC.images = subAlbumVC.images
        imageDetailVC.indexPath = indexPath
        imageDetailVC.imgDetailDelegate = subAlbumVC.self
        
        // Push ImageDetailView embedded in navigation controller
        let imgNavController = UINavigationController(rootViewController: imageDetailVC)
        imgNavController.hidesBottomBarWhenPushed = true
        imgNavController.transitioningDelegate = subAlbumVC
        imgNavController.modalPresentationStyle = .custom
        imgNavController.modalPresentationCapturesStatusBarAppearance = true
        subAlbumVC.navigationController?.present(imgNavController, animated: false) {
            if let selectedCell = subAlbumVC.collectionView?.cellForItem(at: indexPath) as? ImageCollectionViewCell {
                subAlbumVC.animatedCell = selectedCell
                subAlbumVC.albumViewSnapshot = subAlbumVC.view.snapshotView(afterScreenUpdates: true)
                subAlbumVC.cellImageViewSnapshot = selectedCell.snapshotView(afterScreenUpdates: true)
                subAlbumVC.navBarSnapshot = subAlbumVC.navigationController?.navigationBar.snapshotView(afterScreenUpdates: true)
            }
        }
        
        // Image of sub-album displayed ► Fetch sub-album data in the background
        subAlbumVC.startFetchingAlbumAndImages(withHUD: false)
    }
}
