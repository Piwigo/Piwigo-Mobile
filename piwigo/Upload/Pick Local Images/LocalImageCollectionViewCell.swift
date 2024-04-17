//
//  LocalImageCollectionViewCell.swift
//  piwigo
//
//  Created by Spencer Baker on 1/28/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.1 by Eddy Lelièvre-Berna on 13/04/2020
//

import Photos
import UIKit
import piwigoKit

class LocalImageCollectionViewCell: UICollectionViewCell {

    var localIdentifier = ""
    var md5sum = ""
    
    @IBOutlet weak var cellImage: UIImageView!
    @IBOutlet weak var playImg: UIImageView!
    @IBOutlet weak var selectedImage: UIImageView!
    @IBOutlet weak var uploadedImage: UIImageView!
    @IBOutlet weak var darkenView: UIView!
    @IBOutlet weak var waitingActivity: UIActivityIndicatorView!
    @IBOutlet weak var uploadingProgress: UIProgressView!
    @IBOutlet weak var failedUploadImage: UIImageView!
    
    private func configureIcons() {
        // Background color and aspect
        backgroundColor = .piwigoColorCellBackground()
        waitingActivity.color = UIColor.white
        uploadingProgress.trackTintColor = UIColor.white

        // Video icon
        playImg.setMovieIconImage()
    }

    func configure(with imageAsset: PHAsset, thumbnailSize: CGFloat) {
        // Configure icons
        configureIcons()
        
        // Store local identifier
        localIdentifier = imageAsset.localIdentifier

        // Image: retrieve data of right size and crop image
        let retinaScale = Int(UIScreen.main.scale)
        let retinaSquare = CGSize(width: thumbnailSize * CGFloat(retinaScale), height: thumbnailSize * CGFloat(retinaScale))

        let cropToSquare = PHImageRequestOptions()
        cropToSquare.resizeMode = .exact
        let cropSideLength = min(imageAsset.pixelWidth, imageAsset.pixelHeight)
        let square = CGRect(x: 0, y: 0, width: cropSideLength, height: cropSideLength)
        let cropRect = square.applying(CGAffineTransform(scaleX: CGFloat(1.0 / Float(imageAsset.pixelWidth)), y: CGFloat(1.0 / Float(imageAsset.pixelHeight))))
        cropToSquare.normalizedCropRect = cropRect

        PHImageManager.default().requestImage(for: imageAsset, targetSize: retinaSquare, contentMode: .aspectFit, options: cropToSquare, resultHandler: { result, info in
            DispatchQueue.main.async {
                guard let image = result else {
                    if let error = info?[PHImageErrorKey] as? Error {
                        print("••> Error : \(error.localizedDescription)")
                    }
                    self.changeCellImageIfNeeded(withImage: UIImage(named: "placeholder")!)
                    return
                }
                
                self.changeCellImageIfNeeded(withImage: image)
                if imageAsset.mediaType == .video, self.playImg.isHidden {
                    self.playImg.isHidden = false
                }
            }
        })
    }
    
    func configure(with image: UIImage, identifier: String, thumbnailSize: CGFloat) {
        // Configure icons
        configureIcons()
        
        // Store local identifier
        localIdentifier = identifier
        
        // Image: retrieve data of right size and crop image
        changeCellImageIfNeeded(withImage: image)
        if identifier.contains("mov"), self.playImg.isHidden {
            self.playImg.isHidden = false
        }
    }
    
    func update(selected: Bool, state: pwgUploadState? = nil) {
        print("••> Update cell with ID: \(self.localIdentifier) to state: \(state?.stateInfo ?? "nil")")
        // No upload state ► selected/deselected
        guard let state = state else {
            selectedImage?.isHidden = !selected
            darkenView?.isHidden = !selected
            waitingActivity?.isHidden = true
            uploadingProgress?.isHidden = true
            uploadedImage?.isHidden = true
            failedUploadImage?.isHidden = true
            return
        }
        // Known upload request state
        switch state {
        case .waiting, .preparing, .prepared:
            selectedImage?.isHidden = true
            darkenView?.isHidden = false
            waitingActivity?.isHidden = false
            uploadingProgress?.isHidden = false
            uploadingProgress?.setProgress(0, animated: false)
            uploadedImage?.isHidden = true
            failedUploadImage?.isHidden = true
        case .uploading:
            selectedImage?.isHidden = true
            darkenView?.isHidden = false
            waitingActivity?.isHidden = true
            uploadingProgress?.isHidden = false
            uploadedImage?.isHidden = true
            failedUploadImage?.isHidden = true
        case .uploaded, .finishing:
            selectedImage?.isHidden = true
            darkenView?.isHidden = false
            waitingActivity?.isHidden = false
            uploadingProgress?.isHidden = false
            uploadingProgress?.setProgress(1.0, animated: false)
            uploadedImage?.isHidden = true
            failedUploadImage?.isHidden = true
        case .finished, .moderated:
            selectedImage?.isHidden = !selected
            darkenView?.isHidden = false
            uploadingProgress?.isHidden = true
            uploadedImage?.isHidden = false
            failedUploadImage?.isHidden = true
            waitingActivity?.isHidden = true
        case .preparingFail, .preparingError, .formatError,
             .uploadingError, .uploadingFail, .finishingError, .finishingFail:
            selectedImage?.isHidden = true
            darkenView?.isHidden = true
            uploadingProgress?.isHidden = true
            uploadedImage?.isHidden = true
            failedUploadImage?.isHidden = false
            waitingActivity?.isHidden = true
        }
    }

    func setProgress(_ progressFraction: Float, withAnimation animate: Bool) {
        let progress = max(uploadingProgress.progress, progressFraction)
        uploadingProgress?.setProgress(progress, animated: animate)
    }

    private func changeCellImageIfNeeded(withImage image: UIImage) {
        if let oldImage = self.cellImage.image {
            if oldImage.isEqual(image) == false {
                self.cellImage.image = image
            }
        } else {
            self.cellImage.image = image
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
}
