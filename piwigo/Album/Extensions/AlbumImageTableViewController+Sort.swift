//
//  AlbumImageTableViewController+Sort.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - Sort Image
/// - for selecting image sort options
@available(iOS 14, *)
extension AlbumImageTableViewController
{
    func imageSortMenu() -> UIMenu {
        let menuId = UIMenu.Identifier("org.piwigo.piwigoImage.sort")
        let menu = UIMenu(title: NSLocalizedString("categorySort_sort", comment: "Sort Images By…"),
                          image: nil, identifier: menuId,
                          options: UIMenu.Options.displayInline,
                          children: [imageCollectionVC.defaultSortAction(), imageCollectionVC.titleSortAction(),
                                     imageCollectionVC.createdSortAction(), imageCollectionVC.postedSortAction(),
                                     imageCollectionVC.ratingSortAction(), imageCollectionVC.visitsSortAction(),
                                     imageCollectionVC.randomSortAction()].compactMap({$0}))
        return menu
    }
}


@available(iOS 14, *)
extension AlbumImageTableViewController: ImageCollectionViewDelegate
{
    func updateImageSortMenu() {
        let updatedMenu = selectBarButton?.menu?.replacingChildren([selectMenu(), imageSortMenu()])
        selectBarButton?.menu = updatedMenu
    }
}
