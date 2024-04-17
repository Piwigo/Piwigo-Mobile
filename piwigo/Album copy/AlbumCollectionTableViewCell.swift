//
//  AlbumCollectionTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 10/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import UIKit

class AlbumCollectionTableViewCell: UITableViewCell
{
    var albumCollectionVC: AlbumCollectionViewController!
        
    override func awakeFromNib() {
        super.awakeFromNib()
        initCollectionView()
    }

    private func initCollectionView() {
        // Create album collection view controller
        let albumSB = UIStoryboard(name: "AlbumImageTableViewController", bundle: nil)
        guard let albumVC = albumSB.instantiateViewController(withIdentifier: "AlbumCollectionViewController") as? AlbumCollectionViewController else { fatalError("!!! No AlbumCollectionViewController !!!") }
        albumCollectionVC = albumVC
        
        // Need to update row height when collection view finishes its layout.
        albumCollectionVC.didLayoutAction = updateRowHeight
        
        contentView.addSubview(albumCollectionVC.view)
        albumCollectionVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            albumCollectionVC.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            albumCollectionVC.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            albumCollectionVC.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            albumCollectionVC.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func updateRowHeight() {
        DispatchQueue.main.async { [weak self] in
            self?.tableView?.updateRowHeightsWithoutReloadingRows()
        }
    }

    // Update cell size when collection view is done laying out
    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        return albumCollectionVC.collectionView.contentSize
    }
}
