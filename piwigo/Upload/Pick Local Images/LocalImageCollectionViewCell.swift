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
    
    @objc
    func configure(with imageAsset: PHAsset, thumbnailSize: CGFloat) {
        
        // Background color and aspect
        backgroundColor = .piwigoColorCellBackground()
        waitingActivity.color = UIColor.white
        uploadingProgress.trackTintColor = UIColor.white
        localIdentifier = imageAsset.localIdentifier

        // Selected icon: match size to cell size
        let scale: CGFloat = fmax(1.0, self.traitCollection.displayScale);
        selectImgWidth.constant = frame.size.width * selectScale + (scale - 1)
        selectImgHeight.constant = selectImgWidth.constant * selectRatio

        // Video icon: match size to cell size
        let width = frame.size.width * playScale + (scale - 1)
        playBckg.setMovieImage(inBackground: true)
        playBckgWidth.constant = width + 2*offset
        playBckgHeight.constant = width * playRatio + 2*offset
        playImg.setMovieImage(inBackground: false)
        playBckg.addSubview(playImg)
        playBckg.addConstraints(NSLayoutConstraint.constraintCenter(playImg)!)
        playBckg.addConstraints(NSLayoutConstraint.constraintView(playImg, to: CGSize(width: width, height: width * playRatio))!)
        
        // Uploaded icon: match size to cell size
        uploadedImgWidth.constant = frame.size.width * uploadedScale + (scale - 1)
        uploadedImgHeight.constant = uploadedImgWidth.constant * uploadedRatio
        
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
    
    func setProgress(_ progressFraction: Float, withAnimation animate: Bool) {
        let progress = max(uploadingProgress.progress, progressFraction)
        uploadingProgress?.setProgress(progress, animated: animate)
    }

    override func prepareForReuse() {
        cellImage.image = UIImage(named: "placeholder")
        playBckg.isHidden = true
        playImg.isHidden = true
        cellSelected = false
        uploadingProgress?.isHidden = true
        uploadingProgress?.setProgress(0, animated: false)
        failedUploadImage.isHidden = true
        waitingActivity?.isHidden = true
    }
}
