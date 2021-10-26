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
    func didDeselectImage(withId imageId: Int)
    func didRenameFileOfImage(_ imageData: PiwigoImageData)
}

class EditImageThumbTableViewCell: UITableViewCell, UICollectionViewDelegate
{
    weak var delegate: EditImageThumbnailCellDelegate?
    
    @IBOutlet private var editImageThumbCollectionView: UICollectionView!

    private var images: [PiwigoImageData]?
    private var startingScrollingOffset = CGPoint.zero

    override func awakeFromNib() {
        super.awakeFromNib()

        // Register thumbnail collection view cell
        editImageThumbCollectionView.register(UINib(nibName: "EditImageThumbCollectionViewCell",
            bundle: nil), forCellWithReuseIdentifier: "EditImageThumbCollectionViewCell")
    }

    func config(withImages imageSelection: [PiwigoImageData]?) {
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
        return UIEdgeInsets(top: 0, left: kImageDetailsMarginsSpacing, bottom: 0, right: kImageDetailsMarginsSpacing)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return CGFloat(kImageDetailsCellSpacing)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: ImagesCollection.imageDetailsSize(for: self), height: 152.0)
    }
}


// MARK: - EditImageThumbnailDelegate Methods
extension EditImageThumbTableViewCell: EditImageThumbnailDelegate
{
    @objc
    func didDeselectImage(withId imageId: Int) {
        // Update data source
        let newImages = images?.filter({ $0.imageId != imageId })
        images = newImages
        editImageThumbCollectionView.reloadData()

        // Deselect image in parent view
        if delegate?.responds(to: #selector(EditImageThumbnailCellDelegate.didDeselectImage(withId:))) ?? false {
            delegate?.didDeselectImage(withId: imageId)
        }
    }

    @objc
    func didRenameFileOfImage(withId imageId: Int, andFilename fileName: String) {
        // Check accessible data
        guard let indexOfImage = images?.firstIndex(where: { $0.imageId == imageId }),
              let imageToUpdate: PiwigoImageData = images?[indexOfImage] else { return }
        
        // Update data source
        /// Cached data cannot be updated as we may not have downloaded image data.
        /// This happens for example if the user used the search tool right after launching the app.
        imageToUpdate.fileName = fileName
        images?.replaceSubrange(indexOfImage...indexOfImage, with: [imageToUpdate])

        // Update parent image view
        if delegate?.responds(to: #selector(EditImageThumbnailCellDelegate.didRenameFileOfImage(_:))) ?? false {
            delegate?.didRenameFileOfImage(imageToUpdate)
        }
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
        let cellWidth: CGFloat = collectionView(editImageThumbCollectionView, layout: editImageThumbCollectionView.collectionViewLayout, sizeForItemAt: IndexPath(row: 0, section: 0)).width + kImageDetailsMarginsSpacing / 2.0
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
