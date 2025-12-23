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
    @IBOutlet weak var playIcon: UIImageView!
    @IBOutlet weak var selectedIcon: UIImageView!
    @IBOutlet weak var uploadedImage: UIImageView!
    @IBOutlet weak var darkenView: UIView!
    @IBOutlet weak var waitingActivity: UIActivityIndicatorView!
    @IBOutlet weak var uploadingProgress: UIProgressView!
    @IBOutlet weak var failedUploadImage: UIImageView!
    
    private func applyColorPalette() {
        // Appearance
        backgroundColor = PwgColor.cellBackground
        selectedIcon?.layer.shadowColor = UIColor.white.cgColor
        playIcon?.layer.shadowColor = UIColor.black.cgColor
        waitingActivity?.color = UIColor.white
        uploadingProgress?.trackTintColor = UIColor.white
    }

    @MainActor  // Image from the Photos Library
    func configure(with imageAsset: PHAsset, thumbnailSize: CGSize) {
//        debugPrint("••> Configure cell with ID: \(imageAsset.localIdentifier)")
        // Configure icons
        applyColorPalette()
        
        // Store local identifier
        localIdentifier = imageAsset.localIdentifier

        // Image: retrieve data of right size and crop image
        let retinaScale = Int(UIScreen.main.scale)
        let retinaSquare = CGSize(width: thumbnailSize.width * CGFloat(retinaScale),
                                  height: thumbnailSize.height * CGFloat(retinaScale))

        let cropToSquare = PHImageRequestOptions()
        cropToSquare.resizeMode = .exact
        let cropSideLength = min(imageAsset.pixelWidth, imageAsset.pixelHeight)
        let square = CGRect(x: 0, y: 0, width: cropSideLength, height: cropSideLength)
        let cropRect = square.applying(CGAffineTransform(scaleX: CGFloat(1.0 / Float(imageAsset.pixelWidth)), y: CGFloat(1.0 / Float(imageAsset.pixelHeight))))
        cropToSquare.normalizedCropRect = cropRect

        PHImageManager.default().requestImage(for: imageAsset, targetSize: retinaSquare, contentMode: .aspectFit, options: cropToSquare, resultHandler: { result, info in
            DispatchQueue.main.async {
                guard let image = result else {
                    if let error = info?[PHImageErrorKey] as? (any Error) {
                        debugPrint("••> Error : \(error.localizedDescription)")
                    }
                    self.changeCellImageIfNeeded(withImage: pwgImageType.image.placeHolder)
                    return
                }
                
                self.changeCellImageIfNeeded(withImage: image)
                let isVideo = imageAsset.mediaType == .video
                self.playIcon?.isHidden = !isVideo
            }
        })
    }
    
    @MainActor  // Image from the Pasteboard
    func configure(with image: UIImage, identifier: String) {
        // Configure icons
        applyColorPalette()
        
        // Store local identifier
        localIdentifier = identifier
        
        // Image: retrieve data of right size and crop image
        changeCellImageIfNeeded(withImage: image)
        let isVideo = identifier.contains("mov")
        self.playIcon?.isHidden = !isVideo
    }
    
    func update(selected: Bool, state: pwgUploadState? = nil) {
//        debugPrint("••> Update cell with ID: \(self.localIdentifier) to state: \(state?.stateInfo ?? "nil")")
        // No upload state ► selected/deselected
        guard let state = state else {
            selectedIcon?.isHidden = !selected
            darkenView?.isHidden = !selected
            waitingActivity?.isHidden = true
            waitingActivity?.stopAnimating()
            uploadingProgress?.isHidden = true
            uploadingProgress?.setProgress(0, animated: false)
            uploadedImage?.isHidden = true
            failedUploadImage?.isHidden = true
            return
        }
        // Known upload request state
        switch state {
        case .waiting, .preparing, .prepared:
            selectedIcon?.isHidden = true
            darkenView?.isHidden = false
            waitingActivity?.isHidden = false
            waitingActivity?.startAnimating()
            uploadingProgress?.isHidden = false
            uploadingProgress?.setProgress(0, animated: false)
            uploadedImage?.isHidden = true
            failedUploadImage?.isHidden = true
        case .uploading:
            selectedIcon?.isHidden = true
            darkenView?.isHidden = false
            waitingActivity?.isHidden = false
            waitingActivity?.startAnimating()
            uploadingProgress?.isHidden = false
            uploadedImage?.isHidden = true
            failedUploadImage?.isHidden = true
        case .uploaded, .finishing:
            selectedIcon?.isHidden = true
            darkenView?.isHidden = false
            waitingActivity?.isHidden = false
            waitingActivity?.startAnimating()
            uploadingProgress?.isHidden = false
            uploadingProgress?.setProgress(1.0, animated: false)
            uploadedImage?.isHidden = true
            failedUploadImage?.isHidden = true
        case .finished, .moderated:
            selectedIcon?.isHidden = !selected
            darkenView?.isHidden = false
            waitingActivity?.isHidden = true
            waitingActivity?.stopAnimating()
            uploadingProgress?.isHidden = true
            uploadedImage?.isHidden = false
            failedUploadImage?.isHidden = true
        case .preparingFail, .preparingError, .formatError,
             .uploadingError, .uploadingFail, .finishingError, .finishingFail:
            selectedIcon?.isHidden = true
            darkenView?.isHidden = true
            uploadingProgress?.isHidden = true
            uploadedImage?.isHidden = true
            failedUploadImage?.isHidden = false
            waitingActivity?.isHidden = true
            waitingActivity?.stopAnimating()
        }
    }

    func setProgress(_ progressFraction: Float, withAnimation animate: Bool) {
        let progress = max(uploadingProgress.progress, progressFraction)
        uploadingProgress?.setProgress(progress, animated: animate)
    }

    private func changeCellImageIfNeeded(withImage image: UIImage) {
        if let oldImage = self.cellImage.image,
           oldImage.isEqual(image) { return }
        self.cellImage.image = image
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
}
