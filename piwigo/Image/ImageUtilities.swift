//
//  ImageUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/07/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import ImageIO
import MobileCoreServices
import UIKit
import PwgKit
import PwgCacheKit

struct ImageUtilities
{
    // MARK: - Image Downsampling
    // Downsampling large images for display at smaller size
    /// WWDC 2018 - Session 219 - Image and Graphics Best practices
    static func optimumSize(ofImage image: UIImage, forPointSize pointSize: CGSize) -> CGSize? {
        // Check sizes
        if image.size.width < 1 || image.size.height < 1 { return nil }
        if pointSize.width < 1 || pointSize.height < 1 { return nil }
        
        // Return reduced size or nil if no downsampling should be performed
        return reducedSize(from: image.size, to: pointSize)
    }
    
    static func reducedSize(from originalSize: CGSize, to pointSize: CGSize) -> CGSize? {
        // Wanted size too small?
        if pointSize.width < 1 || pointSize.height < 1 { return nil }
        
        // Image smaller than pointSize?
        let scaleWidth = originalSize.width / pointSize.width
        let scaleHeight = originalSize.height / pointSize.height
        let scale = min(scaleWidth, scaleHeight)
        if scale <= 1.0 { return nil }
        
        // Image size larger than pointSize
        return CGSizeMake(originalSize.width / scale, originalSize.height / scale)
    }
    
    static func downsample(imageAt imageURL: URL, to pointSize: CGSize, for type: pwgImageType) -> UIImage {
        // Optimised image available?
        let filePath = imageURL.path + optimisedImageNameExtension
        if let optImage = UIImage(contentsOfFile: filePath) {
            // Images created since commit 18e4273 can be too small (v3.2.2) — fixed in v3.2.3.
            let fileURL: URL?
            if #available(iOS 16.0, *) {
                fileURL = URL(filePath: filePath, directoryHint: .notDirectory)
            } else {
                // Fallback on earlier versions
                fileURL = URL(fileURLWithPath: filePath)
            }
            if let fileCreationDate = fileURL?.creationDate,
               (fileCreationDate < ImageVars.shared.dateCommit18e4273 || fileCreationDate > ImageVars.shared.dateOfFirstOptImageV323) {
                // Decode the image now so that UIKit does not decode it at render time
                return optImage.preparingForDisplay() ?? optImage
            }
        }
        
        // Create an image source without loading the image in memory
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, sourceOptions),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, sourceOptions) as? [CFString: Any],
              let pixelWidth = properties[kCGImagePropertyPixelWidth] as? Double,
              let pixelHeight = properties[kCGImagePropertyPixelHeight] as? Double
        else {
            // Delete corrupted cached image file if any
            try? FileManager.default.removeItem(at: imageURL)
            return type.placeHolder
        }

        // Take the EXIF orientation into account (values 5…8 swap width and height)
        var imageSize = CGSize(width: pixelWidth, height: pixelHeight)
        if let orientation = properties[kCGImagePropertyOrientation] as? UInt32,
           (5...8).contains(orientation) {
            imageSize = CGSize(width: pixelHeight, height: pixelWidth)
        }

        // Determine the maximum dimension of the downsampled image
        var shouldBeSavedInCache = false
        let maxPixelSize: CGFloat
        if let optSize = reducedSize(from: imageSize, to: pointSize) {
            maxPixelSize = max(optSize.width, optSize.height).rounded(.up)
            shouldBeSavedInCache = true
        } else {
            // Image size smaller than pointSize ► No downsampling
            maxPixelSize = max(imageSize.width, imageSize.height)
        }

        // Downsample and decode the image in a single pass,
        // without materialising the full-size image in memory
        let downsampleOptions = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                 kCGImageSourceShouldCacheImmediately: true,
                                 kCGImageSourceCreateThumbnailWithTransform: true,
                                 kCGImageSourceThumbnailMaxPixelSize: maxPixelSize] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions)
        else {
            // Delete corrupted cached image file if any
            try? FileManager.default.removeItem(at: imageURL)
            return type.placeHolder
        }
        let downsampledImage = UIImage(cgImage: cgImage)

        // Save the downsampled image in cache if it does not belong to the app,
        // without delaying the display of the image (only benefits future displays)
        if shouldBeSavedInCache, [.album, .image].contains(type) {
            DispatchQueue.global(qos: .utility).async {
                downsampledImage.saveInOptimumFormat(atPath: filePath)
            }
        }
        return downsampledImage
    }
    
    static func downsample(image: UIImage, to pointSize: CGSize) -> UIImage {
        autoreleasepool {
            // Downsample image if needed
            if let optSize = optimumSize(ofImage: image, forPointSize: pointSize),
               let downsampledImage = image.preparingThumbnail(of: optSize) {
                return downsampledImage
            }
            
            // Return original image
            return image
        }
    }
    
    
    // MARK: - Image Size for Device
    @MainActor static
    func optimumImageSizeForDevice() -> pwgImageSize {
        // Determine the resolution of the screen
        // See https://iosref.com/res
        // See https://www.apple.com/iphone/compare/ and https://www.apple.com/ipad/compare/
        let screenSize = UIScreen.main.bounds.size
        let screenWidth = fmin(screenSize.width, screenSize.height) * pwgImageSize.maxZoomScale
        let scale = AppVars.shared.currentDeviceScale

        switch screenWidth {
        case 0...pwgImageSize.square.minPoints(forScale: scale):
            return .square
        case pwgImageSize.square.minPoints(forScale: scale)+1...pwgImageSize.thumb.minPoints(forScale: scale):
            return .thumb
        case pwgImageSize.thumb.minPoints(forScale: scale)+1...pwgImageSize.xxSmall.minPoints(forScale: scale):
            return .xxSmall
        case pwgImageSize.xxSmall.minPoints(forScale: scale)+1...pwgImageSize.xSmall.minPoints(forScale: scale):
            return .xSmall
        case pwgImageSize.xSmall.minPoints(forScale: scale)+1...pwgImageSize.small.minPoints(forScale: scale):
            return .small
        case pwgImageSize.small.minPoints(forScale: scale)+1...pwgImageSize.medium.minPoints(forScale: scale):
            return .medium
        case pwgImageSize.medium.minPoints(forScale: scale)+1...pwgImageSize.large.minPoints(forScale: scale):
            return .large
        case pwgImageSize.large.minPoints(forScale: scale)+1...pwgImageSize.xLarge.minPoints(forScale: scale):
            return .xLarge
        case pwgImageSize.xLarge.minPoints(forScale: scale)+1...pwgImageSize.xxLarge.minPoints(forScale: scale):
            return .xxLarge
        case pwgImageSize.xxLarge.minPoints(forScale: scale)+1...pwgImageSize.xxxLarge.minPoints(forScale: scale):
            return .xxxLarge
        case pwgImageSize.xxxLarge.minPoints(forScale: scale)+1...pwgImageSize.xxxxLarge.minPoints(forScale: scale):
            return .xxxxLarge
        default:
            return .fullRes
        }
    }
}
