//
//  AlbumCollectionViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 07/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

class AlbumCollectionViewCell: UICollectionViewCell
{
    var albumData: Album? {
        didSet {
//            tableView?.reloadData()
        }
    }

}
