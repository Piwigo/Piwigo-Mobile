//
//  ShareUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 07/01/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit
import PwgCacheKit

final class ShareUtilities {

    // MARK: - Clipboard Expiration
    /// Applies the delay chosen in Settings ▶ Privacy ▶ Clear Clipboard
    /// to the items placed in the pasteboard by the Copy activity.
    static func setClipboardExpiration(forActivityType activityType: UIActivity.ActivityType?) {
        let delay = pwgClearClipboard(rawValue: AppVars.shared.clearClipboardDelay)?.seconds ?? 0.0
        guard delay > 0, activityType == .copyToPasteboard else { return }
        let items = UIPasteboard.general.items
        let expirationDate = NSDate(timeIntervalSinceNow: delay)
        let options: [UIPasteboard.OptionsKey : Any] = [.expirationDate : expirationDate]
        UIPasteboard.general.setItems(items, options: options)
    }


    // MARK: - Image Download
    /** Returns:
     - the Piwigo image size
     - the URL of the image file stored on the Piwigo server
       whose resolution matches the one demaned by the activity type
     **/
    // Returns the size and Piwigo URL of the image of max wantedd size
    static func getOptimumSizeAndURL(_ imageData: Image, ofMaxSize wantedSize: Int) -> (pwgImageSize, URL)? {
        // ATTENTION: Some sizes and/or URLs may not be available!
        // So we go through the whole list of URLs...

        // If this is a video, a GIF, an EPS or a PDF file, always select the full resolution file.
        if imageData.hasFullResThumbnail == false {
            if let pwgURL = imageData.downloadUrl {
                return (.fullRes, pwgURL as URL)
            } else {
                return nil
            }
        }
        
        // Download image of optimum size (depends on Piwigo server settings)
        /// - Check available image sizes from the smallest to the highest resolution
        /// - Note: image.width and .height are always > 1
        let sizes = imageData.sizes
        var selectedSize = Int.zero
        var pwgSize: pwgImageSize = .square, pwgURL: NSURL?

        // Square Size (should always be available)
        if pwgImageSize.square.isAvailable,
           let imageURL = sizes.square?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Max dimension of this image
            let size = sizes.square?.maxSize ?? 1
            // Ensure that at least an URL will be returned
            pwgSize = .square
            pwgURL = imageURL
            selectedSize = size
        }
        
        // Thumbnail Size (should always be available)
        if pwgImageSize.thumb.isAvailable,
           let imageURL = sizes.thumb?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Max dimension of this image
            let size = sizes.thumb?.maxSize ?? 1
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) || sizeIsNearest(size, current: selectedSize, wanted: wantedSize) {
                pwgSize = .thumb
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // XX Small Size
        if pwgImageSize.xxSmall.isAvailable,
           let imageURL = sizes.xxsmall?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Max dimension of this image
            let size = sizes.xxsmall?.maxSize ?? 1
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) || sizeIsNearest(size, current: selectedSize, wanted: wantedSize) {
                pwgSize = .xxSmall
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // X Small Size
        if pwgImageSize.xSmall.isAvailable,
           let imageURL = sizes.xsmall?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Max dimension of this image
            let size = sizes.xsmall?.maxSize ?? 1
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) || sizeIsNearest(size, current: selectedSize, wanted: wantedSize) {
                pwgSize = .xSmall
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // Small Size
        if pwgImageSize.small.isAvailable,
           let imageURL = sizes.small?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Max dimension of this image
            let size = sizes.small?.maxSize ?? 1
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) || sizeIsNearest(size, current: selectedSize, wanted: wantedSize) {
                pwgSize = .small
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // Medium Size (should always be available)
        if pwgImageSize.medium.isAvailable,
           let imageURL = sizes.medium?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Max dimension of this image
            let size = sizes.medium?.maxSize ?? 1
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) || sizeIsNearest(size, current: selectedSize, wanted: wantedSize) {
                pwgSize = .medium
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // Large Size
        if pwgImageSize.large.isAvailable,
           let imageURL = sizes.large?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Max dimension of this image
            let size = sizes.large?.maxSize ?? 1
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) || sizeIsNearest(size, current: selectedSize, wanted: wantedSize) {
                pwgSize = .large
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // X Large Size
        if pwgImageSize.xLarge.isAvailable,
           let imageURL = sizes.xlarge?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Max dimension of this image
            let size = sizes.xlarge?.maxSize ?? 1
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) || sizeIsNearest(size, current: selectedSize, wanted: wantedSize) {
                pwgSize = .xLarge
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // XX Large Size
        if pwgImageSize.xxLarge.isAvailable,
           let imageURL = sizes.xxlarge?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Max dimension of this image
            let size = sizes.xxlarge?.maxSize ?? 1
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) || sizeIsNearest(size, current: selectedSize, wanted: wantedSize) {
                pwgSize = .xxLarge
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // XXX Large Size
        if pwgImageSize.xxxLarge.isAvailable,
           let imageURL = sizes.xxxlarge?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Max dimension of this image
            let size = sizes.xxxlarge?.maxSize ?? 1
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) || sizeIsNearest(size, current: selectedSize, wanted: wantedSize) {
                pwgSize = .xxxLarge
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // XXXX Large Size
        if pwgImageSize.xxxxLarge.isAvailable,
           let imageURL = sizes.xxxxlarge?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Max dimension of this image
            let size = sizes.xxxxlarge?.maxSize ?? 1
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) || sizeIsNearest(size, current: selectedSize, wanted: wantedSize) {
                pwgSize = .xxxxLarge
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // Full Resolution
        if let imageURL = imageData.fullRes?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Max dimension of this image
            let size = imageData.fullRes?.maxSize ?? 1
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) || sizeIsNearest(size, current: selectedSize, wanted: wantedSize) {
                pwgSize = .fullRes
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // NOP if no image can be downloaded
        guard let pwgURL = pwgURL else {
            return nil
        }
        return (pwgSize, pwgURL as URL)
    }
    
    // Check if the size is smaller and the nearest to the wanted size
    static private func sizeIsNearest(_ size: Int, current: Int, wanted: Int) -> Bool {
        return (size < wanted) && (abs(wanted - size) < abs(wanted - current))
    }
    
    // Returns the URL of the image/video/PDF file stored in /tmp before sharing
    static func getFileUrl(ofImage image: Image?, withURL imageUrl: URL?) -> URL {
        // Get filename from image data or URL request
        var fileName = imageUrl?.lastPathComponent
        if let name = image?.fileName, !name.isEmpty {
            fileName = name
        }
        
        // Is filename of original image a PHP request?
        if fileName?.contains(".php") ?? false {
            // The URL does not contain a file name but a PHP request
            // Sometimes happening with full resolution images, try with medium resolution file
            fileName = image?.sizes.medium?.url?.lastPathComponent
            
            // Is filename of medium size image still a PHP request?
            if fileName?.contains(".php") ?? false {
                // The URL does not contain a unique file name but a PHP request
                // Try using the filename stored in Piwigo image data
                if image?.fileName.isEmpty == false {
                    // Use the image file name returned by Piwigo
                    fileName = image?.fileName
                } else {
                    // Try to build filename from creation date
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
                    if let creationDate = image?.dateCreated {
                        fileName = dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: creationDate))
                    } else if let postedDate = image?.datePosted {
                        fileName = dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: postedDate))
                    } else {
                        fileName = dateFormatter.string(from: Date())
                    }
                }
            }
        }
        
        // Check that the filename has an extension
        if URL(string: fileName!)?.pathExtension.count == 0 {
            // And append guessed extension
            if image?.isVideo ?? false {
                // Videos are generally exported in MP4 format
                fileName = fileName?.appending(".mp4")
            }
            else if image?.isPDF ?? false {
                fileName = fileName?.appending(".pdf")
            }
            else if image?.isEPS ?? false {
                fileName = fileName?.appending(".eps")
            }
            else if image?.isGIF ?? false {
                fileName = fileName?.appending(".gif")
            }
            else {
                // Adopt JPEG photo format by default, will be rechecked
                fileName = fileName?.appending(".jpg")
            }
        }
        
        // Shared files are saved in the /tmp directory and will be deleted:
        // - by the app if the user kills it
        // - by the system after a certain amount of time
        let tempDirectoryUrl = URL(fileURLWithPath: NSTemporaryDirectory())
        return tempDirectoryUrl.appendingPathComponent(fileName ?? "PiwigoImage.jpg")
    }
}


// MARK: - UIActivityType Extensions
extension UIActivity.ActivityType
{    
    // Return the maximum resolution accepted for some activity types
    /// - This limit is a floor applied inside the "Optimised" size option only.
    ///   Images shared in their "Original" size are never downsized, whatever the destination.
    /// - AirDrop, Mail, Message, Print and the other activities have no limit:
    ///   they either handle large files well or propose their own resizing options.
    func maxSizeWhenOptimised() -> Int {
        switch self {
        case .assignToContact:
            // A contact card never displays more than a portrait thumbnail
            return 1024
        case .copyToPasteboard:
            // The pasteboard keeps items in memory and uploads them to iCloud
            // when Universal Clipboard is enabled
            return 1920
        default:
            return Int.max
        }
    }

    func shouldStripMetadata() -> Bool {
        // Return whether the user wants to strip metadata
        /// - The flags are set in Settings / Privacy / Share Metadata
        /// - Only the activity types which iOS still proposes are listed:
        ///   the built-in social ones (Facebook, Twitter, Flickr, Vimeo, Weibo, Tencent Weibo)
        ///   have not been vended since iOS 11 removed the system social accounts,
        ///   and the apps which replaced them are handled by the default case.
        switch self {
        case .airDrop:
            return !ImageVars.shared.shareMetadataTypeAirDrop
        case .assignToContact:
            return !ImageVars.shared.shareMetadataTypeAssignToContact
        case .copyToPasteboard:
            return !ImageVars.shared.shareMetadataTypeCopyToPasteboard
        case .mail:
            return !ImageVars.shared.shareMetadataTypeMail
        case .message:
            return !ImageVars.shared.shareMetadataTypeMessage
        case .saveToCameraRoll:
            return !ImageVars.shared.shareMetadataTypeSaveToCameraRoll
        case .print:
            // Printers discard metadata: stripping it would only cost time and quality
            return false
        default:
            return !ImageVars.shared.shareMetadataTypeOther
        }
    }
}
