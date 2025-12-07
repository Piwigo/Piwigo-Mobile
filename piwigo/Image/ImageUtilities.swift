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
import piwigoKit
import UIKit

class ImageUtilities: NSObject {
    
    // MARK: - Piwigo Server Methods
    static func rotate(_ image: Image, by angle: Double,
                       completion: @escaping () -> Void,
                       failure: @escaping (PwgKitError) -> Void) {
        // Prepare parameters for rotating image
        let paramsDict: [String : Any] = ["image_id"  : image.pwgID,
                                          "angle"     : angle * 180.0 / .pi,
                                          "pwg_token" : NetworkVars.shared.pwgToken,
                                          "rotate_hd" : true]
        
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgImageRotate, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: ImageRotateJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { result in
            switch result {
            case .success:
                // Image rotated successfully ► Rotate thumbnails in cache
                /// Image data not always immediately available after rotation.
                /// We rotate the images stored in cache instead of downloading them.
                rotateThumbnailsOfImage(image, by: angle)
                completion()
            
            case .failure(let error):
                /// - Network communication errors
                /// - Returned JSON data is empty
                /// - Cannot decode data returned by Piwigo server
                failure(error)
            }
        }
    }
    
    static func setCategory(_ albumID: Int32, forImageIDs listOfImageIds: [Int64],
                            withAction action: pwgImagesSetCategoryAction,
                            completion: @escaping () -> Void,
                            failure: @escaping (PwgKitError) -> Void) {
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["image_id"    : listOfImageIds,
                                          "category_id" : albumID,
                                          "action"      : action.rawValue,
                                          "pwg_token"   : NetworkVars.shared.pwgToken]
        
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgImagesSetCategory, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: ImagesSetCategoryJSON.self,
                                countOfBytesClientExpectsToReceive: pwgImagesSetCategoryBytes) { result in
            switch result {
            case .success(let pwgData):
                // Images associated/dissociated/moved successfully
                completion()
            
            case .failure(let error):
                /// - Network communication errors
                /// - Returned JSON data is empty
                /// - Cannot decode data returned by Piwigo server
                failure(error)
            }
        }
    }

    static func delete(_ images: Set<Image>,
                       completion: @escaping () -> Void,
                       failure: @escaping (PwgKitError) -> Void) {
        // Prepare parameters for retrieving image/video infos
        let listOfImageIds: [Int64] = images.map({ $0.pwgID })
        let paramsDict: [String : Any] = ["image_id"  : listOfImageIds,
                                          "pwg_token" : NetworkVars.shared.pwgToken]
        
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgImagesDelete, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: ImagesDeleteJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { result in
            switch result {
            case .success:
                // Images deleted successfully
                /// We may check here that the number returned matches the number of images to delete
                /// and return an error to the user.
                completion()
            
            case .failure(let error):
                /// - Network communication errors
                /// - Returned JSON data is empty
                /// - Cannot decode data returned by Piwigo server
                failure(error)
            }
        }
    }
    
    static func addToFavorites(_ imageData: Image,
                               completion: @escaping () -> Void,
                               failure: @escaping (PwgKitError) -> Void) {
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["image_id"  : imageData.pwgID]
        
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgUsersFavoritesAdd, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: FavoritesAddRemoveJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { result in
            switch result {
            case .success:
                // Images successfully added to user's favorites
                completion()
            
            case .failure(let error):
                /// - Network communication errors
                /// - Returned JSON data is empty
                /// - Cannot decode data returned by Piwigo server
                failure(error)
            }
        }
    }
    
    static func removeFromFavorites(_ imageData: Image,
                                    completion: @escaping () -> Void,
                                    failure: @escaping (PwgKitError) -> Void) {
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["image_id"  : imageData.pwgID]
        
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgUsersFavoritesRemove, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: FavoritesAddRemoveJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { result in
            switch result {
            case .success:
                // Images successfully removed from user's favorites
                completion()
            
            case .failure(let error):
                /// - Network communication errors
                /// - Returned JSON data is empty
                /// - Cannot decode data returned by Piwigo server
                failure(error)
            }
        }
    }
    
    
    // MARK: - Image Downsampling
    // Downsampling large images for display at smaller size
    /// WWDC 2018 - Session 219 - Image and Graphics Best practices
    
    // Bug introduced on 6 September 2024 (commit 18e427379a8132575a72ef053fe7d26090e09525)
    static let dateCommit18e4273 = ISO8601DateFormatter().date(from: "2024-09-06T00:00:00Z")!
    static let dateOfFirstOptImageV323 = {
        if AppVars.shared.dateOfFirstOptImageV323 == Date.distantFuture.timeIntervalSinceReferenceDate {
            AppVars.shared.dateOfFirstOptImageV323 = Date().timeIntervalSinceReferenceDate
        }
        return Date(timeIntervalSinceReferenceDate: AppVars.shared.dateOfFirstOptImageV323)
    }()
    
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
        let filePath = imageURL.path + CacheVars.shared.optImage
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
               (fileCreationDate < dateCommit18e4273 || fileCreationDate > dateOfFirstOptImageV323) {
                return optImage
            }
        }
        
        // Retrieve image
        guard let image = UIImage(contentsOfFile: imageURL.path)
        else {
            // Delete corrupted cached image file if any
            try? FileManager.default.removeItem(at: imageURL)
            return type.placeHolder
        }
        
        // Downsample image if needed
        guard let optSize = optimumSize(ofImage: image, forPointSize: pointSize),
              let downsampledImage = image.preparingThumbnail(of: optSize)
        else {
            return image
        }
        
        // Save the downsampled image in cache if it does not belong to the app
        if [.album, .image].contains(type) {
            saveDownsampledImage(downsampledImage, atPath: filePath)
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
    
    private static func saveDownsampledImage(_ downSampledImage: UIImage, atPath filePath: String) {
        autoreleasepool {
            let fm = FileManager.default
            try? fm.removeItem(atPath: filePath)
            if #available(iOS 17, *) {
                if let data = downSampledImage.heicData() as? NSData {
                    do {
                        try data.write(toFile: filePath, options: .atomic)
                    } catch {
                        debugPrint(error.localizedDescription)
                    }
                }
            } else if let data = downSampledImage.jpegData(compressionQuality: 1.0) as? NSData {
                do {
                    try data.write(toFile: filePath, options: .atomic)
                } catch {
                    debugPrint(error.localizedDescription)
                }
            }
        }
    }
    
    // https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_context/dq_context.html#//apple_ref/doc/uid/TP30001066-CH203-BCIBHHBB
    @available(iOS, introduced: 12.0, deprecated: 15.0, message: "")
    public static func supportsPixelFormat(ofCGImage image: CGImage) -> Bool {
        guard let colorSpace = image.colorSpace else {
            return false
        }
        #if os(iOS) || os(watchOS) || os(tvOS)
        let iOS = true
        #else
        let iOS = false
        #endif
        
        #if os(OSX)
        let macOS = true
        #else
        let macOS = false
        #endif
        
        switch (colorSpace.model, image.bitsPerPixel, image.bitsPerComponent,
                image.alphaInfo, image.bitmapInfo.contains(.floatComponents)) {
        case (.unknown, 8, 8, .alphaOnly, _):
            return macOS || iOS
        case (.monochrome, 8, 8, .none, _):
            return macOS || iOS
        case (.monochrome, 8, 8, .alphaOnly, _):
            return macOS || iOS
        case (.monochrome, 16, 16, .none, _):
            return macOS
        case (.monochrome, 32, 32, .none, true):
            return macOS
        case (.rgb, 16, 5, .noneSkipFirst, _):
            return macOS || iOS
        case (.rgb, 32, 8, .noneSkipFirst, _):
            return macOS || iOS
        case (.rgb, 32, 8, .noneSkipLast, _):
            return macOS || iOS
        case (.rgb, 32, 8, .premultipliedFirst, _):
            return macOS || iOS
        case (.rgb, 32, 8, .premultipliedLast, _):
            return macOS || iOS
        case (.rgb, 64, 16, .premultipliedLast, _):
            return macOS
        case (.rgb, 64, 16, .noneSkipLast, _):
            return macOS
        case (.rgb, 128, 32, .noneSkipLast, true):
            return macOS
        case (.rgb, 128, 32, .premultipliedLast, true):
            return macOS
        case (.cmyk, 32, 8, .none, _):
            return macOS
        case (.cmyk, 64, 16, .none, _):
            return macOS
        case (.cmyk, 128, 32, .none, true):
            return macOS
        default:
            return false
        }
    }
    
    
    // MARK: - Image Size, URLs
    static func optimumImageSizeForDevice() -> pwgImageSize {
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
        default:
            return .fullRes
        }
    }
    
    static func getPiwigoURL(_ imageData: Image, ofMinSize size: pwgImageSize) -> URL? {
        // ATTENTION: Some URLs may not be available!
        /// - Check available image sizes from the smallest to the highest resolution
        /// - The max size of a video or PDF  thumbnail is xxLarge
        let sizes = imageData.sizes
        var pwgURL: NSURL?
        
        // Square Size (should always be available)
        if NetworkVars.shared.hasSquareSizeImages,
           let imageURL = sizes.square?.url,
           (imageURL.absoluteString ?? "").isEmpty == false {
            // Ensure that at least an URL will be returned
            pwgURL = imageURL
        }
        
        // Done if wanted size reached
        if size == .square, let imageURL = pwgURL {
            return imageURL as URL
        }
        
        // Thumbnail Size (should always be available)
        if NetworkVars.shared.hasThumbSizeImages,
           let imageURL = sizes.thumb?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Ensure that at least an URL will be returned
            pwgURL = imageURL
        }
        
        // Done if wanted size reached
        if size <= .thumb, let imageURL = pwgURL {
            return imageURL as URL
        }
        
        // XX Small Size
        if NetworkVars.shared.hasXXSmallSizeImages,
           let imageURL = sizes.xxsmall?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Ensure that at least an URL will be returned
            pwgURL = imageURL
        }
        
        // Done if wanted size reached
        if size <= .xxSmall, let imageURL = pwgURL {
            return imageURL as URL
        }
        
        // X Small Size
        if NetworkVars.shared.hasXSmallSizeImages,
           let imageURL = sizes.xsmall?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Ensure that at least an URL will be returned
            pwgURL = imageURL
        }
        
        // Done if wanted size reached
        if size <= .xSmall, let imageURL = pwgURL {
            return imageURL as URL
        }
        
        // Small Size
        if NetworkVars.shared.hasSmallSizeImages,
           let imageURL = sizes.small?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Ensure that at least an URL will be returned
            pwgURL = imageURL
        }
        
        // Done if wanted size reached
        if size <= .small, let imageURL = pwgURL {
            return imageURL as URL
        }
        
        // Medium Size (should always be available)
        if NetworkVars.shared.hasMediumSizeImages,
           let imageURL = sizes.medium?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Ensure that at least an URL will be returned
            pwgURL = imageURL
        }
        
        // Done if wanted size reached
        if size <= .medium, let imageURL = pwgURL {
            return imageURL as URL
        }
        
        // Large Size
        if NetworkVars.shared.hasLargeSizeImages,
           let imageURL = sizes.large?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Ensure that at least an URL will be returned
            pwgURL = imageURL
        }
        
        // Done if wanted size reached
        if size <= .large, let imageURL = pwgURL {
            return imageURL as URL
        }
        
        // X Large Size
        if NetworkVars.shared.hasXLargeSizeImages,
           let imageURL = sizes.xlarge?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Ensure that at least an URL will be returned
            pwgURL = imageURL
        }
        
        // Done if wanted size reached
        if size <= .xLarge, let imageURL = pwgURL {
            return imageURL as URL
        }
        
        // XX Large Size
        if NetworkVars.shared.hasXXLargeSizeImages,
           let imageURL = sizes.xxlarge?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Ensure that at least an URL will be returned
            pwgURL = imageURL
        }
        
        // Done if wanted size reached or not an image
        if (size <= .xxLarge) || imageData.isNotImage, let imageURL = pwgURL {
            return imageURL as URL
        }
        
        // Full Resolution
        if imageData.isImage,
           let imageURL = imageData.fullRes?.url, !(imageURL.absoluteString ?? "").isEmpty {
            // Ensure that at least an URL will be returned
            pwgURL = imageURL
        }
        return pwgURL as URL?
    }
    

    // MARK: - Image Rotation
    static func rotateThumbnailsOfImage(_ imageData: Image, by angle: CGFloat) {
        // Initialisation
        guard let serverID = imageData.server?.uuid else { return }
        let cacheDir = DataDirectories.cacheDirectory.appendingPathComponent(serverID)
        let fm = FileManager.default

        // Loop over all sizes
        autoreleasepool {
            pwgImageSize.allCases.forEach { size in
                // Determine URL of image in cache
                let fileURL = cacheDir.appendingPathComponent(size.path)
                    .appendingPathComponent(String(imageData.pwgID))
                
                // Rotate thumbnail if any
                if let image = UIImage(contentsOfFile: fileURL.path),
                   let rotatedImage = image.rotated(by: -angle),
                   let data = rotatedImage.jpegData(compressionQuality: 1.0) as? NSData
                {
                    let filePath = fileURL.path
                    try? fm.removeItem(atPath: filePath)
                    do {
                        try data.write(toFile: filePath, options: .atomic)
                    } catch {
                        debugPrint(error.localizedDescription)
                    }
                }
                
                // Swap dimensions
                switch size {
                case .square:
                    imageData.sizes.square?.dimensionsSwaped()
                case .thumb:
                    imageData.sizes.thumb?.dimensionsSwaped()
                case .xxSmall:
                    imageData.sizes.xxsmall?.dimensionsSwaped()
                case .xSmall:
                    imageData.sizes.xsmall?.dimensionsSwaped()
                case .small:
                    imageData.sizes.small?.dimensionsSwaped()
                case .medium:
                    imageData.sizes.medium?.dimensionsSwaped()
                case .large:
                    imageData.sizes.large?.dimensionsSwaped()
                case .xLarge:
                    imageData.sizes.xlarge?.dimensionsSwaped()
                case .xxLarge:
                    imageData.sizes.xxlarge?.dimensionsSwaped()
                case .fullRes:
                    imageData.fullRes?.dimensionsSwaped()
                }
 
                // Rotate optimised image if any
                let filePath = fileURL.path + CacheVars.shared.optImage
                if let image = UIImage(contentsOfFile: filePath),
                   let rotatedImage = image.rotated(by: -angle) {
                    saveDownsampledImage(rotatedImage, atPath: filePath)
                }
                
                // The file size and MD5 checksum are unchanged.
            }
        }
    }
}
