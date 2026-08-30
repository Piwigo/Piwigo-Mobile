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
import PwgUploadKit


// MARK: - Share Options
/// Options presented to the user before the share sheet appears.
/// They cannot be chosen afterwards: the type of the item handed to
/// UIActivityViewController decides which activities it proposes.
enum pwgShareFormat: Int16, CaseIterable {
    case original = 0       // Share the file as it is stored on the server
    case mostCompatible     // JPEG for HEIC photos, MP4 for videos
}

enum pwgShareSize: Int16, CaseIterable {
    case original = 0       // Full resolution
    case optimised          // Nearest smaller size available on the server
}

struct ShareOptions {
    /// Photos and videos larger than Full HD are shared with the nearest smaller size
    /// available on the server. Smaller ones are left untouched: they cost little to
    /// transfer and downsizing them would only degrade them for no gain.
    static let optimisedMaxSize = 1920

    /// Videos are optimised to HD instead of Full HD: at equal dimensions a video file
    /// weighs far more than a photo, and HD is enough for what is shared from a phone.
    static let optimisedMaxSizeForVideos = 1280

    /// Smallest gain, on either dimension, making the optimised size worth proposing.
    static let optimisedSizeMinGain = 0.10

    var format: pwgShareFormat
    var size: pwgShareSize
    var keepsLocation: Bool
    var keepsContactInfo: Bool

    /// Which groups of private metadata must be removed from the shared file.
    /// - Camera and lens serial numbers identify the photographer as surely as their name,
    ///   so they go whenever the file has to be rewritten anyway. When the user keeps
    ///   everything, the file is shared untouched — no rewrite, hence no recompression.
    var metadataToStrip: PrivateMetadata {
        var toStrip = PrivateMetadata()
        if keepsLocation == false    { toStrip.insert(.location) }
        if keepsContactInfo == false { toStrip.insert(.contact) }
        if toStrip.isEmpty == false  { toStrip.insert(.device) }
        return toStrip
    }

    /// Maximum resolution of the shared file for the given activity.
    /// - The per-activity limits are a floor applied inside the "Optimised" option only:
    ///   an image shared in its "Original" size is never downsized, whatever the destination.
    func maxSize(for activityType: UIActivity.ActivityType?, isVideo: Bool = false) -> Int {
        switch size {
        case .original:
            return Int.max
        case .optimised:
            let optimisedMaxSize = isVideo ? Self.optimisedMaxSizeForVideos : Self.optimisedMaxSize
            return min(optimisedMaxSize, activityType?.maxSizeWhenOptimised() ?? Int.max)
        }
    }

    // Last options chosen by the user
    static var lastUsed: ShareOptions {
        get {
            return ShareOptions(format: pwgShareFormat(rawValue: ImageVars.shared.shareFormat) ?? .original,
                                size: pwgShareSize(rawValue: ImageVars.shared.shareSize) ?? .original,
                                keepsLocation: ImageVars.shared.shareKeepsLocation,
                                keepsContactInfo: ImageVars.shared.shareKeepsContactInfo)
        }
        set(options) {
            ImageVars.shared.shareFormat = options.format.rawValue
            ImageVars.shared.shareSize = options.size.rawValue
            ImageVars.shared.shareKeepsLocation = options.keepsLocation
            ImageVars.shared.shareKeepsContactInfo = options.keepsContactInfo
        }
    }
}

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


    // MARK: - Share Options
    /// Returns which sections the Options view should propose for the given selection.
    /// - PDF, EPS and GIF files are always shared as they are: they have no derivative
    ///   the app could pick, and re-encoding them would destroy them.
    /// - The Format section is only proposed when it can change something,
    ///   i.e. for videos and for photos whose original file is a HEIC one
    ///   (server-generated derivatives are always JPEG files).
    static func optionsToPropose(for images: [Image]) -> (format: Bool, metadata: Bool, size: Bool) {
        let shareable = images.filter({ $0.hasFullResThumbnail || $0.isVideo })
        guard shareable.isEmpty == false else { return (false, false, false) }

        let hasVideo = shareable.contains(where: { $0.isVideo })
        let hasHEIC = shareable.contains(where: {
            ["heic", "heif"].contains(URL(fileURLWithPath: $0.fileName).pathExtension.lowercased())
        })
        return (format: hasVideo || hasHEIC, metadata: true, size: true)
    }

    /// Returns the resolution of the largest file of the selection, and the resolution
    /// which would be shared if the user picked the optimised size, so that the Options
    /// view can label both rows with the dimensions the user will actually get.
    /// - Photos are shared with one of the derivatives generated by the server,
    ///   so the optimised resolution is the one of the derivative which would be picked.
    /// - Videos have no derivative: they are re-encoded by the export session, which
    ///   downscales them to HD but never scales them up.
    static func resolutions(of images: [Image]) -> (original: CGSize?, optimised: CGSize?) {
        var original: CGSize?, optimised: CGSize?
        for image in images where image.hasFullResThumbnail || image.isVideo {
            // Resolution of the file stored on the server
            var originalSize: CGSize?
            if let fullRes = image.fullRes ?? image.sizes.xxxxlarge {
                originalSize = CGSize(width: fullRes.width, height: fullRes.height)
            }
            if let originalSize = originalSize,
               originalSize.maxSide > (original?.maxSide ?? 0) {
                original = originalSize
            }

            // Resolution which would be shared if the user picked the optimised size
            var optimisedSize: CGSize?
            if image.isVideo {
                optimisedSize = originalSize?.scaledDown(toMaxSide: ShareOptions.optimisedMaxSizeForVideos)
            }
            else if let (size, _) = getOptimumSizeAndURL(image, ofMaxSize: ShareOptions.optimisedMaxSize),
                    let resolution = image.resolution(ofSize: size) {
                optimisedSize = CGSize(width: resolution.width, height: resolution.height)
            }
            if let optimisedSize = optimisedSize,
               optimisedSize.maxSide > (optimised?.maxSide ?? 0) {
                optimised = optimisedSize
            }
        }
        return (original, optimised)
    }

    /// Whether the optimised size is worth proposing, i.e. whether the user would gain
    /// anything by choosing it. Servers whose largest derivative is already small enough
    /// return the very resolution of the original file, and videos smaller than HD are
    /// not downscaled either, which makes the choice pointless in both cases.
    static func isOptimisedSizeWorthProposing(original: CGSize?, optimised: CGSize?) -> Bool {
        guard let original = original, let optimised = optimised,
              original.width > 1, original.height > 1
        else { return false }

        // Propose the choice as soon as one of the dimensions is noticeably smaller
        let widthRatio  = optimised.width  / original.width
        let heightRatio = optimised.height / original.height
        return min(widthRatio, heightRatio) < (1.0 - ShareOptions.optimisedSizeMinGain)
    }

    /// Returns "4032 × 3024" for the given resolution, or an empty string when unknown.
    static func dimensions(of size: CGSize?) -> String {
        guard let size = size, size.width > 1, size.height > 1
        else { return "" }
        return String(format: "%d × %d", Int(size.width), Int(size.height))
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


// MARK: - CGSize Extensions
fileprivate extension CGSize {
    var maxSide: CGFloat {
        return max(width, height)
    }

    // Return the size whose largest side fits the given one, keeping the aspect ratio.
    // Sizes which already fit are returned unchanged: files are never scaled up.
    func scaledDown(toMaxSide maxSide: Int) -> CGSize {
        guard self.maxSide > CGFloat(maxSide) else { return self }
        let ratio = CGFloat(maxSide) / self.maxSide
        return CGSize(width: (width * ratio).rounded(), height: (height * ratio).rounded())
    }
}


// MARK: - Image Extensions
extension Image
{
    // Return the resolution of the derivative of the given size
    func resolution(ofSize size: pwgImageSize) -> Resolution? {
        switch size {
        case .square:       return sizes.square
        case .thumb:        return sizes.thumb
        case .xxSmall:      return sizes.xxsmall
        case .xSmall:       return sizes.xsmall
        case .small:        return sizes.small
        case .medium:       return sizes.medium
        case .large:        return sizes.large
        case .xLarge:       return sizes.xlarge
        case .xxLarge:      return sizes.xxlarge
        case .xxxLarge:     return sizes.xxxlarge
        case .xxxxLarge:    return sizes.xxxxlarge
        case .fullRes:      return fullRes
        }
    }

    // Whether the original file needs to be converted to share it in the most compatible format
    var needsConversionToJPEG: Bool {
        return ["heic", "heif"].contains(URL(fileURLWithPath: fileName).pathExtension.lowercased())
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

}
