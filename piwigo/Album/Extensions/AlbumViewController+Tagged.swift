//
//  AlbumViewController+Tagged.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/05/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: TagSelectorViewDelegate Methods
extension AlbumViewController: TagSelectorViewDelegate
{
    func pushTaggedImagesView(_ viewController: UIViewController) {
        // Push sub-album view
        navigationController?.pushViewController(viewController, animated: true)
    }
}
