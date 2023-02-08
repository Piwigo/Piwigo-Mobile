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

    private var _localIdentifier = ""
    var localIdentifier: String {
        get {
            _localIdentifier
        }
        set(localIdentifier) {
            _localIdentifier = localIdentifier
        }
    }

    private var _md5sum = ""
    var md5sum: String {
        get {
            _md5sum
        }
        set(md5sum) {
            _md5sum = md5sum
        }
    }

    private var _progress: Float = 0.0
    var progress: Float {
        get {
            _progress
        }
        set(progress) {
            setProgress(progress, withAnimation: true)
        }
    }
    
    private let offset: CGFloat = 1.0
    private let playScale: CGFloat = 0.16
    let selectScale: CGFloat = 0.14
    let selectRatio: CGFloat = 75/53
    let uploadedScale: CGFloat = 0.16
    let uploadedRatio: CGFloat = 1.0
    
    @IBOutlet weak var cellImage: UIImageView!
    
    var playImg = UIImageView()
    @IBOutlet weak var playBckg: UIImageView!
    @IBOutlet weak var playBckgWidth: NSLayoutConstraint!
    @IBOutlet weak var playBckgHeight: NSLayoutConstraint!
    
    @IBOutlet weak var selectedImage: UIImageView!
    @IBOutlet weak var selectImgWidth: NSLayoutConstraint!
    @IBOutlet weak var selectImgHeight: NSLayoutConstraint!
    
    @IBOutlet weak var uploadedImage: UIImageView!
    @IBOutlet weak var uploadedImgWidth: NSLayoutConstraint!
    @IBOutlet weak var uploadedImgHeight: NSLayoutConstraint!
    
    @IBOutlet weak var darkenView: UIView!
    @IBOutlet weak var waitingActivity: UIActivityIndicatorView!
    @IBOutlet weak var uploadingProgress: UIProgressView!
    @IBOutlet weak var failedUploadImage: UIImageView!
    
    private func configureIcons() {
        // Background color and aspect
        backgroundColor = .piwigoColorCellBackground()
        waitingActivity.color = UIColor.white
        uploadingProgress.trackTintColor = UIColor.white

        // Selected icon: match size to cell size
        let scale = CGFloat(fmax(1.0, self.traitCollection.displayScale))
        selectImgWidth.constant = frame.size.width * selectScale + (scale - 1)
        selectImgHeight.constant = selectImgWidth.constant * selectRatio

        // Video icon: match size to cell size
        let width = frame.size.width * playScale + (scale - 1)
        playBckg.setMovieIconImage()
        playBckg.tintColor = UIColor.white.withAlphaComponent(0.3)
        playBckgWidth.constant = width + 2*offset
        playBckgHeight.constant = playBckgWidth.constant * playRatio
        playImg.setMovieIconImage()
        playImg.tintColor = UIColor.white
        playBckg.addSubview(playImg)
        playBckg.addConstraints(NSLayoutConstraint.constraintCenter(playImg)!)
        playBckg.addConstraints(NSLayoutConstraint.constraintView(playImg, to: CGSize(width: width, height: width * playRatio))!)
        
        // Uploaded icon: match size to cell size
        uploadedImgWidth.constant = frame.size.width * uploadedScale + (scale - 1)
        uploadedImgHeight.constant = uploadedImgWidth.constant * uploadedRatio
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
            DispatchQueue.main.async(execute: {
                guard let image = result else {
                    if let error = info?[PHImageErrorKey] as? Error {
                        debugPrint("=> Error : \(error.localizedDescription)")
                    }
                    self.cellImage.image = UIImage(named: "placeholder")
                    return
                }
                
                self.cellImage.image = image
                if imageAsset.mediaType == .video {
                    self.playBckg?.isHidden = false
                    self.playImg.isHidden = false
                }
            })
        })
    }
    
    func configure(with image: UIImage, identifier: String, thumbnailSize: CGFloat) {
        // Configure icons
        configureIcons()
        
        // Store local identifier
        localIdentifier = identifier
        
        // Image: retrieve data of right size and crop image
        self.cellImage.image = image
        if identifier.contains("mov") {
            self.playBckg?.isHidden = false
            self.playImg.isHidden = false
        }
    }
    
    func update(selected: Bool, state: pwgUploadState? = nil) {
        // Selection mode
        selectedImage?.isHidden = !selected
        darkenView?.isHidden = !selected

        // Upload state
        guard let state = state else {
            waitingActivity?.isHidden = true
            uploadingProgress?.isHidden = true
            uploadedImage?.isHidden = true
            failedUploadImage?.isHidden = true
            return
        }
        switch state {
        case .waiting, .preparing, .prepared, .deleted:
            darkenView?.isHidden = false
            waitingActivity?.isHidden = false
            uploadingProgress?.isHidden = false
            uploadingProgress?.setProgress(0, animated: false)
            uploadedImage?.isHidden = true
            failedUploadImage?.isHidden = true
        case .uploading:
            darkenView?.isHidden = false
            waitingActivity?.isHidden = true
            uploadingProgress?.isHidden = false
            uploadingProgress?.setProgress(_progress, animated: false)
            uploadedImage?.isHidden = true
            failedUploadImage?.isHidden = true
        case .uploaded, .finishing:
            darkenView?.isHidden = false
            waitingActivity?.isHidden = true
            uploadingProgress?.isHidden = false
            uploadingProgress?.setProgress(1.0, animated: false)
            uploadedImage?.isHidden = true
            failedUploadImage?.isHidden = true
        case .finished, .moderated:
            darkenView?.isHidden = false
            uploadingProgress?.isHidden = true
            uploadingProgress?.setProgress(1, animated: false)
            uploadedImage?.isHidden = false
            failedUploadImage?.isHidden = true
            waitingActivity?.isHidden = true
        case .preparingFail, .preparingError, .formatError,
             .uploadingError, .uploadingFail, .finishingError, .finishingFail:
            darkenView?.isHidden = true
            uploadingProgress?.isHidden = true
            uploadingProgress?.setProgress(_progress, animated: false)
            uploadedImage?.isHidden = true
            failedUploadImage?.isHidden = false
            waitingActivity?.isHidden = true
        }
    }

    func setProgress(_ progressFraction: Float, withAnimation animate: Bool) {
        let progress = max(uploadingProgress.progress, progressFraction)
        uploadingProgress?.setProgress(progress, animated: animate)
    }

    override func prepareForReuse() {
        cellImage.image = UIImage(named: "placeholder")
        playBckg.isHidden = true
        playImg.isHidden = true
    }
}
