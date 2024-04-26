//
//  AlbumCollectionTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

class AlbumCollectionTableViewCell: UITableViewCell
{
    var albumVC: AlbumCollectionViewController!
    
    // Update cell size when collection view is done laying out
    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize
    {
        // Returns collectionView.contentSize in order to set the tableVieweCell height a value greater than 0.
        // because the collection layouting is performed after layouting the tableView.
        return albumVC?.collectionView?.contentSize ?? intrinsicContentSize
    }
}
