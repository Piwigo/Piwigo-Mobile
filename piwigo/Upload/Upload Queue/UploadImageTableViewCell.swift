//
//  UploadImageTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import CoreData
import Photos
import UIKit
import piwigoKit
import uploadKit

class UploadImageTableViewCell: UITableViewCell {
    
    // MARK: - Variables
    var localIdentifier = ""
    var objectID: NSManagedObjectID? = nil
    private let offset: CGFloat = 1.0
    private let playScale: CGFloat = 0.20
    private lazy var scale = CGFloat(fmax(1.0, self.traitCollection.displayScale))

    @IBOutlet weak var cellImage: UIImageView!
    @IBOutlet weak var playIcon: UIImageView!
    @IBOutlet weak var uploadInfoLabel: UILabel!
    @IBOutlet weak var uploadingProgress: UIProgressView!
    @IBOutlet weak var imageInfoLabel: UILabel!
    
    // MARK: - Cell Configuration & Update
    func configure(with upload: Upload, availableWidth: Int, maskedCorner: CACornerMask) {

        // Background color and aspect
        backgroundColor = PwgColor.cellBackground
        playIcon?.layer.shadowColor = UIColor.black.cgColor
        localIdentifier = upload.localIdentifier
        objectID = upload.objectID
        
        // Upload info label
        uploadInfoLabel.textColor = PwgColor.leftLabel
        uploadInfoLabel.text = upload.stateLabel
        
        // Uploading progress bar
        switch upload.state {
        case .waiting,
             .preparing, .preparingError, .preparingFail, .formatError, .prepared,
             .uploadingError, .uploadingFail:
            uploadingProgress?.setProgress(0.0, animated: false)
        case .uploaded, .finishing, .finishingError, .finishingFail, .finished, .moderated:
            uploadingProgress?.setProgress(1.0, animated: false)
        case .uploading:
            break
        }

        // Image info label
        imageInfoLabel.textColor = PwgColor.rightLabel
        
        // Prepare image view
        if #available(iOS 26.0, *) {
            // Apply large corner radius to first and last cells
            let oldCornerRadius: CGFloat = TableViewUtilities.defaultOldRCornerRadius - 2.0
            let newCornerRadius: CGFloat = TableViewUtilities.rowCornerRadius - 2.0
            if maskedCorner.isEmpty {
                cellImage.layer.cornerRadius = oldCornerRadius
            } else if maskedCorner.contains(.layerMinXMinYCorner) {
                cellImage.roundCorners(topLeft: newCornerRadius, topRight: oldCornerRadius,
                                       bottomLeft: oldCornerRadius, bottomRight: oldCornerRadius)
            } else if maskedCorner.contains(.layerMinXMaxYCorner) {
                cellImage.roundCorners(topLeft: oldCornerRadius, topRight: oldCornerRadius,
                                       bottomLeft: newCornerRadius, bottomRight: oldCornerRadius)
            }
        } else {
            // Fallback on previous version
            cellImage.layer.cornerRadius = TableViewUtilities.rowCornerRadius - 2.0
        }
        
        // Determine from where the file comes from:
        // => Photo Library: use PHAsset local identifier
        // => UIPasteborad: use identifier of type "Clipboard-yyyyMMdd-HHmmssSSSS-typ-#"
        //    where "typ" is "img" (photo) or "mov" (video).
        if upload.localIdentifier.contains(UploadManager.shared.kClipboardPrefix) {
            // Case of an image retrieved from the pasteboard
            prepareThumbnailFromFile(for: upload, availableWidth: availableWidth)
        } else {
            // Case of an image from the local Photo Library
            prepareThumbnailFromAsset(for: upload, availableWidth: availableWidth)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }


    // MARK: - Thumbnail Preparation
    /// Case of an image from the pasteboard
    private func prepareThumbnailFromFile(for upload:Upload, availableWidth:Int) {
        // Get file URL from identifier
        let fileURL = UploadManager.shared.uploadsDirectory
            .appendingPathComponent(upload.localIdentifier)
        
        // Task depends on file type
        var image: UIImage!
        if fileURL.lastPathComponent.contains("img") {
            // Case of a photo
            playIcon.isHidden = true

            // Retrieve image data from file stored in the Uploads directory
            var fullResImageData: Data = Data()
            do {
                try fullResImageData = NSData (contentsOf: fileURL) as Data

                // Retrieve UIImage from imageData
                image = UIImage(data: fullResImageData) ?? pwgImageType.image.placeHolder

                // Fix orientation if needed
                image = image.fixOrientation()
            }
            catch let error {
                // Could not find the file to upload!
                debugPrint(error.localizedDescription)
                image = pwgImageType.image.placeHolder
            }
        }
        else if fileURL.lastPathComponent.contains("mov") {
            // Case of a movie
            let asset = AVURLAsset(url: fileURL, options: nil)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            do {
                image = UIImage(cgImage: try imageGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil))
            } catch {
                image = pwgImageType.image.placeHolder
            }
            
            // Add movie icon
            playIcon.isHidden = false
        }
        else {
            // Unknown type
            playIcon.isHidden = true
            image = pwgImageType.image.placeHolder
        }

        // Scale/crop image
        let finalImage = image.crop(width: 1.0, height: 1.0)?.resize(to: 58.0, opaque: true, scale: scale)
        if let currentImage = cellImage.image, !currentImage.isEqual(finalImage) {
            cellImage.image = finalImage
        }

        // Image available
        var text = ""
        if [.preparingError, .preparingFail, .formatError,
            .uploadingError, .uploadingFail, .finishingError].contains(upload.state) {
            // Display error message
            text = errorDescription(for: upload)
        } else if image != pwgImageType.image.placeHolder {
            // Display image information
            let maxSize = upload.resizeImageOnUpload ? upload.photoMaxSize : Int16.max
            text = getImageInfo(from: image ?? pwgImageType.image.placeHolder,
                                for: availableWidth - 2*Int(indentationWidth),
                                maxSize: maxSize)
        }
        imageInfoLabel.text = text
    }

    /// Case of an image from the Photo Library
    private func prepareThumbnailFromAsset(for upload:Upload, availableWidth:Int) {
        // Get corresponding image asset
        guard let imageAsset = PHAsset.fetchAssets(withLocalIdentifiers: [upload.localIdentifier], options: nil).firstObject else {
            cellImage.image = pwgImageType.image.placeHolder
            imageInfoLabel.text = errorDescription(for: upload)
            uploadingProgress?.setProgress(0.0, animated: false)
            playIcon.isHidden = true
            return
        }
        
        // Image asset available
        var text = ""
        if [.preparingError, .preparingFail, .formatError,
            .uploadingError, .uploadingFail, .finishingError].contains(upload.state) {
            // Display error message
            text = errorDescription(for: upload)
        } else {
            // Display image information
            let maxSize = upload.resizeImageOnUpload ? upload.photoMaxSize : Int16.max
            text = getImageInfo(from: imageAsset, for: availableWidth - 2*Int(indentationWidth),
                                maxSize: maxSize)
        }
        imageInfoLabel.text = text
        print("imageInfoLabel text: '\(text)'")
        print("imageInfoLabel font: \(String(describing: imageInfoLabel.font))")

        // Cell image: retrieve data of right size and crop image
        let squareSize = CGSize(width: 58.0 * scale, height: 58.0 * scale)
        let cropToSquare = PHImageRequestOptions()
        cropToSquare.resizeMode = .exact
        let cropSideLength = min(imageAsset.pixelWidth, imageAsset.pixelHeight)
        let square = CGRect(x: 0, y: 0, width: cropSideLength, height: cropSideLength)
        let cropRect = square.applying(CGAffineTransform(scaleX: CGFloat(1.0 / Float(imageAsset.pixelWidth)), y: CGFloat(1.0 / Float(imageAsset.pixelHeight))))
        cropToSquare.normalizedCropRect = cropRect

        PHImageManager.default().requestImage(for: imageAsset, targetSize: squareSize, contentMode: .aspectFill, options: cropToSquare, resultHandler: { result, info in
            DispatchQueue.main.async {
                guard let image = result else {
                    if let error = info?[PHImageErrorKey] as? Error {
                        debugPrint("••> Error : \(error.localizedDescription)")
                    }
                    self.changeCellImageIfNeeded(withImage: pwgImageType.image.placeHolder)
                    return
                }

                self.changeCellImageIfNeeded(withImage: image)
            }
        })
        
        // Video icon?
        playIcon.isHidden = (imageAsset.mediaType != .video)
    }
    
    private func getImageInfo(from imageAsset: PHAsset, for availableWidth: Int, maxSize: Int16) -> String {
        var pixelWidth = Float(imageAsset.pixelWidth)
        var pixelHeight = Float(imageAsset.pixelHeight)
        let imageSize = max(pixelWidth, pixelHeight)
        let maxPhotoSize = pwgPhotoMaxSizes(rawValue: maxSize)?.pixels ?? Int.max
        if imageSize > Float(maxPhotoSize) {
            // Will be downsized
            pixelWidth *= Float(maxPhotoSize) / imageSize
            pixelHeight *= Float(maxPhotoSize) / imageSize
        }
        switch imageAsset.mediaType {
        case .image:
            return imageInfo(for: availableWidth, pixelWidth: pixelWidth, pixelHeight: pixelHeight,
                             creationDate: imageAsset.creationDate)
        case .video:
            return videoInfo(for: availableWidth, pixelWidth: pixelWidth, pixelHeight: pixelHeight,
                             duration: imageAsset.duration, creationDate: imageAsset.creationDate)
        default:
            if let creationDate = imageAsset.creationDate {
                return DateFormatter.localizedString(from: creationDate, dateStyle: .full, timeStyle: .none)
            }
        }
        return ""
    }

    private func getImageInfo(from image: UIImage, for availableWidth: Int, maxSize: Int16) -> String {
        var pixelWidth = Float(image.size.width)
        var pixelHeight = Float(image.size.height)
        let imageSize = max(pixelWidth, pixelHeight)
        let maxPhotoSize = pwgPhotoMaxSizes(rawValue: maxSize)?.pixels ?? Int.max
        if imageSize > Float(maxPhotoSize) {
            // Will be downsized
            pixelWidth *= Float(maxPhotoSize) / imageSize
            pixelHeight *= Float(maxPhotoSize) / imageSize
        }
        return imageInfo(for: availableWidth, pixelWidth: pixelWidth, pixelHeight: pixelHeight, creationDate: Date())
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
    

    // MARK: - Utilities
    func errorDescription(for upload: Upload) -> String {
        // Display error message
        let error: String?
        if upload.requestError.isEmpty == false {
            error = upload.requestError
        } else {
            switch upload.state {
            case .preparingError, .preparingFail:
                error = PwgKitError.missingAsset.localizedDescription
            case .formatError:
                error = PwgKitError.wrongDataFormat.localizedDescription
            case .uploadingError, .uploadingFail, .finishingError:
                error = PwgKitError.networkUnavailable.localizedDescription
            default:
                error = "— ? —"
            }
        }
        return error ?? ""
    }
    
    private func imageInfo(for availableWidth:Int,
                           pixelWidth: Float, pixelHeight: Float, creationDate: Date?) -> String {
        // Check date
        guard let creationDate = creationDate else {
            return String(format: "%.0fx%.0f", pixelWidth, pixelHeight)
        }
        
        // Info depends on content size
        var dateString: String = ""
        let preferredContenSize = traitCollection.preferredContentSizeCategory
        switch preferredContenSize {
        case .extraSmall, .small, .medium, .large, .extraLarge:
            dateString = creationDate.formatted(.dateTime
                .day(.defaultDigits) .month(.wide) .year(.twoDigits) .hour() .minute())
        
        case .extraExtraLarge, .extraExtraExtraLarge:
            switch availableWidth {
            case ...375:
                dateString = creationDate.formatted(.dateTime
                    .day(.defaultDigits) .month(.abbreviated) .year(.defaultDigits))
            case 376...402:
                fallthrough
            default:
                dateString = creationDate.formatted(.dateTime
                    .day(.defaultDigits) .month(.wide) .year(.defaultDigits))
            }

        case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge:
            dateString = creationDate.formatted(.dateTime
                .day(.twoDigits) .month(.abbreviated) .year(.twoDigits))

        case .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
            dateString = creationDate.formatted(.dateTime
                .day(.twoDigits) .month(.twoDigits) .year(.twoDigits))

        default:
            break
        }
        return String(format: "%.0fx%.0f • %@", pixelWidth, pixelHeight, dateString)
    }
    
    private func videoInfo(for availableWidth:Int,
                           pixelWidth: Float, pixelHeight: Float,
                           duration: TimeInterval, creationDate: Date?) -> String {
        // Duration
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [ .minute, .second ]
        formatter.zeroFormattingBehavior = [ .pad ]
        let formattedDuration = formatter.string(from: duration)!

        // Check date
        guard let creationDate = creationDate else {
            return String(format: "%.0fx%.0f • %@", pixelWidth, pixelHeight, formattedDuration)
        }

        // Info depends on content size
        var dateString: String = ""
        let preferredContenSize = traitCollection.preferredContentSizeCategory
        switch preferredContenSize {
        case .extraSmall, .small, .medium, .large, .extraLarge:
            dateString = creationDate.formatted(.dateTime
                .day(.twoDigits) .month(.abbreviated) .year(.twoDigits) .hour() .minute())
        
        case .extraExtraLarge, .extraExtraExtraLarge:
            switch availableWidth {
            case ...375:
                dateString = creationDate.formatted(.dateTime
                    .day(.defaultDigits) .month(.abbreviated) .year(.defaultDigits))
            case 376...402:
                fallthrough
            default:
                dateString = creationDate.formatted(.dateTime
                    .day(.defaultDigits) .month(.wide) .year(.defaultDigits))
            }

        case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge:
            dateString = creationDate.formatted(.dateTime
                .day(.twoDigits) .month(.abbreviated) .year(.twoDigits))

        case .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
            dateString = creationDate.formatted(.dateTime
                .day(.twoDigits) .month(.twoDigits) .year(.twoDigits))

        default:
            break
        }
        return String(format: "%.0fx%.0f • %@ • %@", pixelWidth, pixelHeight, formattedDuration, dateString)
    }
}
