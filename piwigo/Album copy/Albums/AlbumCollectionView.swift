//
//  AlbumCollectionView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 09/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation

class AlbumCollectionView: UICollectionView
{
    override var contentSize: CGSize {
        didSet {
            if oldValue.height != self.contentSize.height {
                invalidateIntrinsicContentSize()
            }
        }
    }

    override var intrinsicContentSize: CGSize {
        layoutIfNeeded()
        return CGSize(width: UIView.noIntrinsicMetric,
                      height: contentSize.height)
    }
}
