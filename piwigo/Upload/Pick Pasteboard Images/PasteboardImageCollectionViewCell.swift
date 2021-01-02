//
//  PasteboardImageCollectionViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/12/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Photos
import UIKit

@objc
class PasteboardImageCollectionViewCell: UICollectionViewCell {

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
            uploadedImage?.isHidden = true
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
            waitingActivity?.isHidden = !waiting
            uploadingProgress?.isHidden = !waiting
            uploadedImage?.isHidden = waiting
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
            waitingActivity?.isHidden = uploading
            uploadingProgress?.isHidden = !uploading
            uploadedImage?.isHidden = uploading
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
            waitingActivity?.isHidden = uploaded
            uploadingProgress?.isHidden = uploaded
            uploadedImage?.isHidden = !uploaded
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
    
    @objc
    func configure(with image: UIImage, identifier: String, thumbnailSize: CGFloat) {
        
        // Background color and aspect
        backgroundColor = UIColor.piwigoColorCellBackground()
        waitingActivity.color = UIColor.white
        uploadingProgress.trackTintColor = UIColor.white
        localIdentifier = identifier

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
        self.cellImage.image = cropImage(image, viewWidth: thumbnailSize * CGFloat(retinaScale), viewHeight: thumbnailSize * CGFloat(retinaScale))
        if identifier.contains("mov") {
            self.playImage?.isHidden = false
        }
    }
    
    func setProgress(_ progress: Float, withAnimation animate: Bool) {
        uploadingProgress?.setProgress(progress, animated: animate)
    }

    override func prepareForReuse() {
        cellImage.image = UIImage(named: "placeholder")
        playImage.isHidden = true
        cellSelected = false
        setProgress(0, withAnimation: false)
    }

    func cropImage(_ inputImage: UIImage, viewWidth: CGFloat, viewHeight: CGFloat) -> UIImage?
    {
        let imageViewScale = max(inputImage.size.width / viewWidth,
                                 inputImage.size.height / viewHeight)

        // Handle images larger than shown-on-screen size
        let cropZone = CGRect(x:0.0, y:0.0,
                              width:inputImage.size.width * imageViewScale,
                              height:inputImage.size.height * imageViewScale)

        // Perform cropping in Core Graphics
        guard let cutImageRef: CGImage = inputImage.cgImage?.cropping(to:cropZone)
        else {
            return nil
        }

        // Return image to UIImage
        let croppedImage: UIImage = UIImage(cgImage: cutImageRef)
        return croppedImage
    }
}
