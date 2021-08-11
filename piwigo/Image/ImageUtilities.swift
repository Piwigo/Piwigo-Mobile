//
//  ImageUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/07/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import ImageIO

@objc
class ImageUtilities: NSObject {
    
    // Downsampling large images for display at smaller size (WWDC 2018 - Session 219)
    class func downsample(imageAt imageURL: URL, to pointSize: CGSize, scale: CGFloat) -> UIImage {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, imageSourceOptions) else {
            return UIImage(named: "placeholder")!
        }
        return downsampledImage(from: imageSource, to: pointSize, scale: scale)
    }

    @objc
    class func downsample(image: UIImage, to pointSize: CGSize, scale: CGFloat) -> UIImage {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageData = image.jpegData(compressionQuality: 1.0),
              let imageSource = CGImageSourceCreateWithData(imageData as CFData, imageSourceOptions) else {
            return UIImage(named: "placeholder")!
        }
        return downsampledImage(from: imageSource, to: pointSize, scale: scale)
    }
    
    class func downsampledImage(from imageSource:CGImageSource, to pointSize: CGSize, scale: CGFloat) -> UIImage {
        // The default display scale for a trait collection is 0.0 (indicating unspecified).
        // We therefore adopt a scale of 1.0 when the display scale is unspecified.
        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * max(scale, 1.0)
        let downsampleOptions = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                 kCGImageSourceShouldCacheImmediately: true,
                                 kCGImageSourceCreateThumbnailWithTransform: true,
                                 kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels] as CFDictionary

        let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions)!
        return UIImage(cgImage: downsampledImage)
    }
}
