//
//  AlbumCollectionViewCellOld+Move.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 25/12/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import UIKit

extension AlbumCollectionViewCellOld {
    // MARK: - Move Category
    func moveCategory(completion: @escaping (Bool) -> Void) {
        guard let albumData = albumData else { return }
        
        let moveSB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
        guard let moveVC = moveSB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController else { return }
        if moveVC.setInput(parameter: albumData, for: .moveAlbum) {
            moveVC.user = user
            pushAlbumDelegate?.pushAlbumView(moveVC, completion: completion)
        }
    }
}


// MARK: - AlbumCollectionViewCellOldDelegate
extension AlbumViewController: PushAlbumCollectionViewCellDelegate
{
    func pushAlbumView(_ viewController: UIViewController?,
                       completion: @escaping (Bool) -> Void) {
        guard let viewController = viewController else {
            return
        }

        // Push sub-album, Discover or Favorites album
        if viewController is AlbumViewController {
            // Push sub-album view
            navigationController?.pushViewController(viewController, animated: true)
        }
        else {
            // Push album list
            if UIDevice.current.userInterfaceIdiom == .pad {
                viewController.modalPresentationStyle = .popover
                viewController.popoverPresentationController?.sourceView = view
                viewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection(rawValue: 0)
                navigationController?.present(viewController, animated: true) {
                    // Hide swipe commands
                    completion(true)
                }
            }
            else {
                let navController = UINavigationController(rootViewController: viewController)
                navController.modalPresentationStyle = .popover
                navController.popoverPresentationController?.sourceView = view
                navController.modalTransitionStyle = .coverVertical
                navigationController?.present(navController, animated: true) {
                    // Hide swipe commands
                    completion(true)
                }
            }
        }
    }
}
