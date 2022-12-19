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
//    static func getInfos(forID imageId: Int64, inCategoryId albumId: Int32,
//                         completion: @escaping () -> Void,
//                         failure: @escaping (NSError) -> Void) {
//        // Prepare parameters for retrieving image/video infos
//        let paramsDict: [String : Any] = ["image_id" : imageId]
//        
//        // Launch request
//        let JSONsession = PwgSession.shared
//        JSONsession.postRequest(withMethod: pwgImagesGetInfo, paramDict: paramsDict,
//                                jsonObjectClientExpectsToReceive: ImagesGetInfoJSON.self,
//                                countOfBytesClientExpectsToReceive: 50000) { jsonData in
//            // Decode the JSON object and store image data in cache.
//            do {
//                // Decode the JSON into codable type ImagesGetInfoJSON.
//                let decoder = JSONDecoder()
//                let imageJSON = try decoder.decode(ImagesGetInfoJSON.self, from: jsonData)
//
//                // Piwigo error?
//                if imageJSON.errorCode != 0 {
//                    let error = PwgSession.shared.localizedError(for: imageJSON.errorCode,
//                                                                    errorMessage: imageJSON.errorMessage)
//                    failure(error as NSError)
//                    return
//                }
//
//                // Collect data returned by server
//                guard let data = imageJSON.data else {
//                    // Data cannot be digested
//                    failure(JsonError.unexpectedError as NSError)
//                    return
//                }
//
//                // Import the imageJSON into Core Data.
//                try ImageProvider.importImages(imageJSON.data, inAlbum: albumId)
//                completion()
//            }
//            catch {
//                // Data cannot be digested
//                let error = error as NSError
//                failure(error)
//            }
//        } failure: { error in
//            /// - Network communication errors
//            /// - Returned JSON data is empty
//            /// - Cannot decode data returned by Piwigo server
//            failure(error)
//        }
//    }
    
    static func setInfos(with paramsDict: [String: Any],
                         completion: @escaping () -> Void,
                         failure: @escaping (NSError) -> Void) {
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgImagesSetInfo, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: ImagesSetInfoJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData in
            // Decode the JSON object and check if image data were updated on server.
            do {
                // Decode the JSON into codable type ImagesSetInfoJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(ImagesSetInfoJSON.self, from: jsonData)
                
                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                 errorMessage: uploadJSON.errorMessage)
                    failure(error as NSError)
                    return
                }
                
                // Successful?
                if uploadJSON.success {
                    // Image properties successfully updated
                    completion()
                }
                else {
                    // Could not set image parameters
                    failure(JsonError.unexpectedError as NSError)
                }
            } catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }
    
    static func delete(_ images:[PiwigoImageData],
                       completion: @escaping () -> Void,
                       failure: @escaping (NSError) -> Void) {
        // Create string containing pipe separated list of image ids
        let listOfImageIds = images.map({ "\($0.imageId)" }).joined(separator: "|")
        
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["image_id"  : listOfImageIds,
                                          "pwg_token" : NetworkVars.pwgToken]
        
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgImagesDelete, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: ImagesDeleteJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData in
            // Decode the JSON and delete image from cache if successful.
            do {
                // Decode the JSON into codable type ImagesDeleteJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(ImagesDeleteJSON.self, from: jsonData)
                
                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                 errorMessage: uploadJSON.errorMessage)
                    failure(error as NSError)
                    return
                }
                
                // Successful?
                if uploadJSON.success {
                    // Images deleted successfully
                    /// We may check here that the number returned matches the number of images to delete
                    /// and return an error to the user.
                    DispatchQueue.global(qos: .userInteractive).async {
                        // Remove image from cache, update UI and Upload database
                        for image in images {
                            // Remove image from cache, update UI and Upload database
                            CategoriesData.sharedInstance().deleteImage(image)
                        }
                    }
                    completion()
                }
                else {
                    // Could not delete images
                    failure(JsonError.unexpectedError as NSError)
                }
            } catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }
    
    static func addToFavorites(_ imageData: PiwigoImageData,
                               completion: @escaping () -> Void,
                               failure: @escaping (NSError) -> Void) {
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["image_id"  : imageData.imageId]
        
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgUsersFavoritesAdd, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: FavoritesAddRemoveJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData in
            // Decode the JSON object and add image to favorites.
            do {
                // Decode the JSON into codable type FavoritesAddRemoveJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(FavoritesAddRemoveJSON.self, from: jsonData)
                
                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                 errorMessage: uploadJSON.errorMessage)
                    failure(error as NSError)
                    return
                }
                
                // Successful?
                if uploadJSON.success {
                    // Images successfully added to user's favorites
                    DispatchQueue.global(qos: .userInteractive).async {
                        // Add image to cache
                        CategoriesData.sharedInstance()
                            .addImage(imageData, toCategory: "\(kPiwigoFavoritesCategoryId)")
                    }
                    completion()
                }
                else {
                    // Could not delete images
                    failure(JsonError.unexpectedError as NSError)
                }
            } catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }
    
    static func removeFromFavorites(_ imageData: PiwigoImageData,
                                    completion: @escaping () -> Void,
                                    failure: @escaping (NSError) -> Void) {
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["image_id"  : imageData.imageId]
        
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgUsersFavoritesRemove, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: FavoritesAddRemoveJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData in
            // Decode the JSON object and remove image from faborites.
            do {
                // Decode the JSON into codable type FavoritesAddRemoveJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(FavoritesAddRemoveJSON.self, from: jsonData)
                
                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                 errorMessage: uploadJSON.errorMessage)
                    failure(error as NSError)
                    return
                }
                
                // Successful?
                if uploadJSON.success {
                    // Images successfully added to user's favorites
                    DispatchQueue.global(qos: .userInteractive).async {
                        // Remove image from cache
                        CategoriesData.sharedInstance()
                            .removeImage(imageData, fromCategory: String(kPiwigoFavoritesCategoryId))
                    }
                    completion()
                }
                else {
                    // Could not delete images
                    failure(JsonError.unexpectedError as NSError)
                }
            } catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }
    
    
    // MARK: - Image Downsampling
    // Downsampling large images for display at smaller size (WWDC 2018 - Session 219)
    static func downsample(imageAt imageURL: URL, to pointSize: CGSize, scale: CGFloat) -> UIImage {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard pointSize.equalTo(CGSize.zero) == false,
              let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, imageSourceOptions) else {
            if let data = try? Data( contentsOf:imageURL) {
                return UIImage(data: data) ?? UIImage(named: "placeholder")!
            } else {
                return UIImage(named: "placeholder")!
            }
        }
        return downsampledImage(from: imageSource, to: pointSize, scale: scale)
    }
    
    static func downsample(image: UIImage, to pointSize: CGSize, scale: CGFloat) -> UIImage {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard pointSize.equalTo(CGSize.zero) == false,
              let imageData = image.jpegData(compressionQuality: 1.0),
              let imageSource = CGImageSourceCreateWithData(imageData as CFData, imageSourceOptions) else {
            return image
        }
        return downsampledImage(from: imageSource, to: pointSize, scale: scale)
    }
    
    static func downsampledImage(from imageSource:CGImageSource, to pointSize: CGSize, scale: CGFloat) -> UIImage {
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
    
    
    // MARK: - Image Size, URLs
    static func optimumImageSizeForDevice() -> pwgImageSize {
        // Determine the resolution of the screen
        // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
        // See https://www.apple.com/iphone/compare/ and https://www.apple.com/ipad/compare/
        let screenSize = UIScreen.main.bounds.size
        let screenWidth = fmin(screenSize.width, screenSize.height)
        
        switch screenWidth {
        case 0...pwgImageSize.square.minPixels:
            return .square
        case pwgImageSize.square.minPixels+1...pwgImageSize.thumb.minPixels:
            return .thumb
        case pwgImageSize.thumb.minPixels+1...pwgImageSize.xxSmall.minPixels:
            return .xxSmall
        case pwgImageSize.xxSmall.minPixels+1...pwgImageSize.xSmall.minPixels:
            return .xSmall
        case pwgImageSize.xSmall.minPixels+1...pwgImageSize.small.minPixels:
            return .small
        case pwgImageSize.small.minPixels+1...pwgImageSize.medium.minPixels:
            return .medium
        case pwgImageSize.medium.minPixels+1...pwgImageSize.large.minPixels:
            return .large
        case pwgImageSize.large.minPixels+1...pwgImageSize.xLarge.minPixels:
            return .xLarge
        case pwgImageSize.xLarge.minPixels+1...pwgImageSize.xxLarge.minPixels:
            return .xxLarge
        default:
            return .fullRes
        }
    }
    
    static func imageSizeName(for size: pwgImageSize, withInfo: Bool = false) -> String {
        var sizeName = size.name
        
        // Determine the optimum image size for the current device
        let optimumSize = self.optimumImageSizeForDevice()
        
        // Return name for given thumbnail size
        switch size {
        case .square, .thumb, .xxSmall:
            if withInfo {
                sizeName.append(contentsOf: size.sizeAndScale)
            }
        case .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .fullRes:
            if withInfo {
                if size == optimumSize {
                    sizeName.append(contentsOf: NSLocalizedString("defaultImageSize_recommended", comment: " (recommended)"))
                } else {
                    sizeName.append(contentsOf: size.sizeAndScale)
                }
            }
        }
        return sizeName
    }
    
    static func getURLs(_ imageData: Image, ofMinSize size: pwgImageSize) -> (NSURL, URL)? {
        // Retrieve server cache directory
        guard let serverID = imageData.server?.uuid else { return nil }
        let serverURL = DataController.cacheDirectory.appendingPathComponent(serverID)

        // ATTENTION: Some URLs may not be available!
        // So we go through the list of URLs...
        var pwgURL: NSURL?, fileURL: URL?
        switch size {
        case .square:
            if AlbumVars.shared.hasSquareSizeImages,
               let imageUUID = imageData.squareRes?.uuid,
               let imageURL = imageData.squareRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.square.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasThumbSizeImages,
                    let imageUUID = imageData.thumbRes?.uuid,
                    let imageURL = imageData.thumbRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.thumb.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasXXSmallSizeImages,
                    let imageUUID = imageData.xxsmallRes?.uuid,
                    let imageURL = imageData.xxsmallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xxSmall.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasXSmallSizeImages,
                    let imageUUID = imageData.xsmallRes?.uuid,
                    let imageURL = imageData.xsmallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xSmall.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasSmallSizeImages,
                    let imageUUID = imageData.smallRes?.uuid,
                    let imageURL = imageData.smallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.small.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasMediumSizeImages,
                    let imageUUID = imageData.mediumRes?.uuid,
                    let imageURL = imageData.mediumRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.medium.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasLargeSizeImages,
                    let imageUUID = imageData.largeRes?.uuid,
                    let imageURL = imageData.largeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.large.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasXLargeSizeImages,
                    let imageUUID = imageData.xlargeRes?.uuid,
                    let imageURL = imageData.xlargeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xLarge.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasXXLargeSizeImages,
                    let imageUUID = imageData.xxlargeRes?.uuid,
                    let imageURL = imageData.xxlargeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xxLarge.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if let imageUUID = imageData.fullRes?.uuid,
                    let imageURL = imageData.fullRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.fullRes.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
        case .thumb:
            if AlbumVars.shared.hasSquareSizeImages,
               let imageUUID = imageData.squareRes?.uuid,
               let imageURL = imageData.squareRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.square.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasThumbSizeImages,
                    let imageUUID = imageData.thumbRes?.uuid,
                    let imageURL = imageData.thumbRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.thumb.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasXXSmallSizeImages,
                    let imageUUID = imageData.xxsmallRes?.uuid,
                    let imageURL = imageData.xxsmallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xxSmall.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasXSmallSizeImages,
                    let imageUUID = imageData.xsmallRes?.uuid,
                    let imageURL = imageData.xsmallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xSmall.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasSmallSizeImages,
                    let imageUUID = imageData.smallRes?.uuid,
                    let imageURL = imageData.smallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.small.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasMediumSizeImages,
                    let imageUUID = imageData.mediumRes?.uuid,
                    let imageURL = imageData.mediumRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.medium.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasLargeSizeImages,
                    let imageUUID = imageData.largeRes?.uuid,
                    let imageURL = imageData.largeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.large.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasXLargeSizeImages,
                    let imageUUID = imageData.xlargeRes?.uuid,
                    let imageURL = imageData.xlargeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xLarge.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasXXLargeSizeImages,
                    let imageUUID = imageData.xxlargeRes?.uuid,
                    let imageURL = imageData.xxlargeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xxLarge.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if let imageUUID = imageData.fullRes?.uuid,
                    let imageURL = imageData.fullRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.fullRes.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
        case .xxSmall:
            if AlbumVars.shared.hasSquareSizeImages,
               let imageUUID = imageData.squareRes?.uuid,
               let imageURL = imageData.squareRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.square.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasThumbSizeImages,
                    let imageUUID = imageData.thumbRes?.uuid,
                    let imageURL = imageData.thumbRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.thumb.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasXXSmallSizeImages,
                    let imageUUID = imageData.xxsmallRes?.uuid,
                    let imageURL = imageData.xxsmallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xxSmall.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasXSmallSizeImages,
                    let imageUUID = imageData.xsmallRes?.uuid,
                    let imageURL = imageData.xsmallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xSmall.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasSmallSizeImages,
                    let imageUUID = imageData.smallRes?.uuid,
                    let imageURL = imageData.smallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.small.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasMediumSizeImages,
                    let imageUUID = imageData.mediumRes?.uuid,
                    let imageURL = imageData.mediumRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.medium.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasLargeSizeImages,
                    let imageUUID = imageData.largeRes?.uuid,
                    let imageURL = imageData.largeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.large.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasXLargeSizeImages,
                    let imageUUID = imageData.xlargeRes?.uuid,
                    let imageURL = imageData.xlargeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xLarge.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasXXLargeSizeImages,
                    let imageUUID = imageData.xxlargeRes?.uuid,
                    let imageURL = imageData.xxlargeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xxLarge.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if let imageUUID = imageData.fullRes?.uuid,
                    let imageURL = imageData.fullRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.fullRes.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
        case .xSmall:
            if AlbumVars.shared.hasSquareSizeImages,
               let imageUUID = imageData.squareRes?.uuid,
               let imageURL = imageData.squareRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.square.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasThumbSizeImages,
                    let imageUUID = imageData.thumbRes?.uuid,
                    let imageURL = imageData.thumbRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.thumb.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasXXSmallSizeImages,
                    let imageUUID = imageData.xxsmallRes?.uuid,
                    let imageURL = imageData.xxsmallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xxSmall.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasXSmallSizeImages,
                    let imageUUID = imageData.xsmallRes?.uuid,
                    let imageURL = imageData.xsmallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xSmall.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasSmallSizeImages,
                    let imageUUID = imageData.smallRes?.uuid,
                    let imageURL = imageData.smallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.small.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasMediumSizeImages,
                    let imageUUID = imageData.mediumRes?.uuid,
                    let imageURL = imageData.mediumRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.medium.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasLargeSizeImages,
                    let imageUUID = imageData.largeRes?.uuid,
                    let imageURL = imageData.largeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.large.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasXLargeSizeImages,
                    let imageUUID = imageData.xlargeRes?.uuid,
                    let imageURL = imageData.xlargeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xLarge.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasXXLargeSizeImages,
                    let imageUUID = imageData.xxlargeRes?.uuid,
                    let imageURL = imageData.xxlargeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xxLarge.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if let imageUUID = imageData.fullRes?.uuid,
                    let imageURL = imageData.fullRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.fullRes.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
        case .small:
            if AlbumVars.shared.hasSquareSizeImages,
               let imageUUID = imageData.squareRes?.uuid,
               let imageURL = imageData.squareRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.square.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasThumbSizeImages,
                    let imageUUID = imageData.thumbRes?.uuid,
                    let imageURL = imageData.thumbRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.thumb.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasXXSmallSizeImages,
                    let imageUUID = imageData.xxsmallRes?.uuid,
                    let imageURL = imageData.xxsmallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xxSmall.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasXSmallSizeImages,
                    let imageUUID = imageData.xsmallRes?.uuid,
                    let imageURL = imageData.xsmallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xSmall.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasSmallSizeImages,
                    let imageUUID = imageData.smallRes?.uuid,
                    let imageURL = imageData.smallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.small.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasMediumSizeImages,
                    let imageUUID = imageData.mediumRes?.uuid,
                    let imageURL = imageData.mediumRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.medium.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasLargeSizeImages,
                    let imageUUID = imageData.largeRes?.uuid,
                    let imageURL = imageData.largeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.large.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasXLargeSizeImages,
                    let imageUUID = imageData.xlargeRes?.uuid,
                    let imageURL = imageData.xlargeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xLarge.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasXXLargeSizeImages,
                    let imageUUID = imageData.xxlargeRes?.uuid,
                    let imageURL = imageData.xxlargeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xxLarge.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if let imageUUID = imageData.fullRes?.uuid,
                    let imageURL = imageData.fullRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.fullRes.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
        case .medium:
            if AlbumVars.shared.hasSquareSizeImages,
               let imageUUID = imageData.squareRes?.uuid,
               let imageURL = imageData.squareRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.square.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasThumbSizeImages,
                    let imageUUID = imageData.thumbRes?.uuid,
                    let imageURL = imageData.thumbRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.thumb.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasXXSmallSizeImages,
                    let imageUUID = imageData.xxsmallRes?.uuid,
                    let imageURL = imageData.xxsmallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xxSmall.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasXSmallSizeImages,
                    let imageUUID = imageData.xsmallRes?.uuid,
                    let imageURL = imageData.xsmallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xSmall.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasSmallSizeImages,
                    let imageUUID = imageData.smallRes?.uuid,
                    let imageURL = imageData.smallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.small.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasMediumSizeImages,
                    let imageUUID = imageData.mediumRes?.uuid,
                    let imageURL = imageData.mediumRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.medium.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasLargeSizeImages,
                    let imageUUID = imageData.largeRes?.uuid,
                    let imageURL = imageData.largeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.large.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasXLargeSizeImages,
                    let imageUUID = imageData.xlargeRes?.uuid,
                    let imageURL = imageData.xlargeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xLarge.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasXXLargeSizeImages,
                    let imageUUID = imageData.xxlargeRes?.uuid,
                    let imageURL = imageData.xxlargeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xxLarge.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if let imageUUID = imageData.fullRes?.uuid,
                    let imageURL = imageData.fullRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.fullRes.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
        case .large:
            if AlbumVars.shared.hasSquareSizeImages,
               let imageUUID = imageData.squareRes?.uuid,
               let imageURL = imageData.squareRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.square.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasThumbSizeImages,
                    let imageUUID = imageData.thumbRes?.uuid,
                    let imageURL = imageData.thumbRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.thumb.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasXXSmallSizeImages,
                    let imageUUID = imageData.xxsmallRes?.uuid,
                    let imageURL = imageData.xxsmallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xxSmall.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasXSmallSizeImages,
                    let imageUUID = imageData.xsmallRes?.uuid,
                    let imageURL = imageData.xsmallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xSmall.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasSmallSizeImages,
                    let imageUUID = imageData.smallRes?.uuid,
                    let imageURL = imageData.smallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.small.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasMediumSizeImages,
                    let imageUUID = imageData.mediumRes?.uuid,
                    let imageURL = imageData.mediumRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.medium.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasLargeSizeImages,
                    let imageUUID = imageData.largeRes?.uuid,
                    let imageURL = imageData.largeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.large.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasXLargeSizeImages,
                    let imageUUID = imageData.xlargeRes?.uuid,
                    let imageURL = imageData.xlargeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xLarge.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasXXLargeSizeImages,
                    let imageUUID = imageData.xxlargeRes?.uuid,
                    let imageURL = imageData.xxlargeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xxLarge.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if let imageUUID = imageData.fullRes?.uuid,
                    let imageURL = imageData.fullRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.fullRes.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
        case .xLarge:
            if AlbumVars.shared.hasSquareSizeImages,
               let imageUUID = imageData.squareRes?.uuid,
               let imageURL = imageData.squareRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.square.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasThumbSizeImages,
                    let imageUUID = imageData.thumbRes?.uuid,
                    let imageURL = imageData.thumbRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.thumb.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasXXSmallSizeImages,
                    let imageUUID = imageData.xxsmallRes?.uuid,
                    let imageURL = imageData.xxsmallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xxSmall.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasXSmallSizeImages,
                    let imageUUID = imageData.xsmallRes?.uuid,
                    let imageURL = imageData.xsmallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xSmall.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasSmallSizeImages,
                    let imageUUID = imageData.smallRes?.uuid,
                    let imageURL = imageData.smallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.small.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasMediumSizeImages,
                    let imageUUID = imageData.mediumRes?.uuid,
                    let imageURL = imageData.mediumRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.medium.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasLargeSizeImages,
                    let imageUUID = imageData.largeRes?.uuid,
                    let imageURL = imageData.largeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.large.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasXLargeSizeImages,
                    let imageUUID = imageData.xlargeRes?.uuid,
                    let imageURL = imageData.xlargeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xLarge.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if AlbumVars.shared.hasXXLargeSizeImages,
                    let imageUUID = imageData.xxlargeRes?.uuid,
                    let imageURL = imageData.xxlargeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xxLarge.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if let imageUUID = imageData.fullRes?.uuid,
                    let imageURL = imageData.fullRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.fullRes.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
        case .xxLarge:
            if AlbumVars.shared.hasSquareSizeImages,
               let imageUUID = imageData.squareRes?.uuid,
               let imageURL = imageData.squareRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.square.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasThumbSizeImages,
                    let imageUUID = imageData.thumbRes?.uuid,
                    let imageURL = imageData.thumbRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.thumb.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasXXSmallSizeImages,
                    let imageUUID = imageData.xxsmallRes?.uuid,
                    let imageURL = imageData.xxsmallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xxSmall.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasXSmallSizeImages,
                    let imageUUID = imageData.xsmallRes?.uuid,
                    let imageURL = imageData.xsmallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xSmall.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasSmallSizeImages,
                    let imageUUID = imageData.smallRes?.uuid,
                    let imageURL = imageData.smallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.small.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasMediumSizeImages,
                    let imageUUID = imageData.mediumRes?.uuid,
                    let imageURL = imageData.mediumRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.medium.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasLargeSizeImages,
                    let imageUUID = imageData.largeRes?.uuid,
                    let imageURL = imageData.largeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.large.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasXLargeSizeImages,
                    let imageUUID = imageData.xlargeRes?.uuid,
                    let imageURL = imageData.xlargeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xLarge.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasXXLargeSizeImages,
                    let imageUUID = imageData.xxlargeRes?.uuid,
                    let imageURL = imageData.xxlargeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xxLarge.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            else if let imageUUID = imageData.fullRes?.uuid,
                    let imageURL = imageData.fullRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.fullRes.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
        case .fullRes:
            if AlbumVars.shared.hasSquareSizeImages,
               let imageUUID = imageData.squareRes?.uuid,
               let imageURL = imageData.squareRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.square.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasThumbSizeImages,
                    let imageUUID = imageData.thumbRes?.uuid,
                    let imageURL = imageData.thumbRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.thumb.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasXXSmallSizeImages,
                    let imageUUID = imageData.xxsmallRes?.uuid,
                    let imageURL = imageData.xxsmallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xxSmall.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasXSmallSizeImages,
                    let imageUUID = imageData.xsmallRes?.uuid,
                    let imageURL = imageData.xsmallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xSmall.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasSmallSizeImages,
                    let imageUUID = imageData.smallRes?.uuid,
                    let imageURL = imageData.smallRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.small.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasMediumSizeImages,
                    let imageUUID = imageData.mediumRes?.uuid,
                    let imageURL = imageData.mediumRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.medium.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasLargeSizeImages,
                    let imageUUID = imageData.largeRes?.uuid,
                    let imageURL = imageData.largeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.large.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasXLargeSizeImages,
                    let imageUUID = imageData.xlargeRes?.uuid,
                    let imageURL = imageData.xlargeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xLarge.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if AlbumVars.shared.hasXXLargeSizeImages,
                    let imageUUID = imageData.xxlargeRes?.uuid,
                    let imageURL = imageData.xxlargeRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.xxLarge.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
            if let imageUUID = imageData.fullRes?.uuid,
                    let imageURL = imageData.fullRes?.url {
                pwgURL = imageURL
                let cacheURL = serverURL.appendingPathComponent(pwgImageSize.fullRes.path)
                fileURL = cacheURL.appendingPathComponent(imageUUID)
            }
        }
        guard let pwgURL = pwgURL, let fileURL = fileURL else {
            return nil
        }
        return (pwgURL, fileURL)
    }
}
