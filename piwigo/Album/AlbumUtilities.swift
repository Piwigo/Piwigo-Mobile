//
//  AlbumUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/12/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

@objc
class AlbumUtilities: NSObject {
    
    // MARK: - Piwigo Server Methods
    class func moveCategory(_ category: PiwigoAlbumData, intoCategoryWithId newParentCatId: Int,
                            completion: @escaping (PiwigoAlbumData) -> Void,
                            failure: @escaping (NSError) -> Void) {
        // Prepare parameters for setting album thumbnail
        let paramsDict: [String : Any] = ["category_id" : category.albumId,
                                          "parent"      : newParentCatId,
                                          "pwg_token"   : NetworkVars.pwgToken]

        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoCategoriesMove, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: CategoriesMoveJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData in
            // Decode the JSON object and update the category in cache.
            do {
                // Decode the JSON into codable type CategoriesMoveJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(CategoriesMoveJSON.self, from: jsonData)

                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                 errorMessage: uploadJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Successful?
                if uploadJSON.success {
                    // Update cached old parent categories, except root album
                    for oldParentStr in category.upperCategories {
                        guard let oldParentID = Int(oldParentStr) else { continue }
                        // Check that it is not the root album, nor the moved album
                        if (oldParentID == 0) || (oldParentID == category.albumId) { continue }

                        // Remove number of moved sub-categories and images
                        CategoriesData.sharedInstance()?.getCategoryById(oldParentID).numberOfSubCategories -= category.numberOfSubCategories + 1
                        CategoriesData.sharedInstance()?.getCategoryById(oldParentID).totalNumberOfImages -= category.totalNumberOfImages
                    }

                    // Update cached new parent categories, except root album
                    var newUpperCategories = [String]()
                    if newParentCatId != 0 {
                        // Parent category in which we moved the category
                        newUpperCategories = CategoriesData.sharedInstance().getCategoryById(newParentCatId).upperCategories ?? []
                        for newParentStr in newUpperCategories {
                            // Check that it is not the root album, nor the moved album
                            guard let newParentId = Int(newParentStr) else { continue }
                            if (newParentId == 0) || (newParentId == category.albumId) { continue }
                            
                            // Add number of moved sub-categories and images
                            CategoriesData.sharedInstance()?.getCategoryById(newParentId).numberOfSubCategories += category.numberOfSubCategories + 1;
                            CategoriesData.sharedInstance()?.getCategoryById(newParentId).totalNumberOfImages += category.totalNumberOfImages
                        }
                    }

                    // Update upperCategories of moved sub-categories
                    var upperCatToRemove:[String] = category.upperCategories ?? []
                    upperCatToRemove.removeAll(where: {$0 == String(category.albumId)})
                    var catToUpdate = [PiwigoAlbumData]()
                    
                    if category.numberOfSubCategories > 0 {
                        let subCategories:[PiwigoAlbumData] = CategoriesData.sharedInstance().getCategoriesForParentCategory(category.albumId) ?? []
                        for subCategory in subCategories {
                            // Replace list of upper categories
                            var upperCategories = subCategory.upperCategories ?? []
                            upperCategories.removeAll(where: { upperCatToRemove.contains($0) })
                            upperCategories.append(contentsOf: newUpperCategories)
                            subCategory.upperCategories = upperCategories
                            catToUpdate.append(subCategory)
                        }
                    }

                    // Replace upper category of moved album
                    var upperCategories = category.upperCategories ?? []
                    upperCategories.removeAll(where: { upperCatToRemove.contains($0) })
                    upperCategories.append(contentsOf: newUpperCategories)
                    category.upperCategories = upperCategories
                    category.nearestUpperCategory = newParentCatId
                    category.parentAlbumId = newParentCatId
                    catToUpdate.append(category)

                    // Update categories in cache
                    CategoriesData.sharedInstance().updateCategories(catToUpdate)

                    completion(category)
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

    class func deleteCategory(_ category: PiwigoAlbumData, inModde mode: String,
                              completion: @escaping () -> Void,
                              failure: @escaping (NSError) -> Void) {
        // Prepare parameters for setting album thumbnail
        let paramsDict: [String : Any] = ["category_id"         : category.albumId,
                                          "photo_deletion_mode" : mode,
                                          "pwg_token"           : NetworkVars.pwgToken]

        // Stores image data before category deletion
        var images: [PiwigoImageData]? = []
        if mode != kCategoryDeletionModeNone {
            images = category.imageList
        }

        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoCategoriesDelete, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: CategoriesDeleteJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData in
            // Decode the JSON object and update the category in cache.
            do {
                // Decode the JSON into codable type CategoriesDeleteJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(CategoriesDeleteJSON.self, from: jsonData)

                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                 errorMessage: uploadJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Successful?
                if uploadJSON.success {
                    // Album successfully deleted ▶ Remove category from list of recent albums
                    let userInfo = ["categoryId" : NSNumber.init(value: category.albumId)]
                    NotificationCenter.default.post(name: Notification.Name.pwgRemoveRecentAlbum,
                                                    object: nil, userInfo: userInfo)

                    // Delete images from cache
                    for image in images ?? [] {
                        // Delete orphans only?
                        if (mode == kCategoryDeletionModeOrphaned) && image.categoryIds.count > 1 {
                            // Update categories the images belongs to
                            CategoriesData.sharedInstance().removeImage(image, fromCategory: String(category.albumId))
                            continue
                        }

                        // Delete image
                        CategoriesData.sharedInstance().deleteImage(image)
                    }

                    // Delete category from cache
                    CategoriesData.sharedInstance().deleteCategory(withId: category.albumId)

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

    class func setRepresentativeOfCategory(withId categoryId: Int, with imageData: PiwigoImageData,
                                           completion: @escaping () -> Void,
                                           failure: @escaping (NSError) -> Void) {
        // Prepare parameters for setting album thumbnail
        let paramsDict: [String : Any] = ["category_id" : categoryId,
                                          "image_id"    : imageData.imageId]

        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoCategoriesSetRepresentative, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: CategoriesSetRepresentativeJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData in
            // Decode the JSON object and update the category in cache.
            do {
                // Decode the JSON into codable type CategoriesSetRepresentativeJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(CategoriesSetRepresentativeJSON.self, from: jsonData)

                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                 errorMessage: uploadJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Successful?
                if uploadJSON.success {
                    // Album thumbnail successfully set ▶ update catagory in cache
                    if let category = CategoriesData.sharedInstance().getCategoryById(categoryId) {
                        category.albumThumbnailId = imageData.imageId
                        category.albumThumbnailUrl = imageData.thumbPath
                        CategoriesData.sharedInstance().updateCategories([category])
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


    // MARK: - Album Collections
    @objc
    class func footerLegend(for nberOfImages: Int) -> String {
        var legend = ""
        if nberOfImages == NSNotFound {
            // Is loading…
            legend = NSLocalizedString("loadingHUD_label", comment:"Loading…")
        }
        else if nberOfImages == 0 {
            // Not loading and no images
            legend = NSLocalizedString("noImages", comment:"No Images")
        }
        else {
            // Display number of images…
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            if let number = numberFormatter.string(from: NSNumber(value: nberOfImages)) {
                let format:String = nberOfImages > 1 ? NSLocalizedString("severalImagesCount", comment:"%@ photos") : NSLocalizedString("singleImageCount", comment:"%@ photo")
                legend = String(format: format, number)
            }
            else {
                legend = String(format: NSLocalizedString("severalImagesCount", comment:"%@ photos"), "?")
            }
        }
        return legend
    }
}
