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
//    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
//        //force layout of all subviews including self, which
//        //updates self's intrinsic height, and thus height of a cell
//        self.setNeedsLayout()
//        self.layoutIfNeeded()
//
//        let result = super.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: horizontalFittingPriority, verticalFittingPriority: verticalFittingPriority)
//        debugPrint("Images:", result)
//
//        //now intrinsic height is correct, call super method
//        return result

        // With autolayout enabled on collection view's cells we need to force a collection view relayout
//        debugPrint("Images:" , viewController?.collectionView?.collectionViewLayout.collectionViewContentSize)
//        debugPrint("Images:" , viewController?.collectionView?.contentSize)
//        viewController?.collectionView?.setNeedsLayout()
//        viewController?.collectionView?.layoutIfNeeded()
//        debugPrint("••> systemLayoutSizeFitting images:" , viewController?.collectionView?.collectionViewLayout.collectionViewContentSize)
//        debugPrint("••> systemLayoutSizeFitting images:" , viewController?.collectionView?.contentSize)
//        return viewController?.collectionView?.contentSize ?? intrinsicContentSize
//    }
}
