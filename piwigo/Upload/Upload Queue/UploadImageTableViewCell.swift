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
    
    // MARK: - Cell Configuration & Update
    func configure(with upload:Upload, availableWidth:Int) {

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
                        UploadManager.shared.resume(failedUploads: [upload.objectID], completionHandler: { (_) in })
                    }
                    return true
                }),
                MGSwipeButton(title: "", icon: UIImage(named: "swipeCancel.png"), backgroundColor: UIColor.piwigoColorBrown(), callback: { sender in
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.uploadsProvider.delete(uploadRequests: [upload.objectID])
                    }
                    return true
                })]
        case .waiting:
            rightButtons = [
                MGSwipeButton(title: "", icon: UIImage(named: "swipeCancel.png"), backgroundColor: UIColor.piwigoColorBrown(), callback: { sender in
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.uploadsProvider.delete(uploadRequests: [upload.objectID])
                    }
                    return true
                })]
        case .preparingFail, .formatError, .finished, .moderated:
            rightButtons = [
                MGSwipeButton(title: "", icon: UIImage(named: "swipeTrashSmall.png"), backgroundColor: UIColor.red, callback: { sender in
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.uploadsProvider.delete(uploadRequests: [upload.objectID])
                    }
                    return true
                })]
        }

        // Image info label
        imageInfoLabel.textColor = UIColor.piwigoColorRightLabel()
        
        // Determine from where the file comes from:
        // => Photo Library: use PHAsset local identifier
        // => UIPasteborad: use identifier of type "Clipboard-yyyyMMdd-HHmmssSSSS-typ-#"
        //    where "typ" is "img" (photo) or "mov" (video).
        if upload.localIdentifier.contains("Clipboard-") {
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
    
    override func prepareForReuse() {
        cellImage.image = UIImage(named: "placeholder")
        playImage.isHidden = true
        uploadInfoLabel.text = ""
        uploadingProgress?.setProgress(0, animated: false)
        imageInfoLabel.text = ""
    }


    // MARK: - Thumbnail Preparation
    /// Case of an image from the pasteboard
    private func prepareThumbnailFromFile(for upload:Upload, availableWidth:Int) {
        // Get file URL from identifier
        var files = [URL]()
        let applicationUploadsDirectory = UploadManager.shared.applicationUploadsDirectory
        do {
            // Get complete filename by searching in the Uploads directory
            files = try FileManager.default.contentsOfDirectory(at: applicationUploadsDirectory,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        }
        catch let error as NSError {
            print(error.localizedDescription)
            files = []
        }
        guard files.count > 0, let fileURL = files.filter({$0.absoluteString.contains(upload.localIdentifier)}).first else {
            // File not available… deleted?
            let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            cellImage.image = UIImage(named: "placeholder")
            imageInfoLabel.text = errorDescription(for: upload)
            uploadingProgress?.setProgress(0.0, animated: false)
            playImage.isHidden = true
            return
        }
        
        // Task depends on file type
        var image: UIImage!
        if fileURL.lastPathComponent.contains("img") {
            // Case of a photo
            playImage.isHidden = true

            // Retrieve image data from file stored in the Uploads directory
            var fullResImageData: Data = Data()
            do {
                try fullResImageData = NSData (contentsOf: fileURL) as Data
            }
            catch let error as NSError {
                // Could not find the file to upload!
                print(error.localizedDescription)
                let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                return
            }

            // Retrieve UIImage from imageData
            image = UIImage(data: fullResImageData) ?? UIImage(named: "placeholder")!

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
                image = UIImage(named: "placeholder")!
            }
        }
        else {
            // Unknown type
            image = UIImage(named: "placeholder")!
        }

        // Scale/crop image
        cellImage.image = image.crop(width: 1.0, height: 1.0)?.resize(to: 58.0, opaque: true)
        cellImage.layer.cornerRadius = 10 - 3

        // Image available?
        if [.preparingError, .preparingFail, .formatError, .uploadingError, .finishingError].contains(upload.state) {
            // Display error message
            imageInfoLabel.text = errorDescription(for: upload)
            if [.preparingError, .preparingFail, .formatError].contains(upload.state) {
                uploadingProgress?.setProgress(0.0, animated: false)
            }
        } else {
            // Display image information
            imageInfoLabel.text = getImageInfo(from: cellImage.image ?? UIImage(named: "placeholder")!, for: availableWidth - 2*Int(indentationWidth), scale: upload.photoResize)
        }
    }

    /// Case of an image from the Photo Library
    private func prepareThumbnailFromAsset(for upload:Upload, availableWidth:Int) {
        // Get corresponding image asset
        guard let imageAsset = PHAsset.fetchAssets(withLocalIdentifiers: [upload.localIdentifier], options: nil).firstObject else {
            cellImage.image = UIImage(named: "placeholder")
            imageInfoLabel.text = errorDescription(for: upload)
            uploadingProgress?.setProgress(0.0, animated: false)
            playImage.isHidden = true
            return
        }
        
        // Image asset available
        if [.preparingError, .preparingFail, .formatError, .uploadingError, .finishingError].contains(upload.state) {
            // Display error message
            imageInfoLabel.text = errorDescription(for: upload)
            if [.preparingError, .preparingFail, .formatError].contains(upload.state) {
                uploadingProgress?.setProgress(0.0, animated: false)
            }
        } else {
            // Display image information
            imageInfoLabel.text = getImageInfo(from: imageAsset, for: availableWidth - 2*Int(indentationWidth), scale: upload.photoResize)
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
    
    private func getImageInfo(from imageAsset: PHAsset, for availableWidth: Int, scale: Int16) -> String {
        let pixelWidth = (Float(imageAsset.pixelWidth * Int(scale)) / 100.0).rounded()
        let pixelHeight = (Float(imageAsset.pixelHeight * Int(scale)) / 100.0).rounded()
        switch imageAsset.mediaType {
        case .image:
            return imageInfo(for: availableWidth, pixelWidth: pixelWidth, pixelHeight: pixelHeight, creationDate: imageAsset.creationDate)
        case .video:
            return videoInfo(for: availableWidth, pixelWidth: pixelWidth, pixelHeight: pixelHeight, duration: imageAsset.duration, creationDate: imageAsset.creationDate)
        default:
            if let creationDate = imageAsset.creationDate {
                return DateFormatter.localizedString(from: creationDate, dateStyle: .full, timeStyle: .none)
            }
        }
        return ""
    }

    private func getImageInfo(from image: UIImage, for availableWidth: Int, scale: Int16) -> String {
        let pixelWidth = (Float(image.size.width * CGFloat(scale)) / 100.0).rounded()
        let pixelHeight = (Float(image.size.height * CGFloat(scale)) / 100.0).rounded()
        return imageInfo(for: availableWidth, pixelWidth: pixelWidth, pixelHeight: pixelHeight, creationDate: Date())
    }

    
    // MARK: - Utilities
    private func errorDescription(for upload:Upload) -> String {
        // Display error message
        let error: String?
        if upload.requestError?.count ?? 0 > 0 {
            error = upload.requestError
        } else {
            switch upload.state {
            case .preparingError, .preparingFail:
                error = UploadError.missingAsset.localizedDescription
            case .formatError:
                error = UploadError.wrongDataFormat.localizedDescription
            case .uploadingError, .finishingError:
                error = UploadError.networkUnavailable.localizedDescription
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
}
