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
import PwgKit
import PwgCacheKit
import PwgUIKit
import PwgUploadKit

final class LocalImageCollectionViewCell: UICollectionViewCell {

    var localIdentifier = ""
    var md5sum = ""
    private var currentProgress: Float = 0

    // A Live Photo uploaded as both halves produces two upload requests sharing this cell's
    // localIdentifier, i.e. two independent progress streams for a single progress bar. Each
    // half is tracked separately, keyed by the suffix its file key carries, and the bar shows
    // their mean so that it fills once, smoothly, instead of twice.
    private var expectedParts = 1
    private var partProgress = [String: Float]()

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
    func configure(with imageAsset: PHAsset, thumbnailSize: CGSize,
                   uploadLivePhotoAs: pwgUploadLivePhotoAs) {
//        debugPrint("••> Configure cell with ID: \(imageAsset.localIdentifier)")
        // Configure icons
        applyColorPalette()
        
        // Store local identifier
        localIdentifier = imageAsset.localIdentifier

        // How many upload requests will this asset produce?
        /// The option is provided by the picker, which knows whether the upload being
        /// prepared adopted the default or another one.
        expectedParts = (imageAsset.mediaSubtypes.contains(.photoLive)
                         && uploadLivePhotoAs == .both) ? 2 : 1

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
                        #if DEBUG
                        debugPrint("••> Error : \(error.localizedDescription)")
                        #endif
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

        // A pasteboard object is never a Live Photo, see PasteboardObject
        expectedParts = 1

        // Image: retrieve data of right size and crop image
        changeCellImageIfNeeded(withImage: image)
        let isVideo = identifier.contains(kMovieSuffix)
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
            // The state reaching this cell is that of a single upload request, so when the asset
            // yields two of them it says nothing about the other half: emptying the bar here
            // would wipe the progress of the half already uploaded. The notifications empty it
            // themselves, by reporting a null fraction when the preparation of a half starts.
            if expectedParts == 1 {
                currentProgress = 0
                partProgress = [:]
                uploadingProgress?.setProgress(0, animated: false)
            }
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
            // Only one half is uploaded, see the .waiting case above
            if expectedParts == 1 {
                currentProgress = 1.0
                uploadingProgress?.setProgress(1.0, animated: false)
            }
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
            selectedIcon?.isHidden = !selected
            darkenView?.isHidden = !selected
            uploadingProgress?.isHidden = true
            uploadedImage?.isHidden = true
            failedUploadImage?.isHidden = false
            waitingActivity?.isHidden = true
            waitingActivity?.stopAnimating()
        }
    }
    
    func setProgress(_ progressFraction: Float, forFileKey fileKey: String, withAnimation animate: Bool) {
        // Which half of the asset does this fraction describe?
        let part = fileKey.hasSuffix(kLivePhotoMovieSuffix) ? kLivePhotoMovieSuffix : ""

        // A null fraction is posted when the preparation of a half starts, i.e. it marks the
        // beginning — or the restart, after a failure — of that half. Any other fraction only
        // ever grows: transfers report bytes sent so far.
        if progressFraction <= 0 {
            partProgress[part] = 0
        } else {
            partProgress[part] = max(partProgress[part] ?? 0, progressFraction)
        }

        // Share the bar between the halves. Trust whichever count is the larger, so that the bar
        // cannot overfill if the option changed after these requests were created.
        let parts = max(expectedParts, partProgress.count)
        let combined = partProgress.values.reduce(0, +) / Float(parts)
        guard combined != currentProgress else { return }
        currentProgress = combined
        uploadingProgress?.setProgress(currentProgress, animated: animate)
    }
    
    private func changeCellImageIfNeeded(withImage image: UIImage) {
        if let oldImage = self.cellImage.image,
           oldImage.isEqual(image) { return }
        self.cellImage.image = image
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()

        currentProgress = 0
        partProgress = [:]
        expectedParts = 1
    }
}
