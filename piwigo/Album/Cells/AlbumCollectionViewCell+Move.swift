//
//  AlbumCollectionViewCell+Move.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 25/12/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

extension AlbumCollectionViewCell {
    // MARK: - Move Category
    func moveCategory() {
        guard let albumData = albumData else { return }
        
        let moveSB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
        guard let moveVC = moveSB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController else { return }
        if moveVC.setInput(parameter: albumData, for: .moveAlbum) {
            moveVC.user = user
            moveVC.albumMovedDelegate = self
            categoryDelegate?.pushCategoryView(moveVC)
        }
    }

}


// MARK: - SelectCategoryAlbumMovedDelegate Methods
extension AlbumCollectionViewCell: SelectCategoryAlbumMovedDelegate
{
    func didMoveCategory() {
        // Hide swipe commands
//        let cell = tableView?.cellForRow(at: IndexPath(item: 0, section: 0)) as? AlbumTableViewCell
//        cell?.hideSwipe(animated: true) { [self] _ in
            // Remove category from the album/images collection
            categoryDelegate?.didMoveCategory(self)
//        }
    }
}
