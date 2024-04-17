//
//  ImageCollectionTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 10/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import UIKit

class ImageCollectionTableViewCell: UITableViewCell
{
    var imageCollectionVC: ImageCollectionViewController!
        
    override func awakeFromNib() {
        super.awakeFromNib()
        initCollectionView()
    }

    private func initCollectionView() {
        // Create image collection view controller
        let imageSB = UIStoryboard(name: "AlbumImageTableViewController", bundle: nil)
        guard let imageVC = imageSB.instantiateViewController(withIdentifier: "ImageCollectionViewController") as? ImageCollectionViewController else { fatalError("!!! No ImageCollectionViewController !!!") }
        imageCollectionVC = imageVC
        
        // Need to update row height when collection view finishes its layout.
        imageCollectionVC.didLayoutAction = updateRowHeight
        
        contentView.addSubview(imageCollectionVC.view)
        imageCollectionVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageCollectionVC.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            imageCollectionVC.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            imageCollectionVC.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageCollectionVC.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func updateRowHeight() {
        DispatchQueue.main.async { [weak self] in
            self?.tableView?.updateRowHeightsWithoutReloadingRows()
        }
    }

    // Update cell size when collection view is done laying out
    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        return imageCollectionVC.collectionView.contentSize
    }
}
