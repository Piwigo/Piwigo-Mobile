//
//  EditImageThumbTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/01/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5.3 by Eddy Lelièvre-Berna on 30/08/2021.
//

import UIKit
import piwigoKit

@objc protocol EditImageThumbnailCellDelegate: NSObjectProtocol {
    func didDeselectImage(withId imageId: Int64)
    func didRenameFileOfImage(_ imageData: Image)
}

class EditImageThumbTableViewCell: UITableViewCell, UICollectionViewDelegate
{
    weak var delegate: EditImageThumbnailCellDelegate?
    
    @IBOutlet private var editImageThumbCollectionView: UICollectionView!

    private var images: [Image]?
    private var startingScrollingOffset = CGPoint.zero

    override func awakeFromNib() {
        super.awakeFromNib()

        // Register thumbnail collection view cell
        editImageThumbCollectionView.register(UINib(nibName: "EditImageThumbCollectionViewCell",
            bundle: nil), forCellWithReuseIdentifier: "EditImageThumbCollectionViewCell")
    }

    func config(withImages imageSelection: [Image]?) {
        // Data
        images = imageSelection

        // Collection of images
        backgroundColor = .piwigoColorCellBackground()
        if editImageThumbCollectionView == nil {
            editImageThumbCollectionView = UICollectionView(frame: CGRect.zero,
                                                            collectionViewLayout: UICollectionViewFlowLayout())
            editImageThumbCollectionView.reloadData()
        } else {
            editImageThumbCollectionView.collectionViewLayout.invalidateLayout()
        }
    }
}

    
// MARK: - UICollectionViewDataSource Methods
extension EditImageThumbTableViewCell: UICollectionViewDataSource
{
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // Returns number of images or albums
        return images?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EditImageThumbCollectionViewCell", for: indexPath) as? EditImageThumbCollectionViewCell else {
            print("Error: collectionView.dequeueReusableCell does not return a EditImageThumbCollectionViewCell!")
            return EditImageThumbCollectionViewCell()
        }
        cell.config(withImage: images?[indexPath.row], removeOption: ((images?.count ?? 0) > 1))
        cell.delegate = self
        return cell
    }
}


// MARK: - UICollectionViewDelegateFlowLayout Methods
extension EditImageThumbTableViewCell: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        // Avoid unwanted spaces
        return UIEdgeInsets(top: 0, left: AlbumUtilities.kImageDetailsMarginsSpacing,
                            bottom: 0, right: AlbumUtilities.kImageDetailsMarginsSpacing)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return AlbumUtilities.kImageDetailsCellSpacing
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: AlbumUtilities.imageDetailsSize(forView: self), height: 152.0)
    }
}


// MARK: - EditImageThumbnailDelegate Methods
extension EditImageThumbTableViewCell: EditImageThumbnailDelegate
{
    @objc
    func didDeselectImage(withId imageId: Int64) {
        // Update data source
        let newImages = images?.filter({ $0.pwgID != imageId })
        images = newImages
        editImageThumbCollectionView.reloadData()

        // Deselect image in parent view
        delegate?.didDeselectImage(withId: imageId)
    }

    @objc
    func didRenameFileOfImage(withId imageId: Int64, andFilename fileName: String) {
        // Retrieve image data from cache
        guard let imageToUpdate = images?.first(where: {$0.pwgID == imageId}) else { return }
        
        // Update image in cache
        imageToUpdate.fileName = fileName

        // Update parent image view
        delegate?.didRenameFileOfImage(imageToUpdate)
    }
}


// MARK: - UIScrollViewDelegate Methods
extension EditImageThumbTableViewCell: UIScrollViewDelegate
{
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        startingScrollingOffset = scrollView.contentOffset
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>)
    {
        let cellWidth: CGFloat = collectionView(editImageThumbCollectionView, layout: editImageThumbCollectionView.collectionViewLayout, sizeForItemAt: IndexPath(row: 0, section: 0)).width + AlbumUtilities.kImageDetailsMarginsSpacing / 2.0
        let offset:CGFloat = scrollView.contentOffset.x + scrollView.contentInset.left
        let proposedPage: CGFloat = offset / fmax(1.0, cellWidth)
        let snapPoint: CGFloat = 0.1
        let snapDelta: CGFloat = offset > startingScrollingOffset.x ? (1 - snapPoint) : snapPoint

        var page: CGFloat
        if floor(proposedPage + snapDelta) == floor(proposedPage) {
            page = floor(proposedPage)
        } else {
            page = floor(proposedPage + 1)
        }

        targetContentOffset.pointee = CGPoint(x: cellWidth * page,
                                              y: targetContentOffset.pointee.y)
    }
}
