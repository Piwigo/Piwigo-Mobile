//
//  AlbumCollectionViewCell+Move.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 25/12/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

extension AlbumCollectionViewCell {
    // MARK: - Move Category
    func moveCategory(completion: @escaping (Bool) -> Void) {
        guard let albumData = albumData else { return }
        
        let moveSB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
        guard let moveVC = moveSB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController else { return }
        if moveVC.setInput(parameter: albumData, for: .moveAlbum) {
            moveVC.user = user
            categoryDelegate?.pushCategoryView(moveVC, completion: completion)
        }
    }
}
