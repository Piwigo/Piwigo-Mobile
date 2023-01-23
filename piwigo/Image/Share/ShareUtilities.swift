//
//  ShareUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 07/01/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

class ShareUtilities {
    
    // MARK: - Image Download
    /** Returns:
     - the URL of the image file stored on the Piwigo server
     whose resolution matches the one expected by the activity type
     - the URL of that image stored in cache.
     **/
    // Returns the size and Piwigo URL of the image of max wantedd size
    class func getOptimumSizeAndURL(_ imageData: Image, ofMaxSize wantedSize: Int) -> (pwgImageSize, NSURL)? {
        // ATTENTION: Some sizes and/or URLs may not be available!
        // So we go through the whole list of URLs...
        var pwgSize: pwgImageSize?, pwgURL: NSURL?
        
        // If this is a video, always select the full resolution file, i.e. the video.
        if imageData.isVideo {
            // NOP if no image can be downloaded
            pwgURL = imageData.fullRes?.url
            pwgSize = .fullRes
            guard let pwgSize = pwgSize, let pwgURL = pwgURL else {
                return nil
            }
            return (pwgSize, pwgURL)
        }
        
        // Download image of optimum size (depends on Piwigo server settings)
        /// - Check available image sizes from the smallest to the highest resolution
        /// - Note: image.width and .height are always > 1
        var selectedSize = Int.zero
        
        // Square Size (should always be available)
        if AlbumVars.shared.hasSquareSizeImages,
           let imageURL = imageData.squareRes?.url {
            // Max dimension of this image
            let size = max(imageData.squareRes?.width ?? 1, imageData.squareRes?.height ?? 1)
            // Ensure that at least an URL will be returned
            if pwgURL == nil {
                pwgSize = .square
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // Thumbnail Size (should always be available)
        if AlbumVars.shared.hasThumbSizeImages,
           let imageURL = imageData.thumbRes?.url {
            // Max dimension of this image
            let size = max(imageData.thumbRes?.width ?? 1, imageData.thumbRes?.height ?? 1)
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) ||
                ((size < wantedSize) && (abs(wantedSize - size) < abs(wantedSize - selectedSize))) {
                pwgSize = .thumb
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // XX Small Size
        if AlbumVars.shared.hasXXSmallSizeImages,
           let imageURL = imageData.xxsmallRes?.url {
            // Max dimension of this image
            let size = max(imageData.xxsmallRes?.width ?? 1, imageData.xxsmallRes?.height ?? 1)
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) ||
                ((size < wantedSize) && (abs(wantedSize - size) < abs(wantedSize - selectedSize))) {
                pwgSize = .xxSmall
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // X Small Size
        if AlbumVars.shared.hasXSmallSizeImages,
           let imageURL = imageData.xsmallRes?.url {
            // Max dimension of this image
            let size = max(imageData.xsmallRes?.width ?? 1, imageData.xsmallRes?.height ?? 1)
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) ||
                ((size < wantedSize) && (abs(wantedSize - size) < abs(wantedSize - selectedSize))) {
                pwgSize = .xSmall
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // Small Size
        if AlbumVars.shared.hasSmallSizeImages,
           let imageURL = imageData.smallRes?.url {
            // Max dimension of this image
            let size = max(imageData.smallRes?.width ?? 1, imageData.smallRes?.height ?? 1)
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) ||
                ((size < wantedSize) && (abs(wantedSize - size) < abs(wantedSize - selectedSize))) {
                pwgSize = .small
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // Medium Size (should always be available)
        if AlbumVars.shared.hasMediumSizeImages,
           let imageURL = imageData.mediumRes?.url {
            // Max dimension of this image
            let size = max(imageData.mediumRes?.width ?? 1, imageData.mediumRes?.height ?? 1)
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) ||
                ((size < wantedSize) && (abs(wantedSize - size) < abs(wantedSize - selectedSize))) {
                pwgSize = .medium
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // Large Size
        if AlbumVars.shared.hasLargeSizeImages,
           let imageURL = imageData.largeRes?.url {
            // Max dimension of this image
            let size = max(imageData.largeRes?.width ?? 1, imageData.largeRes?.height ?? 1)
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) ||
                ((size < wantedSize) && (abs(wantedSize - size) < abs(wantedSize - selectedSize))) {
                pwgSize = .large
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // X Large Size
        if AlbumVars.shared.hasXLargeSizeImages,
           let imageURL = imageData.xlargeRes?.url {
            // Max dimension of this image
            let size = max(imageData.xlargeRes?.width ?? 1, imageData.xlargeRes?.height ?? 1)
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) ||
                ((size < wantedSize) && (abs(wantedSize - size) < abs(wantedSize - selectedSize))) {
                pwgSize = .xLarge
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // XX Large Size
        if AlbumVars.shared.hasXXLargeSizeImages,
           let imageURL = imageData.xxlargeRes?.url {
            // Max dimension of this image
            let size = max(imageData.xxlargeRes?.width ?? 1, imageData.xxlargeRes?.height ?? 1)
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) ||
                ((size < wantedSize) && (abs(wantedSize - size) < abs(wantedSize - selectedSize))) {
                pwgSize = .xxLarge
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // Full Resolution
        if let imageURL = imageData.fullRes?.url {
            // Max dimension of this image
            let size = max(imageData.fullRes?.width ?? 1, imageData.fullRes?.height ?? 1)
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) ||
                ((size < wantedSize) && (abs(wantedSize - size) < abs(wantedSize - selectedSize))) {
                pwgSize = .fullRes
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // NOP if no image can be downloaded
        guard let pwgSize = pwgSize, let pwgURL = pwgURL else {
            return nil
        }
        return (pwgSize, pwgURL)
    }
    
    // Returns the URL of the image file stored in /tmp before the share
    class func getFileUrl(ofImage image: Image?, withURL imageUrl: URL?) -> URL {
        // Get filename from image data or URL request
        var fileName = imageUrl?.lastPathComponent
        if let name = image?.fileName, !name.isEmpty {
            fileName = name
        }
        
        // Is filename of original image a PHP request?
        if fileName?.contains(".php") ?? false {
            // The URL does not contain a file name but a PHP request
            // Sometimes happening with full resolution images, try with medium resolution file
            fileName = image?.mediumRes?.url?.lastPathComponent
            
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
                        fileName = dateFormatter.string(from: creationDate)
                    } else if let postedDate = image?.datePosted {
                        fileName = dateFormatter.string(from: postedDate)
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
        
        // Shared files are saved in the /temp directory and will be deleted:
        // - by the app if the user kills it
        // - by the system after a certain amount of time
        let tempDirectoryUrl = URL(fileURLWithPath: NSTemporaryDirectory())
        return tempDirectoryUrl.appendingPathComponent(fileName ?? "PiwigoImage.jpg")
    }
}


// MARK: - UIActivityType Extensions
extension UIActivity.ActivityType: Comparable {
    
    // Allows to compare and sort activity types
    public static func < (lhs: UIActivity.ActivityType, rhs: UIActivity.ActivityType) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // Return the maximum resolution accepted for some activity types
    func imageMaxSize() -> Int {
        // Get the maximum image size according to the activity type (infinity if no limit)
        /// - See https://makeawebsitehub.com/social-media-image-sizes-cheat-sheet/
        /// - High resolution for: AirDrop, Copy, Mail, Message, iBooks, Flickr, Print, SaveToCameraRoll
        var maxSize = Int.max
        if #available(iOS 10, *) {
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
            case kPiwigoActivityTypePostToWhatsApp:
                maxSize = 1920
            case kPiwigoActivityTypePostToSignal:
                maxSize = 1920
            case kPiwigoActivityTypeMessenger:
                maxSize = 1920
            case kPiwigoActivityTypePostInstagram:
                maxSize = 1080
            default:
                maxSize = Int.max
            }
        }
        return maxSize
    }

    func shouldStripMetadata() -> Bool {
        // Return whether the user wants to strip metadata
        /// - The flag are set in Settings / Images / Share Metadata
        if #available(iOS 10, *) {
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
            case kPiwigoActivityTypeMessenger:
                if !ImageVars.shared.shareMetadataTypeMessenger {
                    return true
                }
            case .postToFlickr:
                if !ImageVars.shared.shareMetadataTypePostToFlickr {
                    return true
                }
            case kPiwigoActivityTypePostInstagram:
                if !ImageVars.shared.shareMetadataTypePostInstagram {
                    return true
                }
            case kPiwigoActivityTypePostToSignal:
                if !ImageVars.shared.shareMetadataTypePostToSignal {
                    return true
                }
            case kPiwigoActivityTypePostToSnapchat:
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
            case kPiwigoActivityTypePostToWhatsApp:
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
        } else {
            // Single On/Off share metadata option (use first boolean)
            if !ImageVars.shared.shareMetadataTypeAirDrop {
                return true
            }
        }
        return false
    }
}
