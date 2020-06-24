//
//  UploadImageTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Photos
import UIKit

@objc
class UploadImageTableViewCell: MGSwipeTableCell {
    
    // MARK: - Core Data
    /**
     The UploadsProvider that collects upload data, saves it to Core Data,
     and serves it to the uploader.
     */
    private lazy var uploadsProvider: UploadsProvider = {
        let provider : UploadsProvider = UploadsProvider()
        return provider
    }()

    // MARK: - Upload Manager
    /**
     The UploadManager that prepares and transfers images and updates the cache.
     */
    private lazy var uploadManager: UploadManager = {
        let provider : UploadManager = UploadManager()
        return provider
    }()

    // MARK: - Variables
    private var _localIdentifier = ""
    @objc var localIdentifier: String {
        get {
            _localIdentifier
        }
        set(localIdentifier) {
            _localIdentifier = localIdentifier
        }
    }

    @IBOutlet weak var cellImage: UIImageView!
    @IBOutlet weak var playImage: UIImageView!
    @IBOutlet weak var uploadInfoLabel: UILabel!
    @IBOutlet weak var uploadingProgress: UIProgressView!
    @IBOutlet weak var imageInfoLabel: UILabel!
    
    func configure(with upload:Upload) {

        // Background color and aspect
        backgroundColor = UIColor.piwigoColorCellBackground()
        localIdentifier = upload.localIdentifier

        // Get corresponding image asset
        guard let imageAsset = PHAsset.fetchAssets(withLocalIdentifiers: [upload.localIdentifier], options: nil).firstObject else {
            self.cellImage.image = UIImage(named: "placeholder")
            return
        }
        
        // Upload info label
        uploadInfoLabel.textColor = UIColor.piwigoColorLeftLabel()
        uploadInfoLabel.text = upload.stateLabel
        
        // Uploading progress bar
        if [.waiting, .preparing, .prepared, .formatError].contains(upload.state) {
            uploadingProgress?.setProgress(0.0, animated: false)
        }
        if [.uploaded, .finishing, .finishingError, .finished].contains(upload.state) {
            uploadingProgress?.setProgress(1.0, animated: false)
        }

        // Image info label
        imageInfoLabel.textColor = UIColor.piwigoColorRightLabel()
        if [.preparingError, .formatError, .uploadingError, .finishingError].contains(upload.state) {
            imageInfoLabel.text = upload.requestError
        } else {
            imageInfoLabel.text = getImageInfo(from: imageAsset)
        }
                
        // Cell image: retrieve data of right size and crop image
        let retinaScale = Int(UIScreen.main.scale)
        let retinaSquare = CGSize(width: self.contentView.frame.size.width * CGFloat(retinaScale),
                                  height: self.contentView.frame.size.height * CGFloat(retinaScale))

        let cropToSquare = PHImageRequestOptions()
        cropToSquare.resizeMode = .exact
        let cropSideLength = min(imageAsset.pixelWidth, imageAsset.pixelHeight)
        let square = CGRect(x: 0, y: 0, width: cropSideLength, height: cropSideLength)
        let cropRect = square.applying(CGAffineTransform(scaleX: CGFloat(1.0 / Float(imageAsset.pixelWidth)), y: CGFloat(1.0 / Float(imageAsset.pixelHeight))))
        cropToSquare.normalizedCropRect = cropRect

        PHImageManager.default().requestImage(for: imageAsset, targetSize: retinaSquare, contentMode: .aspectFit, options: cropToSquare, resultHandler: { result, info in
            DispatchQueue.main.async(execute: {
                if info?[PHImageErrorKey] != nil {
                    let error = info?[PHImageErrorKey] as? Error
                    if let description = error?.localizedDescription {
                        print("=> Error : \(description)")
                    }
                    self.cellImage.image = UIImage(named: "placeholder")
                } else {
                    self.cellImage.image = result
                }
                self.cellImage.layer.cornerRadius = 10 - 3
            })
        })
        
        // Video icon
        playImage.isHidden = imageAsset.mediaType == .video ? false : true

        // Right => Left swipe commands
        swipeBackgroundColor = UIColor.piwigoColorCellBackground()
        rightExpansion.buttonIndex = 0
        rightExpansion.threshold = 3.0
        rightExpansion.fillOnTrigger = true
        rightExpansion.expansionColor = UIColor.piwigoColorBrown()
        rightSwipeSettings.transition = .border
        switch upload.state {
        case .preparing, .prepared, .uploading, .uploaded, .finishing:
            rightButtons = [];
        case .preparingError, .uploadingError, .finishingError:
            rightButtons = [
                MGSwipeButton(title: "", icon: UIImage(named: "swipeRetry.png"), backgroundColor: UIColor.piwigoColorOrange(), callback: { sender in
                    self.uploadManager.resume(failedUploads: [upload]) { (_) in }
                    return true
                }),
                MGSwipeButton(title: "", icon: UIImage(named: "swipeCancel.png"), backgroundColor: UIColor.piwigoColorBrown(), callback: { sender in
                    self.uploadsProvider.delete(uploadRequests: [upload]) { (_) in }
                    return true
                })]
        case .formatError, .waiting:
            rightButtons = [
                MGSwipeButton(title: "", icon: UIImage(named: "swipeCancel.png"), backgroundColor: UIColor.piwigoColorBrown(), callback: { sender in
                    self.uploadsProvider.delete(uploadRequests: [upload]) { (_) in }
                    return true
                })]
        case .finished:
            rightButtons = [
                MGSwipeButton(title: "", icon: UIImage(named: "swipeCancel.png"), backgroundColor: UIColor.piwigoColorBrown(), callback: { sender in
                    self.uploadsProvider.delete(uploadRequests: [upload]) { (_) in }
                    return true
                }),
                MGSwipeButton(title: "", icon: UIImage(named: "swipeTrashSmall.png"), backgroundColor: .red, callback: { sender in
                    self.uploadManager.delete(uploadedImages: [upload])
                    return true
                })]
        }
    }
    
    func update(with userInfo: [AnyHashable : Any]) {
        // Top label
        let stateInfo = (userInfo["stateInfo"] ?? "") as! String
        uploadInfoLabel.text = stateInfo
        
        // Progress bar
        let progressFraction = (userInfo["progressFraction"] ?? 0.0) as! Float
        uploadingProgress?.setProgress(progressFraction, animated: true)

        // Bottom label
        let errorDescription = (userInfo["Error"] ?? "") as! String
        if errorDescription.count == 0,
            let imageAsset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject {
                imageInfoLabel.text = getImageInfo(from: imageAsset)
        } else {
            imageInfoLabel.text = errorDescription
        }
    }
    
    private func getImageInfo(from imageAsset: PHAsset) -> String {
        switch imageAsset.mediaType {
        case .image:
            if let creationDate = imageAsset.creationDate {
                if self.bounds.size.width > 414 {
                    // i.e. larger than iPhones 6,7 screen width
                    return String(format: "%ldx%ld pixels - %@", imageAsset.pixelWidth, imageAsset.pixelHeight, DateFormatter.localizedString(from: creationDate, dateStyle: .full, timeStyle: .medium))
                } else if self.bounds.size.width > 375 {
                    return String(format: "%ldx%ld pixels — %@", imageAsset.pixelWidth, imageAsset.pixelHeight, DateFormatter.localizedString(from: creationDate, dateStyle: .long, timeStyle: .short))
                } else {
                    return String(format: "%ldx%ld pixels — %@", imageAsset.pixelWidth, imageAsset.pixelHeight, DateFormatter.localizedString(from: creationDate, dateStyle: .short, timeStyle: .short))
                }
            } else {
                return String(format: "%ldx%ld pixels", imageAsset.pixelWidth, imageAsset.pixelHeight)
            }
        case .video:
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [ .minute, .second ]
            formatter.zeroFormattingBehavior = [ .pad ]
            let formattedDuration = formatter.string(from: imageAsset.duration)!
            if let creationDate = imageAsset.creationDate {
                if self.bounds.size.width > 414 {
                    // i.e. larger than iPhones 6,7 screen width
                    return String(format: "%ldx%ld pixels, %@ - %@", imageAsset.pixelWidth, imageAsset.pixelHeight, formattedDuration, DateFormatter.localizedString(from: creationDate, dateStyle: .full, timeStyle: .medium))
                } else if self.bounds.size.width > 375 {
                    return String(format: "%ldx%ld pixels, %@ - %@", imageAsset.pixelWidth, imageAsset.pixelHeight, formattedDuration, DateFormatter.localizedString(from: creationDate, dateStyle: .long, timeStyle: .short))
                } else {
                    return String(format: "%ldx%ld pixels, %@ - %@", imageAsset.pixelWidth, imageAsset.pixelHeight, formattedDuration, DateFormatter.localizedString(from: creationDate, dateStyle: .short, timeStyle: .short))
                }
            } else {
                return String(format: "%ldx%ld pixels, %@", imageAsset.pixelWidth, imageAsset.pixelHeight, formattedDuration)
            }
        default:
            if let creationDate = imageAsset.creationDate {
                return DateFormatter.localizedString(from: creationDate, dateStyle: .full, timeStyle: .none)
            }
        }
        return ""
    }

    override func prepareForReuse() {
        cellImage.image = UIImage(named: "placeholder")
        playImage.isHidden = true
        uploadInfoLabel.text = ""
        uploadingProgress?.setProgress(0, animated: false)
        imageInfoLabel.text = ""
    }
}
