//
//  AlbumUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/12/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

enum kPwgCategoryDeletionMode {
    case none, orphaned, all
    
    var pwgArg: String {
        switch self {
        case .none:
            return "no_delete"
        case .orphaned:
            return "delete_orphans"
        case .all:
            return "force_delete"
        }
    }
}

class AlbumUtilities: NSObject {
    
    // MARK: - Piwigo Server Methods
    private class func thumbnailSizeArg() -> String {
        var sizeArg = "thumb"
        switch kPiwigoImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) {
        case kPiwigoImageSizeSquare:
            if AlbumVars.shared.hasSquareSizeImages {
                sizeArg = "square"
            }
        case kPiwigoImageSizeXXSmall:
            if AlbumVars.shared.hasXXSmallSizeImages {
                sizeArg = "2small"
            }
        case kPiwigoImageSizeXSmall:
            if AlbumVars.shared.hasXSmallSizeImages {
                sizeArg = "xsmall"
            }
        case kPiwigoImageSizeSmall:
            if AlbumVars.shared.hasSmallSizeImages {
                sizeArg = "small"
            }
        case kPiwigoImageSizeMedium, kPiwigoImageSizeFullRes:
            if AlbumVars.shared.hasMediumSizeImages {
                sizeArg = "medium"
            }
        case kPiwigoImageSizeLarge:
            if AlbumVars.shared.hasLargeSizeImages {
                sizeArg = "large"
            }
        case kPiwigoImageSizeXLarge:
            if AlbumVars.shared.hasXLargeSizeImages {
                sizeArg = "xlarge"
            }
        case kPiwigoImageSizeXXLarge:
            if AlbumVars.shared.hasXXLargeSizeImages {
                sizeArg = "xxlarge"
            }
        case kPiwigoImageSizeThumb:
            fallthrough
        default:
            sizeArg = "thumb"
        }
        return sizeArg
    }
    
    class func getAlbums(completion: @escaping (Bool) -> Void,
                         failure: @escaping (NSError) -> Void) {

        // Prepare parameters for setting album thumbnail
        let paramsDict: [String : Any] = [
            "cat_id"            : 0,
            "recursive"         : true,
            "faked_by_community": NetworkVars.usesCommunityPluginV29 ? "false" : "true",
            "thumbnail_size"    : thumbnailSizeArg()
        ]

        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoCategoriesGetList, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: CategoriesGetListJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData in
            // Decode the JSON object and update the category cache.
            do {
                // Decode the JSON into codable type CategoriesGetListJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(CategoriesGetListJSON.self, from: jsonData)

                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                 errorMessage: uploadJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Extract albums data from JSON message
                let albums = parseAlbumJSON(uploadJSON.data)

                // Update Categories Data cache
                let didUpdateCats = CategoriesData.sharedInstance().replaceAllCategories(albums)

                // Check whether the auto-upload category still exists
                let autoUploadCatId = UploadVars.autoUploadCategoryId
                let indexOfAutoUpload = albums.firstIndex(where: {$0.albumId == autoUploadCatId})
                if indexOfAutoUpload == NSNotFound {
                    UploadManager.shared.disableAutoUpload()
                }
                
                // Check whether the default album still exists
                let defaultCatId = AlbumVars.shared.defaultCategory
                if defaultCatId != 0 {
                    let indexOfDefault = albums.firstIndex(where: {$0.albumId == defaultCatId})
                    if indexOfDefault == NSNotFound {
                        AlbumVars.shared.defaultCategory = 0    // Back to root album
                    }
                }

                // Update albums if Community extension installed (not needed for admins)
                if !NetworkVarsObjc.hasAdminRights,
                   NetworkVarsObjc.usesCommunityPluginV29 {
                    getCommunityAlbums { comAlbums in
                        // Loop over Community albums
                        for comAlbum in comAlbums {
                            CategoriesData.sharedInstance().addCommunityCategory(withUploadRights: comAlbum)
                        }
                        // Return albums
                        completion(didUpdateCats)
                        return
                    } failure: { _ in
                        // Continue without Community albums
                    }
                } else {
                    completion(didUpdateCats)
                }
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
    
    class func getCommunityAlbums(completion: @escaping ([PiwigoAlbumData]) -> Void,
                                  failure: @escaping (NSError) -> Void) {

        // Prepare parameters for setting album thumbnail
        let paramsDict: [String : Any] = ["cat_id"    : 0,
                                          "recursive" : true]

        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kCommunityCategoriesGetList, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: CommunityCategoriesGetListJSON.self,
                                countOfBytesClientExpectsToReceive: 1040) { jsonData in
            // Decode the JSON object and update the category in cache.
            do {
                // Decode the JSON into codable type CommunityCategoriesGetListJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(CommunityCategoriesGetListJSON.self, from: jsonData)

                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                 errorMessage: uploadJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Return Community albums
                completion(parseAlbumJSON(uploadJSON.data))
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
    
    private class func parseAlbumJSON(_ jsonAlbums:[Album]) -> [PiwigoAlbumData] {
        var albums = [PiwigoAlbumData]()
        for category in jsonAlbums {
            if let id = category.id {
                let albumData = PiwigoAlbumData()
                albumData.albumId = id
                albumData.name = NetworkUtilities.utf8mb4String(from: category.name ?? "No Name")
                albumData.comment = NetworkUtilities.utf8mb4String(from: category.comment ?? "")
                
                // When "id_uppercat" is null or not supplied: album at the root
                if let upperCat = category.upperCat {
                    albumData.parentAlbumId = Int(upperCat) ?? NSNotFound
                } else {
                    albumData.parentAlbumId = 0
                }
                if let upperCats = category.uppercats?.components(separatedBy: ",") {
                    albumData.upperCategories = upperCats
                } else {
                    albumData.upperCategories = []
                }
                
                // Rank, number of images and sub-albums
                albumData.globalRank = CGFloat(Float(category.globalRank ?? "") ?? 0.0)
                albumData.numberOfImages = category.nbImages ?? 0
                albumData.totalNumberOfImages = category.totalNbImages ?? 0
                albumData.numberOfSubCategories = category.nbCategories ?? 0
                
                // Thumbnail
                albumData.albumThumbnailId = Int(category.thumbnailId ?? "") ?? NSNotFound
                albumData.albumThumbnailUrl = NetworkUtilities.encodedImageURL(category.thumbnailUrl ?? "")
                
                // When "date_last" is null or not supplied: no date
                /// - 'date_last' is the maximum 'date_available' of the images associated to an album.
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                albumData.dateLast = dateFormatter.date(from: category.dateLast ?? "")

                // By default, Community users have no upload rights
                albumData.hasUploadRights = false
                
                albums.append(albumData)
            }
        }
        return albums
    }
    
    class func create(withName name:String, description: String, status: String,
                      inParentWithId parentCategeoryId: Int,
                      completion: @escaping (Int) -> Void,
                      failure: @escaping (NSError) -> Void) {

        // Prepare parameters for setting album thumbnail
        let paramsDict: [String : Any] = ["name"    : name,
                                          "parent"  : parentCategeoryId,
                                          "comment" : description,
                                          "status"  : status]

        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoCategoriesAdd, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: CategoriesAddJSON.self,
                                countOfBytesClientExpectsToReceive: 1040) { jsonData in
            // Decode the JSON object and update the category in cache.
            do {
                // Decode the JSON into codable type CategoriesAddJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(CategoriesAddJSON.self, from: jsonData)

                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                 errorMessage: uploadJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Successful?
                if let catId = uploadJSON.data.id, catId != NSNotFound {
                    // Album successfully created ▶ Add new album to cache
                    CategoriesData.sharedInstance().addCategory(catId, withParameters: paramsDict)
                    
                    // Add new category to list of recent albums
                    let userInfo = ["categoryId" : NSNumber.init(value: catId)]
                    NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)
                    completion(catId)
                }
                else {
                    // Could not create album
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

    class func setInfos(_ category: PiwigoAlbumData,
                        withName name:String, description: String,
                        completion: @escaping () -> Void,
                        failure: @escaping (NSError) -> Void) {

        // Prepare parameters for setting album thumbnail
        let paramsDict: [String : Any] = ["category_id" : category.albumId,
                                          "name"        : name,
                                          "comment"     : description]

        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoCategoriesSetInfo, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: CategoriesSetInfoJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData in
            // Decode the JSON object and update the category in cache.
            do {
                // Decode the JSON into codable type CategoriesSetInfoJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(CategoriesSetInfoJSON.self, from: jsonData)

                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                 errorMessage: uploadJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Successful?
                if uploadJSON.success {
                    // Album successfully updated ▶ Update category in cache
                    category.name = name
                    category.comment = description
                    CategoriesData.sharedInstance().updateCategories([category])
                    completion()
                }
                else {
                    // Could not set album data
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

    class func move(_ category: PiwigoAlbumData, intoCategoryWithId newParentCatId: Int,
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
                    category.parentAlbumId = newParentCatId
                    catToUpdate.append(category)

                    // Update categories in cache
                    CategoriesData.sharedInstance().updateCategories(catToUpdate)

                    completion(category)
                }
                else {
                    // Could not move album
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

    class func delete(_ category: PiwigoAlbumData,
                      inModde mode: kPwgCategoryDeletionMode,
                      completion: @escaping () -> Void,
                      failure: @escaping (NSError) -> Void) {
        // Prepare parameters for setting album thumbnail
        let paramsDict: [String : Any] = ["category_id"         : category.albumId,
                                          "photo_deletion_mode" : mode.pwgArg,
                                          "pwg_token"           : NetworkVars.pwgToken]

        // Stores image data before category deletion
        var images: [PiwigoImageData]? = []
        if mode != .none {
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
                        if (mode == .orphaned) && image.categoryIds.count > 1 {
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
                    // Could not delete album
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

    class func setRepresentative(_ category: PiwigoAlbumData, with imageData: PiwigoImageData,
                                 completion: @escaping () -> Void,
                                 failure: @escaping (NSError) -> Void) {
        // Prepare parameters for setting album thumbnail
        let paramsDict: [String : Any] = ["category_id" : category.albumId,
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
                    // Album thumbnail successfully set ▶ update catagory
                    category.albumThumbnailId = imageData.imageId
                    category.albumThumbnailUrl = imageData.thumbPath
                    
                    // Update catagory in cache
                    CategoriesData.sharedInstance().updateCategories([category])
                    completion()
                }
                else {
                    // Could not set album thumbnail
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
