//
//  AlbumCollectionViewFlowLayout.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

class AlbumCollectionViewFlowLayout: UICollectionViewFlowLayout
{
    // See https://iosref.com/res
    private let margin = CGFloat(4)                 // Left and right margins for albums
    private let cellHeight = CGFloat(156.5)         // See AlbumTableViewCell XIB file

    private var deletingIndexPaths = [IndexPath]()
    private var insertingIndexPaths = [IndexPath]()


    // MARK: Layout Overrides
    override func prepare() {
        super.prepare()
        
        guard let collectionView = collectionView else { return }
        collectionView.layoutMargins = UIEdgeInsets(top: 0.0, left: margin, bottom: 0.0, right: margin)

        let cellWidth = AlbumUtilities.albumSize(forView: collectionView, maxWidth: 384.0)
        self.itemSize = CGSize(width: cellWidth, height: cellHeight)
        self.minimumLineSpacing = 0.0
        self.minimumInteritemSpacing = AlbumUtilities.kAlbumCellSpacing
        self.sectionInset = UIEdgeInsets.zero
        self.sectionInsetReference = .fromSafeArea
    }
    
    
    // MARK: Attributes for Updated Items
    override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attributes = super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath) else { return nil }
        
        if deletingIndexPaths.contains(itemIndexPath) {
            attributes.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            attributes.alpha = 0.0
            attributes.zIndex = 0
        }
        return attributes
    }
    
    override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attributes = super.initialLayoutAttributesForAppearingItem(at: itemIndexPath) else { return nil }
        
        if insertingIndexPaths.contains(itemIndexPath) {
            attributes.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            attributes.alpha = 0.0
            attributes.zIndex = 0
        }
        return attributes
    }
    
    
    // MARK: Updates
    override func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
        super.prepare(forCollectionViewUpdates: updateItems)
        
        for update in updateItems {
            switch update.updateAction {
            case .delete:
                guard let indexPath = update.indexPathBeforeUpdate else { return }
                deletingIndexPaths.append(indexPath)
            case .insert:
                guard let indexPath = update.indexPathAfterUpdate else { return }
                insertingIndexPaths.append(indexPath)
            default:
                break
            }
        }
    }
    
    override func finalizeCollectionViewUpdates() {
        super.finalizeCollectionViewUpdates()
        
        deletingIndexPaths.removeAll()
        insertingIndexPaths.removeAll()
    }
}
