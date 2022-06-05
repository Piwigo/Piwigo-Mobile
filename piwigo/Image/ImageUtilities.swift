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
    class func getInfos(forID imageId:Int, inCategoryId categoryId: Int,
                        completion: @escaping (PiwigoImageData) -> Void,
                        failure: @escaping (NSError) -> Void) {
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["image_id" : imageId]
        
        // Launch request
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoImagesGetInfo, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: ImagesGetInfoJSON.self,
                                countOfBytesClientExpectsToReceive: 50000) { jsonData in
            // Decode the JSON object and store image data in cache.
            do {
                // Decode the JSON into codable type ImagesGetInfoJSON.
                let decoder = JSONDecoder()
                let imageJSON = try decoder.decode(ImagesGetInfoJSON.self, from: jsonData)

                // Piwigo error?
                if imageJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: imageJSON.errorCode,
                                                                    errorMessage: imageJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Collect data returned by server
                guard let data = imageJSON.data,
                      let derivatives = imageJSON.derivatives else {
                          // Data cannot be digested
                          failure(JsonError.unexpectedError as NSError)
                          return
                }

                // Retrieve image data currently in cache
                let imageData = CategoriesData.sharedInstance()
                    .getImageForCategory(categoryId, andId: imageId) ?? PiwigoImageData()
                imageData.imageId = data.imageId ?? imageId

                // Date formatter
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

                // Upper categoies
                if let catIds = data.categoryIds, !catIds.isEmpty {
                    imageData.categoryIds = [NSNumber]()
                    for catId in catIds {
                        if let id = catId.id {
                            imageData.categoryIds.append(NSNumber(value: id))
                        }
                    }
                }
                if imageData.categoryIds.isEmpty {
                    imageData.categoryIds.append(NSNumber(value: categoryId))
                }
                
                // Image title and description
                if let title = data.imageTitle {
                    imageData.imageTitle = NetworkUtilities.utf8mb4String(from: title)
                }
                if let description = data.comment {
                    imageData.comment = NetworkUtilities.utf8mb4String(from: description)
                }
                
                // Image visits and rate
                if let visits = data.visits {
                    imageData.visits = visits
                }
                if let score = data.ratingScore, let rate = Float(score) {
                    imageData.ratingScore = rate
                }
                
                // Image file size, name and MD5 checksum
                imageData.fileSize = data.fileSize ?? NSNotFound
                imageData.md5checksum = data.md5checksum ?? imageData.md5checksum ?? ""
                imageData.fileName = NetworkUtilities.utf8mb4String(from: data.fileName ?? imageData.fileName ?? "NoName.jpg")
                let fileExt = URL(fileURLWithPath: imageData.fileName).pathExtension as NSString
                if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExt, nil)?.takeRetainedValue() {
                    imageData.isVideo = UTTypeConformsTo(uti, kUTTypeMovie)
                }
                
                // Image dates
                imageData.datePosted = dateFormatter.date(from: data.datePosted ?? "") ?? imageData.datePosted ?? Date()
                imageData.dateCreated = dateFormatter.date(from: data.dateCreated ?? "") ?? imageData.dateCreated ?? imageData.datePosted
                
                // Author
                imageData.author = NetworkUtilities.utf8mb4String(from: data.author ?? imageData.author ?? "NSNotFound")
                
                // Privacy level
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
                imageData.fullResPath = NetworkUtilities.encodedImageURL(data.fullResPath ?? imageData.fullResPath ?? "")

                imageData.squarePath = NetworkUtilities.encodedImageURL(derivatives.squareImage?.url ?? imageData.squarePath ?? "")
                imageData.squareWidth = derivatives.squareImage?.width ?? 1
                imageData.squareHeight = derivatives.squareImage?.height ?? 1
                imageData.thumbPath = NetworkUtilities.encodedImageURL(derivatives.thumbImage?.url ?? imageData.thumbPath ?? "")
                imageData.thumbWidth = derivatives.thumbImage?.width ?? 1
                imageData.thumbHeight = derivatives.thumbImage?.height ?? 1
                imageData.mediumPath = NetworkUtilities.encodedImageURL(derivatives.mediumImage?.url ?? imageData.mediumPath ?? "")
                imageData.mediumWidth = derivatives.mediumImage?.width ?? 1
                imageData.mediumHeight = derivatives.mediumImage?.height ?? 1
                imageData.xxSmallPath = NetworkUtilities.encodedImageURL(derivatives.xxSmallImage?.url ?? imageData.xxSmallPath ?? "")
                imageData.xxSmallWidth = derivatives.xxSmallImage?.width ?? 1
                imageData.xxSmallHeight = derivatives.xxSmallImage?.height ?? 1
                imageData.xSmallPath = NetworkUtilities.encodedImageURL(derivatives.xSmallImage?.url ?? imageData.xSmallPath ?? "")
                imageData.xSmallWidth = derivatives.xSmallImage?.width ?? 1
                imageData.xSmallHeight = derivatives.xSmallImage?.height ?? 1
                imageData.smallPath = NetworkUtilities.encodedImageURL(derivatives.smallImage?.url ?? imageData.smallPath ?? "")
                imageData.smallWidth = derivatives.smallImage?.width ?? 1
                imageData.smallHeight = derivatives.smallImage?.height ?? 1
                imageData.largePath = NetworkUtilities.encodedImageURL(derivatives.largeImage?.url ?? imageData.largePath ?? "")
                imageData.largeWidth = derivatives.largeImage?.width ?? 1
                imageData.largeHeight = derivatives.largeImage?.height ?? 1
                imageData.xLargePath = NetworkUtilities.encodedImageURL(derivatives.xLargeImage?.url ?? imageData.xLargePath ?? "")
                imageData.xLargeWidth = derivatives.xLargeImage?.width ?? 1
                imageData.xLargeHeight = derivatives.xLargeImage?.height ?? 1
                imageData.xxLargePath = NetworkUtilities.encodedImageURL(derivatives.xxLargeImage?.url ?? imageData.xxLargePath ?? "")
                imageData.xxLargeWidth = derivatives.xxLargeImage?.width ?? 1
                imageData.xxLargeHeight = derivatives.xxLargeImage?.height ?? 1

                // Update cache
                for catId in imageData.categoryIds {
                    if let _ = CategoriesData.sharedInstance().getCategoryById(catId.intValue) {
                        CategoriesData.sharedInstance().getCategoryById(catId.intValue)
                            .updateImages([imageData])
                    }
                }
                completion(imageData)
            }
            catch {
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
    
    @objc
    class func setInfos(with paramsDict: [String: Any],
                        completion: @escaping () -> Void,
                        failure: @escaping (NSError) -> Void) {
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoImagesSetInfo, paramDict: paramsDict,
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

    @objc
    class func addToFavorites(_ imageData: PiwigoImageData,
                      completion: @escaping () -> Void,
                      failure: @escaping (NSError) -> Void) {
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["image_id"  : imageData.imageId]

        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoUsersFavoritesAdd, paramDict: paramsDict,
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

    @objc
    class func removeFromFavorites(_ imageData: PiwigoImageData,
                                   completion: @escaping () -> Void,
                                   failure: @escaping (NSError) -> Void) {
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["image_id"  : imageData.imageId]

        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoUsersFavoritesRemove, paramDict: paramsDict,
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
    class func downsample(imageAt imageURL: URL, to pointSize: CGSize, scale: CGFloat) -> UIImage {
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

    @objc
    class func downsample(image: UIImage, to pointSize: CGSize, scale: CGFloat) -> UIImage {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard pointSize.equalTo(CGSize.zero) == false,
              let imageData = image.jpegData(compressionQuality: 1.0),
              let imageSource = CGImageSourceCreateWithData(imageData as CFData, imageSourceOptions) else {
            return image
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
