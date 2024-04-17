//
//  ImageCollectionTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

class ImageCollectionTableViewCell: UITableViewCell
{
    var viewController: ImageCollectionViewController!
        
    // Update cell size when collection view is done laying out
    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        return viewController?.collectionView?.contentSize ?? intrinsicContentSize
    }
}
