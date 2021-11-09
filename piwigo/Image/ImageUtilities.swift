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

@objc
class ImageUtilities: NSObject {
    
    // MARK: - Piwigo Server Methods
    @objc
    class func getInfos(forID imageId:Int,
                        completion: @escaping (PiwigoImageData) -> Void,
                        failure: @escaping (NSError) -> Void) {
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["image_id" : "\(imageId)"]
        
        // Launch request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoImagesGetInfo, paramDict: paramsDict,
                                countOfBytesClientExpectsToReceive: 50000) { jsonData, error in
            // Any error?
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            if let error = error as NSError? {
                failure(error)
                return
            }
            
            // Decode the JSON and import it into Core Data.
            do {
                // Decode the JSON into codable type ImagesGetInfoJSON.
                let decoder = JSONDecoder()
                let imageJSON = try decoder.decode(ImagesGetInfoJSON.self, from: jsonData)

                // Piwigo error?
                if (imageJSON.errorCode != 0) {
                    let error = NSError(domain: "Piwigo", code: imageJSON.errorCode,
                                    userInfo: [NSLocalizedDescriptionKey : imageJSON.errorMessage])
                    failure(error)
                    return
                }

                // Collect data returned by server
                let imageData = PiwigoImageData()
                if let data = imageJSON.data {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    imageData.imageId = data.imageId ?? imageId
                    imageData.categoryIds = data.categoryIds?.map({ NSNumber(integerLiteral: $0.id!) })
                    imageData.imageTitle = NetworkUtilities.utf8mb4String(from: data.imageTitle ?? "")
                    imageData.comment = NetworkUtilities.utf8mb4String(from: data.comment ?? "")
                    imageData.visits = data.visits ?? 0
                    if let rate = Float(data.ratingScore ?? "0.0") {
                        imageData.ratingScore = rate
                    }
                    
                    imageData.fileSize = data.fileSize ?? NSNotFound
                    imageData.md5checksum = data.md5checksum ?? ""
                    imageData.fileName = NetworkUtilities.utf8mb4String(from: data.fileName ?? "NoName.jpg")
                    let fileExt = URL(fileURLWithPath: imageData.fileName).pathExtension as NSString
                    if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExt, nil)?.takeRetainedValue() {
                        imageData.isVideo = UTTypeConformsTo(uti, kUTTypeMovie)
                    }
                    imageData.datePosted = dateFormatter.date(from: data.datePosted ?? "") ?? Date()
                    imageData.dateCreated = dateFormatter.date(from: data.dateCreated ?? "") ?? imageData.datePosted
                    imageData.author = NetworkUtilities.utf8mb4String(from: data.author ?? "NSNotFound")
                    if let privacyLevel = Int32(data.privacyLevel ?? String(kPiwigoPrivacyObjcUnknown.rawValue)) {
                        imageData.privacyLevel = kPiwigoPrivacyObjc(rawValue: privacyLevel)
                    } else {
                        imageData.privacyLevel = kPiwigoPrivacyObjcUnknown
                    }
                    
                    // Switch to old cache data format
                    var tagList = [PiwigoTagData]()
                    for tag in data.tags ?? [] {
                        guard let tagId = tag.id else { continue }
                        let newTag = PiwigoTagData()
                        newTag.tagId = Int(tagId)
                        newTag.tagName = NetworkUtilities.utf8mb4String(from: tag.name ?? "")
                        newTag.lastModified = dateFormatter.date(from: tag.lastmodified ?? "") ?? Date()
                        newTag.numberOfImagesUnderTag = tag.counter ?? Int64(NSNotFound)
                        tagList.append(newTag)
                    }
                    imageData.tags = tagList

                    imageData.fullResWidth = data.fullResWidth ?? 1
                    imageData.fullResHeight = data.fullResHeight ?? 1
                    imageData.fullResPath = data.fullResPath ?? ""
                }

                if let derivatives = imageJSON.derivatives {
                    imageData.squarePath = derivatives.squareImage?.url ?? ""
                    imageData.squareWidth = derivatives.squareImage?.width ?? 1
                    imageData.squareHeight = derivatives.squareImage?.height ?? 1
                    imageData.thumbPath = derivatives.thumbImage?.url ?? ""
                    imageData.thumbWidth = derivatives.thumbImage?.width ?? 1
                    imageData.thumbHeight = derivatives.thumbImage?.height ?? 1
                    imageData.mediumPath = derivatives.mediumImage?.url ?? ""
                    imageData.mediumWidth = derivatives.mediumImage?.width ?? 1
                    imageData.mediumHeight = derivatives.mediumImage?.height ?? 1
                    imageData.xxSmallPath = derivatives.xxSmallImage?.url ?? ""
                    imageData.xxSmallWidth = derivatives.xxSmallImage?.width ?? 1
                    imageData.xxSmallHeight = derivatives.xxSmallImage?.height ?? 1
                    imageData.xSmallPath = derivatives.xSmallImage?.url ?? ""
                    imageData.xSmallWidth = derivatives.xSmallImage?.width ?? 1
                    imageData.xSmallHeight = derivatives.xSmallImage?.height ?? 1
                    imageData.smallPath = derivatives.smallImage?.url ?? ""
                    imageData.smallWidth = derivatives.smallImage?.width ?? 1
                    imageData.smallHeight = derivatives.smallImage?.height ?? 1
                    imageData.largePath = derivatives.largeImage?.url ?? ""
                    imageData.largeWidth = derivatives.largeImage?.width ?? 1
                    imageData.largeHeight = derivatives.largeImage?.height ?? 1
                    imageData.xLargePath = derivatives.xLargeImage?.url ?? ""
                    imageData.xLargeWidth = derivatives.xLargeImage?.width ?? 1
                    imageData.xLargeHeight = derivatives.xLargeImage?.height ?? 1
                    imageData.xxLargePath = derivatives.xxLargeImage?.url ?? ""
                    imageData.xxLargeWidth = derivatives.xxLargeImage?.width ?? 1
                    imageData.xxLargeHeight = derivatives.xxLargeImage?.height ?? 1
                }

                // Update cache
                for catId in imageData.categoryIds {
                    CategoriesData.sharedInstance().getCategoryById(catId.intValue)
                        .updateImages([imageData])
                }
                completion(imageData)
            }
            catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        }
    }
    
    @objc
    class func setInfos(with paramsDict: [String: Any],
                        completion: @escaping () -> Void,
                        failure: @escaping (NSError) -> Void) {
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoImagesSetInfo, paramDict: paramsDict,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData, error in
            // Any error?
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            if let error = error as NSError? {
                failure(error)
                return
            }
            
            // Decode the JSON and import it into Core Data.
            do {
                // Decode the JSON into codable type ImagesSetInfoJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(ImagesSetInfoJSON.self, from: jsonData)

                // Piwigo error?
                if (uploadJSON.errorCode != 0) {
                    let error = NSError(domain: "Piwigo", code: uploadJSON.errorCode,
                                    userInfo: [NSLocalizedDescriptionKey : uploadJSON.errorMessage])
                    failure(error)
                    return
                }

                // Successful?
                if uploadJSON.success {
                    // Image properties successfully updated
                    completion()
                }
                else {
                    // Could not set image parameters
                    let error = NSError(domain: "Piwigo", code: -1, userInfo: [NSLocalizedDescriptionKey : NSLocalizedString("serverUnknownError_message", comment: "Unexpected error encountered while calling server method with provided parameters.")])
                    failure(error)
                }
            } catch {
                // Data cannot be digested
                let error = NSError(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : JsonError.wrongJSONobject.localizedDescription])
                failure(error)
            }
        }
    }
    
    @objc
    class func delete(_ images:[PiwigoImageData],
                      completion: @escaping () -> Void,
                      failure: @escaping (NSError) -> Void) {
        // Create string containing pipe separated list of image ids
        let listOfImageIds = images.map({ "\($0.imageId)" }).joined(separator: "|")
        
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["image_id"  : listOfImageIds,
                                          "pwg_token" : NetworkVars.pwgToken]

        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoImagesDelete, paramDict: paramsDict,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData, error in
            // Any error?
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            if let error = error as NSError? {
                failure(error)
                return
            }
            
            // Decode the JSON and import it into Core Data.
            do {
                // Decode the JSON into codable type ImagesDeleteJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(ImagesDeleteJSON.self, from: jsonData)

                // Piwigo error?
                if (uploadJSON.errorCode != 0) {
                    let error = NSError(domain: "Piwigo", code: uploadJSON.errorCode,
                                    userInfo: [NSLocalizedDescriptionKey : uploadJSON.errorMessage])
                    failure(error)
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
                    let error = NSError(domain: "Piwigo", code: -1, userInfo: [NSLocalizedDescriptionKey : NSLocalizedString("serverUnknownError_message", comment: "Unexpected error encountered while calling server method with provided parameters.")])
                    failure(error)
                }
            } catch {
                // Data cannot be digested
                let error = NSError(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : JsonError.wrongJSONobject.localizedDescription])
                failure(error)
            }
        }
    }

    @objc
    class func addToFavorites(_ imageData: PiwigoImageData,
                      completion: @escaping () -> Void,
                      failure: @escaping (NSError) -> Void) {
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["image_id"  : "\(imageData.imageId)"]

        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoUsersFavoritesAdd, paramDict: paramsDict,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData, error in
            // Any error?
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            if let error = error as NSError? {
                failure(error)
                return
            }
            
            // Decode the JSON and import it into Core Data.
            do {
                // Decode the JSON into codable type FavoritesAddRemoveJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(FavoritesAddRemoveJSON.self, from: jsonData)

                // Piwigo error?
                if (uploadJSON.errorCode != 0) {
                    let error = NSError(domain: "Piwigo", code: uploadJSON.errorCode,
                                    userInfo: [NSLocalizedDescriptionKey : uploadJSON.errorMessage])
                    failure(error)
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
                    let error = NSError(domain: "Piwigo", code: -1, userInfo: [NSLocalizedDescriptionKey : NSLocalizedString("serverUnknownError_message", comment: "Unexpected error encountered while calling server method with provided parameters.")])
                    failure(error)
                }
            } catch {
                // Data cannot be digested
                let error = NSError(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : JsonError.wrongJSONobject.localizedDescription])
                failure(error)
            }
        }
    }

    @objc
    class func removeFromFavorites(_ imageData: PiwigoImageData,
                                   completion: @escaping () -> Void,
                                   failure: @escaping (NSError) -> Void) {
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["image_id"  : "\(imageData.imageId)"]

        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoUsersFavoritesRemove, paramDict: paramsDict,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData, error in
            // Any error?
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            if let error = error as NSError? {
                failure(error)
                return
            }
            
            // Decode the JSON and import it into Core Data.
            do {
                // Decode the JSON into codable type FavoritesAddRemoveJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(FavoritesAddRemoveJSON.self, from: jsonData)

                // Piwigo error?
                if (uploadJSON.errorCode != 0) {
                    let error = NSError(domain: "Piwigo", code: uploadJSON.errorCode,
                                    userInfo: [NSLocalizedDescriptionKey : uploadJSON.errorMessage])
                    failure(error)
                    return
                }

                // Successful?
                if uploadJSON.success {
                    // Images successfully added to user's favorites
                    DispatchQueue.global(qos: .userInteractive).async {
                        // Remove image from cache
                        CategoriesData.sharedInstance()
                            .removeImage(imageData, fromCategory: "\(kPiwigoFavoritesCategoryId)")
                    }
                    completion()
                }
                else {
                    // Could not delete images
                    let error = NSError(domain: "Piwigo", code: -1, userInfo: [NSLocalizedDescriptionKey : NSLocalizedString("serverUnknownError_message", comment: "Unexpected error encountered while calling server method with provided parameters.")])
                    failure(error)
                }
            } catch {
                // Data cannot be digested
                let error = NSError(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : JsonError.wrongJSONobject.localizedDescription])
                failure(error)
            }
        }
    }

    
    // MARK: - Image Downsampling
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
