//
//  UploadImageTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Photos
import UIKit
import piwigoKit

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
    private let imagePlaceholder = UIImage(named: "placeholder")!
    private var _localIdentifier = ""
    @objc var localIdentifier: String {
        get {
            _localIdentifier
        }
        set(localIdentifier) {
            _localIdentifier = localIdentifier
        }
    }

    private let offset: CGFloat = 1.0
    private let playScale: CGFloat = 0.20

    @IBOutlet weak var cellImage: UIImageView!

    var playImg = UIImageView()
    @IBOutlet weak var playBckg: UIImageView!
    @IBOutlet weak var playBckgWidth: NSLayoutConstraint!
    @IBOutlet weak var playBckgHeight: NSLayoutConstraint!
    
    @IBOutlet weak var uploadInfoLabel: UILabel!
    @IBOutlet weak var uploadingProgress: UIProgressView!
    @IBOutlet weak var imageInfoLabel: UILabel!
    
    // MARK: - Cell Configuration & Update
    func configure(with upload:Upload, availableWidth:Int) {

        // Background color and aspect
        backgroundColor = .piwigoColorCellBackground()
        localIdentifier = upload.localIdentifier

        // Upload info label
        uploadInfoLabel.textColor = .piwigoColorLeftLabel()
        uploadInfoLabel.text = upload.stateLabel
        
        // Uploading progress bar
        switch upload.state {
        case .waiting,
             .preparing, .preparingError, .preparingFail, .formatError, .prepared,
             .uploadingError, .uploadingFail:
            uploadingProgress?.setProgress(0.0, animated: false)
        case .uploaded, .finishing, .finishingError, .finished:
            uploadingProgress?.setProgress(1.0, animated: false)
        default:
            uploadingProgress?.setProgress(1.0, animated: false)
        }

        // Right => Left swipe commands
        swipeBackgroundColor = .piwigoColorCellBackground()
        rightExpansion.buttonIndex = 0
        rightExpansion.threshold = 3.0
        rightExpansion.fillOnTrigger = true
        rightExpansion.expansionColor = .piwigoColorBrown()
        rightSwipeSettings.transition = .border
        switch upload.state {
        case .preparing, .prepared, .uploading, .uploaded, .finishing:
            rightButtons = [];
        case .preparingError, .uploadingError, .finishingError:
            rightButtons = [
                MGSwipeButton(title: "", icon: UIImage(named: "swipeRetry.png"), backgroundColor: .piwigoColorOrange(), callback: { sender in
                    UploadManager.shared.backgroundQueue.async {
                        UploadManager.shared.resume(failedUploads: [upload.objectID], completionHandler: { (_) in
                            UploadManager.shared.findNextImageToUpload()
                        })
                    }
                    return true
                }),
                MGSwipeButton(title: "", icon: UIImage(named: "swipeCancel.png"), backgroundColor: .piwigoColorBrown(), callback: { sender in
                    self.uploadsProvider.delete(uploadRequests: [upload.objectID]) { _ in }
                    return true
                })]
        case .waiting, .deleted:
            rightButtons = [
                MGSwipeButton(title: "", icon: UIImage(named: "swipeCancel.png"), backgroundColor: .piwigoColorBrown(), callback: { sender in
                    self.uploadsProvider.delete(uploadRequests: [upload.objectID]) { _ in }
                    return true
                })]
        case .preparingFail, .formatError, .uploadingFail, .finishingFail,.finished, .moderated:
            rightButtons = [
                MGSwipeButton(title: "", icon: UIImage(named: "swipeTrashSmall.png"), backgroundColor: .red, callback: { sender in
                    self.uploadsProvider.delete(uploadRequests: [upload.objectID]) { _ in }
                    return true
                })]
        }

        // Image info label
        imageInfoLabel.textColor = .piwigoColorRightLabel()
        
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
    
    func update(with userInfo: [AnyHashable : Any]) {
        // Top label
        if let stateLabel: String = userInfo["stateLabel"] as! String? {
            uploadInfoLabel.text = stateLabel
        }

        // Progress bar
        if let progressFraction = userInfo["progressFraction"] as? Float {
            if progressFraction == Float(0.0) {
                uploadingProgress?.setProgress(0.0, animated: true)
            } else {
                let progress = max(uploadingProgress.progress, progressFraction)
                uploadingProgress?.setProgress(progress, animated: true)
            }
        }

        // Bottom label
        if let errorDescription = userInfo["Error"] as? String,
           !errorDescription.isEmpty {
            imageInfoLabel.text = errorDescription
        }
    }
    
    override func prepareForReuse() {
        cellImage.image = imagePlaceholder
        playBckg.isHidden = true
        playImg.isHidden = true
        uploadInfoLabel.text = ""
        uploadingProgress?.setProgress(0, animated: false)
        imageInfoLabel.text = ""
    }


    // MARK: - Thumbnail Preparation
    /// Case of an image from the pasteboard
    private func prepareThumbnailFromFile(for upload:Upload, availableWidth:Int) {
        // Get file URL from identifier
        let fileURL = UploadManager.shared.applicationUploadsDirectory
            .appendingPathComponent(upload.localIdentifier)
        
        // Task depends on file type
        var image: UIImage!
        if fileURL.lastPathComponent.contains("img") {
            // Case of a photo
            playBckg.isHidden = true
            playImg.isHidden = true

            // Retrieve image data from file stored in the Uploads directory
            var fullResImageData: Data = Data()
            do {
                try fullResImageData = NSData (contentsOf: fileURL) as Data
            }
            catch let error as NSError {
                // Could not find the file to upload!
                print(error.localizedDescription)
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                return
            }

            // Retrieve UIImage from imageData
            image = UIImage(data: fullResImageData) ?? imagePlaceholder

            // Fix orientation if needed
            image = image.fixOrientation()
        }
        else if fileURL.lastPathComponent.contains("mov") {
            // Case of a movie
            let asset = AVURLAsset(url: fileURL, options: nil)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            do {
                image = UIImage(cgImage: try imageGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil))
            } catch {
                image = imagePlaceholder
            }
            
            // Add movie icon
            addMovieIcon()
        }
        else {
            // Unknown type
            image = imagePlaceholder
        }

        // Scale/crop image
        cellImage.image = image.crop(width: 1.0, height: 1.0)?.resize(to: 58.0, opaque: true)
        cellImage.layer.cornerRadius = 10 - 3

        // Image available
        if [.preparingError, .preparingFail, .formatError,
            .uploadingError, .uploadingFail, .finishingError].contains(upload.state) {
            // Display error message
            imageInfoLabel.text = errorDescription(for: upload)
        } else {
            // Display image information
            let maxSize = upload.resizeImageOnUpload ? upload.photoMaxSize : Int16.max
            imageInfoLabel.text = getImageInfo(from: image ?? imagePlaceholder,
                                               for: availableWidth - 2*Int(indentationWidth),
                                               maxSize: maxSize)
        }
    }

    /// Case of an image from the Photo Library
    private func prepareThumbnailFromAsset(for upload:Upload, availableWidth:Int) {
        // Get corresponding image asset
        guard let imageAsset = PHAsset.fetchAssets(withLocalIdentifiers: [upload.localIdentifier], options: nil).firstObject else {
            cellImage.image = imagePlaceholder
            imageInfoLabel.text = errorDescription(for: upload)
            uploadingProgress?.setProgress(0.0, animated: false)
            playBckg.isHidden = true
            playImg.isHidden = true
            return
        }
        
        // Image asset available
        if [.preparingError, .preparingFail, .formatError,
            .uploadingError, .uploadingFail, .finishingError].contains(upload.state) {
            // Display error message
            imageInfoLabel.text = errorDescription(for: upload)
        } else {
            // Display image information
            let maxSize = upload.resizeImageOnUpload ? upload.photoMaxSize : Int16.max
            imageInfoLabel.text = getImageInfo(from: imageAsset, for: availableWidth - 2*Int(indentationWidth),
                                               maxSize: maxSize)
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
                    self.cellImage.image = self.imagePlaceholder
                } else {
                    self.cellImage.image = result
                }
                self.cellImage.layer.cornerRadius = 10 - 3
            })
        })
        
        // Video icon
        if imageAsset.mediaType == .video {
            addMovieIcon()
        }
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

    
    // MARK: - Utilities
    private func errorDescription(for upload:Upload) -> String {
        // Display error message
        let error: String?
        if upload.requestError.count > 0 {
            error = upload.requestError
        } else {
            switch upload.state {
            case .preparingError, .preparingFail:
                error = UploadError.missingAsset.localizedDescription
            case .formatError:
                error = UploadError.wrongDataFormat.localizedDescription
            case .uploadingError, .uploadingFail, .finishingError:
                error = JsonError.networkUnavailable.localizedDescription
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
            return String(format: "%.0fx%.0f pixels", pixelWidth, pixelHeight)
        }
        
        // Info depends on table width
        if availableWidth > 414 {
            // i.e. larger than iPhones 6,7 screen width
            return String(format: "%.0fx%.0f pixels - %@", pixelWidth, pixelHeight, DateFormatter.localizedString(from: creationDate, dateStyle: .full, timeStyle: .medium))
        } else if availableWidth > 375 {
            return String(format: "%.0fx%.0f pixels — %@", pixelWidth, pixelHeight, DateFormatter.localizedString(from: creationDate, dateStyle: .long, timeStyle: .short))
        } else {
            return String(format: "%.0fx%.0f pixels — %@", pixelWidth, pixelHeight, DateFormatter.localizedString(from: creationDate, dateStyle: .short, timeStyle: .short))
        }
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
            return String(format: "%.0fx%.0f pixels, %@", pixelWidth, pixelHeight, formattedDuration)
        }

        // Info depends on table width
        if availableWidth > 414 {
            // i.e. larger than iPhones 6,7 screen width
            return String(format: "%.0fx%.0f pixels, %@ - %@", pixelWidth, pixelHeight, formattedDuration, DateFormatter.localizedString(from: creationDate, dateStyle: .full, timeStyle: .medium))
        } else if availableWidth > 375 {
            return String(format: "%.0fx%.0f pixels, %@ - %@", pixelWidth, pixelHeight, formattedDuration, DateFormatter.localizedString(from: creationDate, dateStyle: .long, timeStyle: .short))
        } else {
            return String(format: "%.0fx%.0f pixels, %@ - %@", pixelWidth, pixelHeight, formattedDuration, DateFormatter.localizedString(from: creationDate, dateStyle: .short, timeStyle: .short))
        }
    }
    
    private func addMovieIcon() {
        // Match size to cell size
        let scale: CGFloat = fmax(1.0, self.traitCollection.displayScale);
        let width = cellImage.frame.size.width * playScale + (scale - 1)
        playBckg.setMovieImage(inBackground: true)
        playBckgWidth.constant = width + 2*offset
        playBckgHeight.constant = playBckgWidth.constant * playRatio
        playImg.setMovieImage(inBackground: false)
        playBckg.addSubview(playImg)
        playBckg.addConstraints(NSLayoutConstraint.constraintCenter(playImg)!)
        playBckg.addConstraints(NSLayoutConstraint.constraintView(playImg, to: CGSize(width: width, height: width * playRatio))!)
        playBckg.isHidden = false
        playImg.isHidden = false
    }
}
