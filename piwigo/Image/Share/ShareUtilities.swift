//
//  ShareUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 07/01/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

class ShareUtilities {
    
    // MARK: - Image Download
    /** Returns:
     - the Piwigo  image size
     - the URL of the image file stored on the Piwigo server
       whose resolution matches the one demaned by the activity type
     **/
    // Returns the size and Piwigo URL of the image of max wantedd size
    static func getOptimumSizeAndURL(_ imageData: Image, ofMaxSize wantedSize: Int) -> (pwgImageSize, URL)? {
        // ATTENTION: Some sizes and/or URLs may not be available!
        // So we go through the whole list of URLs...

        // If this is a video, always select the full resolution file, i.e. the video.
        if imageData.isVideo {
            if let pwgURL = imageData.fullRes?.url {
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
        if NetworkVars.hasSquareSizeImages,
           let imageURL = sizes.square?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Max dimension of this image
            let size = sizes.square?.maxSize ?? 1
            // Ensure that at least an URL will be returned
            pwgSize = .square
            pwgURL = imageURL
            selectedSize = size
        }
        
        // Thumbnail Size (should always be available)
        if NetworkVars.hasThumbSizeImages,
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
        if NetworkVars.hasXXSmallSizeImages,
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
        if NetworkVars.hasXSmallSizeImages,
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
        if NetworkVars.hasSmallSizeImages,
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
        if NetworkVars.hasMediumSizeImages,
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
        if NetworkVars.hasLargeSizeImages,
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
        if NetworkVars.hasXLargeSizeImages,
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
        if NetworkVars.hasXXLargeSizeImages,
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
    
    static private func sizeIsNearest(_ size: Int, current: Int, wanted: Int) -> Bool {
        // Check if the size is smaller and the nearest to the wanted size
        return (size < wanted) && (abs(wanted - size) < abs(wanted - current))
    }
    
    // Returns the URL of the image file stored in /tmp before the share
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
            } else  {
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
    func imageMaxSize() -> Int {
        // Get the maximum image size according to the activity type (infinity if no limit)
        /// - See https://makeawebsitehub.com/social-media-image-sizes-cheat-sheet/
        /// - High resolution for: AirDrop, Copy, Mail, Message, iBooks, Flickr, Print, SaveToCameraRoll
        var maxSize = Int.max
        switch self {
        case .assignToContact:
            maxSize = 1024
        case .postToFacebook:
            maxSize = 1200
        case .postToTencentWeibo:
            maxSize = 640 // 9 images max + 1 video
        case .postToTwitter:
            maxSize = 880 // 4 images max
        case .postToWeibo:
            maxSize = 640 // 9 images max + 1 video
        case pwgActivityTypePostToWhatsApp:
            maxSize = 1920
        case pwgActivityTypePostToSignal:
            maxSize = 1920
        case pwgActivityTypeMessenger:
            maxSize = 1920
        case pwgActivityTypePostInstagram:
            maxSize = 1080
        default:
            maxSize = Int.max
        }
        return maxSize
    }

    func shouldStripMetadata() -> Bool {
        // Return whether the user wants to strip metadata
        /// - The flag are set in Settings / Images / Share Metadata
        switch self {
        case .airDrop:
            if !ImageVars.shared.shareMetadataTypeAirDrop {
                return true
            }
        case .assignToContact:
            if !ImageVars.shared.shareMetadataTypeAssignToContact {
                return true
            }
        case .copyToPasteboard:
            if !ImageVars.shared.shareMetadataTypeCopyToPasteboard {
                return true
            }
        case .mail:
            if !ImageVars.shared.shareMetadataTypeMail {
                return true
            }
        case .message:
            if !ImageVars.shared.shareMetadataTypeMessage {
                return true
            }
        case .postToFacebook:
            if !ImageVars.shared.shareMetadataTypePostToFacebook {
                return true
            }
        case pwgActivityTypeMessenger:
            if !ImageVars.shared.shareMetadataTypeMessenger {
                return true
            }
        case .postToFlickr:
            if !ImageVars.shared.shareMetadataTypePostToFlickr {
                return true
            }
        case pwgActivityTypePostInstagram:
            if !ImageVars.shared.shareMetadataTypePostInstagram {
                return true
            }
        case pwgActivityTypePostToSignal:
            if !ImageVars.shared.shareMetadataTypePostToSignal {
                return true
            }
        case pwgActivityTypePostToSnapchat:
            if !ImageVars.shared.shareMetadataTypePostToSnapchat {
                return true
            }
        case .postToTencentWeibo:
            if !ImageVars.shared.shareMetadataTypePostToTencentWeibo {
                return true
            }
        case .postToTwitter:
            if !ImageVars.shared.shareMetadataTypePostToTwitter {
                return true
            }
        case .postToVimeo:
            if !ImageVars.shared.shareMetadataTypePostToVimeo {
                return true
            }
        case .postToWeibo:
            if !ImageVars.shared.shareMetadataTypePostToWeibo {
                return true
            }
        case pwgActivityTypePostToWhatsApp:
            if !ImageVars.shared.shareMetadataTypePostToWhatsApp {
                return true
            }
        case .saveToCameraRoll:
            if !ImageVars.shared.shareMetadataTypeSaveToCameraRoll {
                return true
            }
        default:
            if !ImageVars.shared.shareMetadataTypeOther {
                return true
            }
        }
        return false
    }
}
