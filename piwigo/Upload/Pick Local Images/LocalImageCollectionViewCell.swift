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

@objc
class LocalImageCollectionViewCell: UICollectionViewCell {

    private var _localIdentifier = ""
    @objc var localIdentifier: String {
        get {
            _localIdentifier
        }
        set(localIdentifier) {
            _localIdentifier = localIdentifier
        }
    }

    private var _cellSelected = false
    @objc var cellSelected: Bool {
        get {
            _cellSelected
        }
        set(cellSelected) {
            _cellSelected = cellSelected
            selectedImage?.isHidden = !cellSelected
            darkenView?.isHidden = !cellSelected
            waitingActivity?.isHidden = true
            uploadingProgress?.isHidden = true
            uploadingProgress?.setProgress(0, animated: false)
            uploadedImage?.isHidden = true
            failedUploadImage?.isHidden = true
        }
    }

    private var _cellWaiting = false
    @objc var cellWaiting: Bool {
        get {
            _cellWaiting
        }
        set(waiting) {
            _cellUploading = waiting
            darkenView?.isHidden = !waiting
            uploadingProgress?.isHidden = !waiting
            uploadedImage?.isHidden = waiting
            uploadingProgress?.setProgress(0, animated: false)
            failedUploadImage?.isHidden = true
            waitingActivity?.isHidden = !waiting
        }
    }

    private var _cellUploading = false
    @objc var cellUploading: Bool {
        get {
            _cellUploading
        }
        set(uploading) {
            _cellUploading = uploading
            darkenView?.isHidden = !uploading
            uploadingProgress?.isHidden = !uploading
            uploadedImage?.isHidden = uploading
            uploadingProgress?.setProgress(_progress, animated: false)
            failedUploadImage?.isHidden = true
            waitingActivity?.isHidden = uploading
        }
    }

    private var _cellUploaded = false
    @objc var cellUploaded: Bool {
        get {
            _cellUploaded
        }
        set(uploaded) {
            _cellUploaded = uploaded
            darkenView?.isHidden = !uploaded
            uploadingProgress?.isHidden = uploaded
            uploadingProgress?.setProgress(1, animated: false)
            uploadedImage?.isHidden = !uploaded
            failedUploadImage?.isHidden = true
            waitingActivity?.isHidden = uploaded
        }
    }

    private var _cellFailed = false
    @objc var cellFailed: Bool {
        get {
            _cellFailed
        }
        set(failed) {
            _cellUploaded = false
            darkenView?.isHidden = !failed
            uploadingProgress?.isHidden = true
            uploadingProgress?.setProgress(_progress, animated: false)
            uploadedImage?.isHidden = true
            failedUploadImage?.isHidden = !failed
            waitingActivity?.isHidden = true
        }
    }

    private var _progress: Float = 0.0
    @objc var progress: Float {
        get {
            _progress
        }
        set(progress) {
            setProgress(progress, withAnimation: true)
        }
    }
    
    @IBOutlet weak var cellImage: UIImageView!
    @IBOutlet weak var playImage: UIImageView!
    @IBOutlet weak var selectedImage: UIImageView!
    @IBOutlet weak var darkenView: UIView!
    @IBOutlet weak var waitingActivity: UIActivityIndicatorView!
    @IBOutlet weak var uploadingProgress: UIProgressView!
    @IBOutlet weak var uploadedImage: UIImageView!
    @IBOutlet weak var failedUploadImage: UIImageView!
    
    @objc
    func configure(with imageAsset: PHAsset, thumbnailSize: CGFloat) {
        
        // Background color and aspect
        backgroundColor = .piwigoColorCellBackground()
        waitingActivity.color = UIColor.white
        uploadingProgress.trackTintColor = UIColor.white
        localIdentifier = imageAsset.localIdentifier

        // Checked icon: reduce original size of 17x25 pixels when using tiny thumbnails
        if thumbnailSize > 0.0 && thumbnailSize < 75.0 {
            let sizeOfIcon = UIImage(named: "checkMark")!.size
            let maxHeightOfIcon = thumbnailSize / 3.0
            let scale = maxHeightOfIcon / sizeOfIcon.height
            contentView.addConstraints(NSLayoutConstraint.constraintView(selectedImage, to: CGSize(width: sizeOfIcon.width * scale, height: sizeOfIcon.height * scale))!)
        }
        
        // Video icon: reduce original size of 25x16 pixels when using tiny thumbnails
        if thumbnailSize > 0.0 && thumbnailSize < 75.0 {
            let sizeOfIcon = UIImage(named: "video")!.size
            let maxWidthOfIcon = thumbnailSize / 3.0
            let scale = maxWidthOfIcon / sizeOfIcon.width
            contentView.addConstraints(NSLayoutConstraint.constraintView(playImage, to: CGSize(width: sizeOfIcon.width * scale, height: sizeOfIcon.height * scale))!)
        }
        
        // Uploaded icon: reduce original size of 25x25 pixels when using tiny thumbnails
        if thumbnailSize > 0.0 && thumbnailSize < 100.0 {
            let sizeOfIcon = UIImage(named: "piwigo")!.size
            let maxWidthOfIcon = thumbnailSize / 4.0
            let scale = maxWidthOfIcon / sizeOfIcon.width
            contentView.addConstraints(NSLayoutConstraint.constraintView(uploadedImage, to: CGSize(width: sizeOfIcon.width * scale, height: sizeOfIcon.height * scale))!)
        }
        
        // Image: retrieve data of right size and crop image
        let retinaScale = Int(UIScreen.main.scale)
        let retinaSquare = CGSize(width: thumbnailSize * CGFloat(retinaScale), height: thumbnailSize * CGFloat(retinaScale))

        let cropToSquare = PHImageRequestOptions()
        cropToSquare.resizeMode = .exact
        let cropSideLength = min(imageAsset.pixelWidth, imageAsset.pixelHeight)
        let square = CGRect(x: 0, y: 0, width: cropSideLength, height: cropSideLength)
        let cropRect = square.applying(CGAffineTransform(scaleX: CGFloat(1.0 / Float(imageAsset.pixelWidth)), y: CGFloat(1.0 / Float(imageAsset.pixelHeight))))
        cropToSquare.normalizedCropRect = cropRect

        PHImageManager.default().requestImage(for: imageAsset, targetSize: retinaSquare, contentMode: .aspectFit, options: cropToSquare, resultHandler: { [unowned self] result, info in
            DispatchQueue.main.async(execute: {
                if (info?[PHImageErrorKey] != nil) || (result == nil) {
                    let error = info?[PHImageErrorKey] as? Error
                    if let description = error?.localizedDescription {
                        print("=> Error : \(description)")
                    }
                    self.cellImage.image = UIImage(named: "placeholder")
                } else {
                    self.cellImage.image = result
                    if imageAsset.mediaType == .video {
                        self.playImage?.isHidden = false
                    }
                }
            })
        })
    }
    
    func setProgress(_ progressFraction: Float, withAnimation animate: Bool) {
        let progress = max(uploadingProgress.progress, progressFraction)
        uploadingProgress?.setProgress(progress, animated: animate)
    }

    override func prepareForReuse() {
        cellImage.image = UIImage(named: "placeholder")
        playImage.isHidden = true
        cellSelected = false
        uploadingProgress?.isHidden = true
        uploadingProgress?.setProgress(0, animated: false)
        failedUploadImage.isHidden = true
        waitingActivity?.isHidden = true
    }
}
