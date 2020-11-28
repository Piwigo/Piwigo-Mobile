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
    
    func configure(with upload:Upload, width:Int) {

        // Background color and aspect
        backgroundColor = UIColor.piwigoColorCellBackground()
        localIdentifier = upload.localIdentifier

        // Upload info label
        uploadInfoLabel.textColor = UIColor.piwigoColorLeftLabel()
        uploadInfoLabel.text = upload.stateLabel
        
        // Uploading progress bar
        if [.waiting, .preparing, .preparingError, .preparingFail, .prepared, .formatError, .uploadingError].contains(upload.state) {
            uploadingProgress?.setProgress(0.0, animated: false)
        }
        if [.uploaded, .finishing, .finishingError, .finished].contains(upload.state) {
            uploadingProgress?.setProgress(1.0, animated: false)
        }

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
                    UploadManager.shared.backgroundQueue.async {
                        UploadManager.shared.resume(failedUploads: [upload], completionHandler: { (_) in })
                    }
                    return true
                }),
                MGSwipeButton(title: "", icon: UIImage(named: "swipeCancel.png"), backgroundColor: UIColor.piwigoColorBrown(), callback: { sender in
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.uploadsProvider.delete(uploadRequests: [upload.objectID])
                    }
                    return true
                })]
        case .waiting, .preparingFail, .formatError:
            rightButtons = [
                MGSwipeButton(title: "", icon: UIImage(named: "swipeCancel.png"), backgroundColor: UIColor.piwigoColorBrown(), callback: { sender in
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.uploadsProvider.delete(uploadRequests: [upload.objectID])
                    }
                    return true
                })]
        case .finished, .moderated:
            rightButtons = [
                MGSwipeButton(title: "", icon: UIImage(named: "swipeCancel.png"), backgroundColor: UIColor.piwigoColorBrown(), callback: { sender in
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.uploadsProvider.delete(uploadRequests: [upload.objectID])
                    }
                    return true
                }),
                MGSwipeButton(title: "", icon: UIImage(named: "swipeTrashSmall.png"), backgroundColor: .red, callback: { sender in
                    UploadManager.shared.delete(uploadedImages: [self.localIdentifier], with: [upload.objectID])
                    return true
                })]
        }

        // Image info label
        imageInfoLabel.textColor = UIColor.piwigoColorRightLabel()
        
        // Get corresponding image asset
        guard let imageAsset = PHAsset.fetchAssets(withLocalIdentifiers: [upload.localIdentifier], options: nil).firstObject else {
            if upload.requestError?.count ?? 0 > 0 {
                imageInfoLabel.text = upload.requestError
            } else {
                switch upload.state {
                case .preparingError, .preparingFail:
                    imageInfoLabel.text = UploadError.missingAsset.localizedDescription
                case .formatError:
                    imageInfoLabel.text = UploadError.wrongDataFormat.localizedDescription
                case .uploadingError, .finishingError:
                    imageInfoLabel.text = UploadError.networkUnavailable.localizedDescription
                default:
                    imageInfoLabel.text = "— ? —"
                }
            }
            self.cellImage.image = UIImage(named: "placeholder")
            uploadingProgress?.setProgress(0.0, animated: false)
            playImage.isHidden = true
            return
        }
        
        // Image asset available
        if [.preparingError, .preparingFail, .formatError, .uploadingError, .finishingError].contains(upload.state) {
            // Display error message
            if upload.requestError?.count ?? 0 > 0 {
                imageInfoLabel.text = upload.requestError
            } else {
                switch upload.state {
                case .preparingError, .preparingFail:
                    imageInfoLabel.text = UploadError.missingAsset.localizedDescription
                case .formatError:
                    imageInfoLabel.text = UploadError.wrongDataFormat.localizedDescription
                case .uploadingError, .finishingError:
                    imageInfoLabel.text = UploadError.networkUnavailable.localizedDescription
                default:
                    imageInfoLabel.text = "— ? —"
                }
                uploadingProgress?.setProgress(0.0, animated: false)
            }
        } else {
            // Display image information
            imageInfoLabel.text = getImageInfo(from: imageAsset, for: width - 2*Int(indentationWidth), scale: upload.photoResize)
        }

        // Cell image: retrieve data of right size and crop image
        let retinaScale = Int(UIScreen.main.scale)
        let retinaSquare = CGSize(width: 58.0 * CGFloat(retinaScale),
                                  height: 58.0 * CGFloat(retinaScale))

        let cropToSquare = PHImageRequestOptions()
        cropToSquare.resizeMode = .exact
        let cropSideLength = min(imageAsset.pixelWidth, imageAsset.pixelHeight)
        let square = CGRect(x: 0, y: 0, width: cropSideLength, height: cropSideLength)
        let cropRect = square.applying(CGAffineTransform(scaleX: CGFloat(1.0 / Float(imageAsset.pixelWidth)), y: CGFloat(1.0 / Float(imageAsset.pixelHeight))))
        cropToSquare.normalizedCropRect = cropRect

        PHImageManager.default().requestImage(for: imageAsset, targetSize: retinaSquare, contentMode: .aspectFill, options: cropToSquare, resultHandler: { result, info in
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
    }
    
    func update(with userInfo: [AnyHashable : Any]) {
        // Top label
        if let stateLabel: String = userInfo["stateLabel"] as! String? {
            uploadInfoLabel.text = stateLabel
        }

        // Progress bar
        if let progressFraction: Float = userInfo["progressFraction"] as! Float? {
            uploadingProgress?.setProgress(progressFraction, animated: true)
        }

        // Bottom label
        let errorDescription = (userInfo["Error"] ?? "") as! String
        if errorDescription.count == 0, let photoResize = userInfo["photoResize"] as? Int16,
            let imageAsset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject {
            imageInfoLabel.text = getImageInfo(from: imageAsset, for: Int(bounds.size.width), scale: photoResize)
        } else if errorDescription.count > 0 {
            imageInfoLabel.text = errorDescription
        }
    }
    
    private func getImageInfo(from imageAsset: PHAsset, for width: Int, scale: Int16) -> String {
        let pixelWidth = (Float(imageAsset.pixelWidth * Int(scale)) / 100.0).rounded()
        let pixelHeight = (Float(imageAsset.pixelHeight * Int(scale)) / 100.0).rounded()
        switch imageAsset.mediaType {
        case .image:
            if let creationDate = imageAsset.creationDate {
                if width > 414 {
                    // i.e. larger than iPhones 6,7 screen width
                    return String(format: "%.0fx%.0f pixels - %@", pixelWidth, pixelHeight, DateFormatter.localizedString(from: creationDate, dateStyle: .full, timeStyle: .medium))
                } else if width > 375 {
                    return String(format: "%.0fx%.0f pixels — %@", pixelWidth, pixelHeight, DateFormatter.localizedString(from: creationDate, dateStyle: .long, timeStyle: .short))
                } else {
                    return String(format: "%.0fx%.0f pixels — %@", pixelWidth, pixelHeight, DateFormatter.localizedString(from: creationDate, dateStyle: .short, timeStyle: .short))
                }
            } else {
                return String(format: "%.0fx%.0f pixels", pixelWidth, pixelHeight)
            }
        case .video:
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [ .minute, .second ]
            formatter.zeroFormattingBehavior = [ .pad ]
            let formattedDuration = formatter.string(from: imageAsset.duration)!
            if let creationDate = imageAsset.creationDate {
                if width > 414 {
                    // i.e. larger than iPhones 6,7 screen width
                    return String(format: "%.0fx%.0f pixels, %@ - %@", pixelWidth, pixelHeight, formattedDuration, DateFormatter.localizedString(from: creationDate, dateStyle: .full, timeStyle: .medium))
                } else if width > 375 {
                    return String(format: "%.0fx%.0f pixels, %@ - %@", pixelWidth, pixelHeight, formattedDuration, DateFormatter.localizedString(from: creationDate, dateStyle: .long, timeStyle: .short))
                } else {
                    return String(format: "%.0fx%.0f pixels, %@ - %@", pixelWidth, pixelHeight, formattedDuration, DateFormatter.localizedString(from: creationDate, dateStyle: .short, timeStyle: .short))
                }
            } else {
                return String(format: "%.0fx%.0f pixels, %@", pixelWidth, pixelHeight, formattedDuration)
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
