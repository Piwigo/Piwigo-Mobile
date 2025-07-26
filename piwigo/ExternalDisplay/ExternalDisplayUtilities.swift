//
//  ExternalDisplayUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 23/05/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

class ExternalDisplayUtilities {
    /** Returns:
     - the Piwigo  image size
     - the URL of the image file stored on the Piwigo server
       whose resolution matches the one of the external screen
     
     N.B.: Should only be applied to images
     **/
    static func getOptimumImageSizeAndURL(_ imageData: Image, ofMinSize wantedSize: Int) -> (pwgImageSize, URL)? {
        // ATTENTION: Some sizes and/or URLs may not be available!
        // So we go through the whole list of URLs...
        
        // Download image of optimum size (depends on Piwigo server settings)
        /// - Check available image sizes from the smallest to the highest resolution
        /// - Note: image.width and .height are always > 1
        let sizes = imageData.sizes
        var selectedSize = Int.zero
        var pwgSize: pwgImageSize = .square, pwgURL: NSURL?

        // Square Size (should always be available)
        if NetworkVars.shared.hasSquareSizeImages,
           let imageURL = sizes.square?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Max dimension of this image
            let size = sizes.square?.maxSize ?? 1
            // Ensure that at least an URL will be returned
            pwgSize = .square
            pwgURL = imageURL
            selectedSize = size
        }
        
        // Thumbnail Size (should always be available)
        if NetworkVars.shared.hasThumbSizeImages,
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
        if NetworkVars.shared.hasXXSmallSizeImages,
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
        if NetworkVars.shared.hasXSmallSizeImages,
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
        if NetworkVars.shared.hasSmallSizeImages,
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
        if NetworkVars.shared.hasMediumSizeImages,
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
        if NetworkVars.shared.hasLargeSizeImages,
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
        if NetworkVars.shared.hasXLargeSizeImages,
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
        if NetworkVars.shared.hasXXLargeSizeImages,
           let imageURL = sizes.xxlarge?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Max dimension of this image
            let size = sizes.xxlarge?.maxSize ?? 1
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate
            if (pwgURL == nil) || sizeIsNearest(size, current: selectedSize, wanted: wantedSize) || imageData.isNotImage {
                pwgSize = .xxLarge
                pwgURL = imageURL
                selectedSize = size
            }
        }
        
        // Full Resolution (not always available)
        if let imageURL = imageData.fullRes?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Max dimension of this image
            let size = imageData.fullRes?.maxSize ?? 1
            // Ensure that at least an URL will be returned
            // and check if this size is more appropriate for an image exclusively
            if imageData.isImage, (pwgURL == nil) || sizeIsNearest(size, current: selectedSize, wanted: wantedSize) {
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
        // Check if the size is greater than the current size which is smaller than the wanted size
        return (size > current) && (current < wanted)
    }
}
